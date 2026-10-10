------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- Aircraft spawn sub-module: aircraft, CAP, AFAC, JTAC
-- Part of veafSpawn.lua split (LUAR-001)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Unit spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific unit at a specific spot
-- @param position spawnPosition
-- @param string name
-- @param string country
-- @param int speed
-- @param int alt
-- @param int speed
-- @param int hdg (0..359)
-- @param string unitName (callsign)
-- @param string role (ex: jtac)
-- @param boolean static (is the unit force to spawn as a static unit)
-- @param integer code (starts at 1111, laser code if jtac)
-- @param string freq (frequency if JTAC in MHz with . separator)
-- @param boolean silent (mutes messages to players except errors)
-- @param boolean hiddenOnMFD
-- @param table job (helicopter only) what it does once spawned: `{ task, destination, altitude, speed }`,
--   see veafAircraftSpawn.spawnHelicopterGroup
function veafSpawn.spawnUnit(
  spawnPosition,
  radius,
  name,
  czName,
  country,
  alt,
  hdg,
  unitName,
  role,
  static,
  code,
  freq,
  mod,
  silent,
  hiddenOnMFD,
  job
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnUnit(name = %s, czName=%s, country=%s, alt=%d, hdg=%d, unitName=%s, role=%s, static=%s, code=%s, freq=%s, mod=%s, silent=%s, hiddenOnMFD=%s)",
    name,
    czName,
    country,
    alt,
    hdg,
    unitName,
    role,
    static,
    code,
    freq,
    mod,
    silent,
    hiddenOnMFD
  )

  veafSpawn.spawnedUnitsCounter = veafSpawn.spawnedUnitsCounter + 1

  -- find the desired unit in the groups database
  local unit = veafUnits.findUnit(name)

  if not unit then
    veaf.loggers.get(veafSpawn.Id):info("cannot find unit " .. name)
    trigger.action.outText(veaf.t("spawn.cannot_find_unit", name), 5)
    return
  end

  -- cannot spawn planes yet [TODO], however spawning them as a static is fine; a helicopter goes
  -- through the ground spawn (FEAT-HELICOPTER-SPAWN)
  if unit.air and not static and not unit.helicopter then
    veaf.loggers.get(veafSpawn.Id):info("Air units cannot be spawned at the moment (work in progress)")
    trigger.action.outText(veaf.t("spawn.air_wip"), 5)
    return
  end

  local units = {}
  local groupName = nil

  veaf.loggers.get(veafSpawn.Id):trace("spawnUnit unit = " .. unit.displayName .. ", dcsUnit = " .. tostring(unit.typeName))

  if role == "jtac" then
    local name = "JTAC "
      .. tostring(code):sub(1, 1)
      .. " "
      .. tostring(code):sub(2, 2)
      .. " "
      .. tostring(code):sub(3, 3)
      .. " "
      .. tostring(code):sub(4, 4)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
    groupName = name
    unitName = name
  elseif role == "tacan" then
    local name = "TACAN " .. tostring(freq) .. tostring(mod)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
    groupName = name
    unitName = name
  else
    groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), name, czName)
    if not unitName then
      unitName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), unit.displayName, czName)
    end
  end

  veaf.loggers.get(veafSpawn.Id):trace("groupName=" .. groupName)
  veaf.loggers.get(veafSpawn.Id):trace("unitName=" .. unitName)

  local spawnSpot = nil
  local nbTries = 25
  repeat
    spawnSpot = veaf.placePointOnLand(veaf.getRandomPointInCircle(spawnPosition, radius))
    veaf.loggers
      .get(veafSpawn.Id)
      :trace(string.format("spawnUnit: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
    -- on a helicopter, `alt` is the altitude of its job: it is put down on the ground first
    if alt > 0 and not unit.helicopter then
      spawnSpot.y = alt
    end
    if not veafUnits.checkPositionForUnit(spawnSpot, unit) then
      veaf.loggers.get(veafSpawn.Id):debug("finding another spawnSpot for unit %s, remaining tries #%s", unit.displayName, nbTries)
      spawnSpot = nil
      nbTries = nbTries - 1
    end
  until spawnSpot or nbTries <= 0

  if not spawnSpot then
    veaf.loggers.get(veafSpawn.Id):info("cannot find a suitable position for spawning unit " .. unit.displayName)
    trigger.action.outText(veaf.t("spawn.no_position_unit", unit.displayName), 5)
    return
  else
    local toInsert = {}
    local effectPreset = nil
    local effectTransparency = nil
    local shapeName = nil

    if unit.static or static then
      if unit.category then
        if unit.category == "Heliport" then
          unit.category = "Heliports"
        end
        -- if unit.category == "Effect" then
        --     unit.category = "Effects"
        --     effectPreset = 2
        --     effectTransparency = 1
        --     shapeName = "medium smoke and fire"
        -- end
      end

      groupName = unitName --this name here will be used for reference by DCS, since we return groupName for other scripts to do their thing, this must be the unitName

      toInsert = {
        ["x"] = spawnSpot.x,
        ["y"] = spawnSpot.z,
        ["alt"] = spawnSpot.y,
        ["type"] = unit.typeName,
        ["name"] = groupName,
        ["category"] = unit.category,
        ["heading"] = math.rad(hdg),
        -- ["effectTransparency"] = effectTransparency,
        -- ["effectPreset"] = effectPreset,
        -- ["shapeName"] = shapeName,
      }
    else
      toInsert = {
        ["x"] = spawnSpot.x,
        ["y"] = spawnSpot.z,
        ["alt"] = spawnSpot.y,
        ["type"] = unit.typeName,
        ["name"] = unitName,
        ["speed"] = 0,
        ["skill"] = "Random",
        ["heading"] = math.rad(hdg),
      }
      if unit.helicopter then
        toInsert.payload = veafUnits.aircraftPayload(unit)
      end
    end

    table.insert(units, toInsert)
  end

  veaf.loggers.get(veafSpawn.Id):trace(string.format("unitData = %s", veaf.p(units)))

  -- actually spawn the unit
  if unit.static or static then --if the unit was forced to spawn as a static it could still be an air or a naval unit so this check goes first
    veaf.loggers.get(veafSpawn.Id):trace("Spawning STATIC")
    veaf.addStatic({ country = country, groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
    --groupName = nil --statics do not have a group name, you must set groupName to nil to avoid other scripts interacting
  elseif unit.helicopter then
    veaf.loggers.get(veafSpawn.Id):trace("Spawning HELICOPTER")
    groupName =
      veafAircraftSpawn.spawnHelicopterGroup({ country = country, name = groupName, units = units, hiddenOnMFD = hiddenOnMFD }, job, silent)
  elseif unit.air then
    veaf.loggers.get(veafSpawn.Id):trace("Spawning AIRPLANE")
    veaf.addGroup({ country = country, category = "PLANE", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
  elseif unit.naval then
    veaf.loggers.get(veafSpawn.Id):trace("Spawning SHIP")
    veaf.addGroup({ country = country, category = "SHIP", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
  else
    veaf.loggers.get(veafSpawn.Id):trace("Spawning GROUND_UNIT")
    veaf.addGroup({ country = country, category = "GROUND_UNIT", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
  end

  if role == "jtac" and not static then
    -- JTAC needs to be invisible and immortal
    local _setImmortal = {
      id = "SetImmortal",
      params = {
        value = true,
      },
    }
    -- invisible to AI, Shagrat
    local _setInvisible = {
      id = "SetInvisible",
      params = {
        value = true,
      },
    }

    local spawnedGroup = Group.getByName(groupName)
    local controller = spawnedGroup:getController()
    Controller.setCommand(controller, _setImmortal)
    Controller.setCommand(controller, _setInvisible)

    -- start lasing
    if veaf.isCtldReady() then
      CTLDJTACManager.getInstance():stopAutoLase(groupName)
      local radioData = { freq = freq, mod = mod, name = groupName }
      veafSpawn.JTACAutoLase(groupName, code, radioData)
    end
  elseif role == "tacan" and not static then
    veaf.loggers.get(veafSpawn.Id):trace(string.format("name=%s", tostring(name)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("freq=%s", tostring(freq)))
    local mod = string.upper(mod) or "X"
    veaf.loggers.get(veafSpawn.Id):trace(string.format("mod=%s", tostring(mod)))
    local txFreq = (1025 + freq - 1) * 1000000
    local rxFreq = (962 + freq - 1) * 1000000
    if (freq < 64 and mod == "Y") or (freq >= 64 and mod == "X") then
      rxFreq = (1088 + freq - 1) * 1000000
    end
    veaf.loggers.get(veafSpawn.Id):trace(string.format("txFreq=%s", tostring(txFreq)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("rxFreq=%s", tostring(rxFreq)))

    local command = {
      id = "ActivateBeacon",
      params = {
        type = 4,
        system = 18,
        callsign = code or "TCN",
        frequency = rxFreq,
        AA = false,
        channel = freq,
        bearing = true,
        modeChannel = mod,
      },
    }

    veaf.loggers.get(veafSpawn.Id):trace(string.format("setting %s", veaf.p(command)))
    local spawnedGroup = Group.getByName(groupName)
    local controller = spawnedGroup:getController()
    controller:setCommand(command)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("done setting command"))
  end

  -- message the unit spawning
  veaf.loggers.get(veafSpawn.Id):trace(string.format("message the unit spawning"))
  -- A JTAC always speaks, even when a script spawned it. Kept deliberately (decision recorded in
  -- FIX-SPAWN-BYPASSSECURITY-AS-SILENT, 2026-08-24) rather than tidied away with the conflation it was
  -- patching around: its message carries the laser code and the radio frequency, which is the data a
  -- pilot needs to *use* the JTAC, not a notification he can afford to miss. A convoy appearing is news;
  -- "designating on 1688" is equipment.
  --
  -- A TACAN is the same kind of data, and is NOT exempted here — a scripted TACAN stays as quiet as it is
  -- today, so this lot changes no behaviour it was not asked to change. If a mission ever needs one, this
  -- is the line to extend.
  if (role == "jtac") or not silent then
    local message = veaf.t("spawn.unit_spawned", unit.displayName, country)
    if role == "jtac" and not static then
      message = veaf.t("spawn.jtac_spawned", code, freq, mod)
    elseif role == "tacan" then
      -- Band upper-cased for display only: it arrives as the pilot typed it (`band x`), and a TACAN is
      -- read aloud as 99X.
      message = veaf.t("spawn.tacan_spawned", tostring(freq or ""), string.upper(tostring(mod or "")), tostring(code or ""))
    end
    veaf.loggers.get(veafSpawn.Id):trace(message)
    trigger.action.outText(message, 15)
  end

  return groupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Cargo spawn command
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Spawn a specific cargo at a specific spot

function veafSpawn.JTACAutoLase(groupName, laserCode, radioData)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.JTACAutoLase()")
  veaf.loggers.get(veafSpawn.Id):trace(string.format("groupName=%s", tostring(groupName)))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("laserCode=%s", tostring(laserCode)))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("radioData=%s\n", veaf.p(radioData)))
  local _radio = radioData or {}
  veaf.loggers.get(veafSpawn.Id):trace(string.format("_radio=%s\n", veaf.p(_radio)))
  veaf.loggers.get(veafSpawn.Id):trace(string.format("calling CTLD"))
  -- The legacy ctld.JTACAutoLase wrapper still exists but logs a DEPRECATED line on every
  -- call, and a mission spawns JTACs often enough to fill the log with it.
  CTLDJTACManager.getInstance():autoLase(groupName, laserCode, false, "all", nil, _radio)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("CTLD called"))
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- air units templates
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VeafAirUnitTemplate object
-------------------------------------------------------------------------------------------------------------------------------------------------------------
VeafAirUnitTemplate = {}

function VeafAirUnitTemplate:new(objectToCopy)
  local objectToCreate = objectToCopy or {} -- create object if user does not provide one
  setmetatable(objectToCreate, self)
  self.__index = self

  -- init the new object

  -- name
  objectToCreate.name = nil
  --  coalition (0 = neutral, 1 = red, 2 = blue)
  objectToCreate.coalition = nil
  -- route, only for veaf commands (groups already have theirs)
  objectToCreate.route = nil
  objectToCreate.humanName = nil
  objectToCreate.groupData = nil

  return objectToCreate
end

---
--- setters and getters
---

function VeafAirUnitTemplate:setName(value)
  self.name = value
  return self
end

function VeafAirUnitTemplate:getName()
  return self.name
end

function VeafAirUnitTemplate:setCoalition(value)
  self.coalition = value
  return self
end

function VeafAirUnitTemplate:getCoalition()
  return self.coalition
end

function VeafAirUnitTemplate:setGroupData(value)
  self.groupData = value
  return self
end

function VeafAirUnitTemplate:getGroupData()
  return self.groupData
end

function veafSpawn.initializeAirUnitTemplates()
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.initializeAirUnitTemplates()")

  -- find groups with the air units template prefix
  veaf.loggers.get(veafSpawn.Id):debug("find groups with the air units template prefix")
  local _prefix = veafSpawn.AirUnitTemplatesPrefix:upper()
  veaf.loggers.get(veafSpawn.Id):trace("_prefix=%s", _prefix)
  local _templateGroups = {}
  local _groups = veaf.getGroupsOfCoalition()
  for _, group in pairs(_groups) do
    local _name = group:getName():upper()
    --veaf.loggers.get(veafSpawn.Id):trace("_name=%s",_name)
    if string.sub(_name, 1, string.len(_prefix)) == _prefix then
      table.insert(_templateGroups, group)
    end
  end

  veaf.loggers.get(veafSpawn.Id):trace("_templateGroups=%s", _templateGroups)
  for _, group in pairs(_templateGroups) do
    local _groupName = group:getName()
    veaf.loggers.get(veafSpawn.Id):trace("_groupName=%s", _groupName)
    -- The side is what lets a red `-cap` draw red templates only (#240).
    local _template = VeafAirUnitTemplate:new():setName(_groupName):setCoalition(group:getCoalition())
    veafSpawn.airUnitTemplates[_groupName:upper()] = _template
  end

  -- find groups within the veafSpawn.SpawnablePlanes table
  -- DOES NOT WORK YET
  if veafSpawn.SpawnablePlanes then
    veaf.loggers.get(veafSpawn.Id):debug("find groups within the veafSpawn.SpawnablePlanes table")
    for _, groupData in pairs(veafSpawn.SpawnablePlanes) do
      local _groupName = groupData.name
      veaf.loggers.get(veafSpawn.Id):trace("_groupName=%s", _groupName)
      groupData.country = "russia"
      groupData.countryId = 0
      groupData.category = "plane"
      groupData.coalition = "red"
      groupData.uncontrolled = false
      groupData.hidden = false
      local _template = VeafAirUnitTemplate:new():setName(_groupName):setGroupData(groupData)
      veafSpawn.airUnitTemplates[_groupName:upper()] = _template
    end
  end
end

function veafSpawn.listAllCAP(unitName)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.listAllCAP(unitName=%s)", unitName)
  local sorted = {}
  for name, template in pairs(veafSpawn.airUnitTemplates) do
    local _name = template:getName():sub(veafSpawn.AirUnitTemplatesPrefix:len() + 1)
    table.insert(sorted, _name)
  end
  table.sort(sorted)
  local text = ""
  for _, name in pairs(sorted) do
    text = text .. name .. "\n"
  end
  if text == "" then
    veaf.outTextForUnit(unitName, veaf.t("spawn.no_cap"), 10)
  else
    veaf.outTextForUnit(unitName, text, 30)
  end
end

function veafSpawn.dumpSpawnablePlanesList(export_path)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.dumpSpawnablePlanesList(export_path=%s)", export_path)

  local jsonify = function(key, value)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("jsonify(%s)", veaf.p(value)))
    if veaf.json then
      return veaf.json.stringify(value)
    else
      return ""
    end
  end

  -- sort the spawnable planes alphabetically
  local sortedSpawnablePlanesNames = {}
  for _, spawnablePlane in pairs(veafSpawn.airUnitTemplates) do
    local _name = spawnablePlane:getName():sub(veafSpawn.AirUnitTemplatesPrefix:len() + 1)
    table.insert(sortedSpawnablePlanesNames, _name)
  end
  table.sort(sortedSpawnablePlanesNames)
  veaf.loggers.get(veafSpawn.Id):trace("sortedSpawnablePlanesNames=%s", veaf.lp(sortedSpawnablePlanesNames))

  local _filename = "SpawnablePlanes.json"
  if veaf.config.MISSION_NAME then
    _filename = "SpawnablePlanesList_" .. veaf.config.MISSION_NAME .. ".json"
  end
  if not veaf.DO_NOT_EXPORT_JSON_FILES then
    veaf.exportAsJson(sortedSpawnablePlanesNames, "spawnablePlanes", jsonify, _filename, export_path or veaf.config.MISSION_EXPORT_PATH)
  end
end

function veafSpawn.spawnAFAC(spawnSpot, name, country, altitude, speed, hdg, frequency, mod, code, immortal, silent, hiddenOnMFD)
  local coalition = veaf.getCoalitionForCountry(country, true)
  if not coalition then
    veaf.loggers.get(veafSpawn.Id):error("No country/coalition for AFAC !")
    return nil
  end

  -- find template amongst the existing templates (name can be a regex)
  local groupName = veafSpawn.findSpawnableAircraftGroupname(name, coalition)
  if not groupName then
    local message = string.format('The AFAC aircraft template could not be found for "%s"', veaf.p(name))
    veaf.loggers.get(veafSpawn.Id):info(message)
    trigger.action.outTextForCoalition(coalition, veaf.t("spawn.afac_template_not_found", veaf.p(name)), 15)
    return nil
  end
  veaf.loggers.get(veafSpawn.Id):trace("found template=%s", groupName)

  if not veafSpawn.AFAC.numberSpawned[coalition] then
    veafSpawn.AFAC.numberSpawned[coalition] = 1
  elseif veafSpawn.AFAC.numberSpawned[coalition] > veafSpawn.AFAC.maximumAmount then
    veaf.loggers.get(veafSpawn.Id):info("The limit for AFACs was reached, one needs to be destroyed")
    if not silent then
      trigger.action.outTextForCoalition(coalition, veaf.t("spawn.afac_limit"), 15)
    end
    return false
  end

  veaf.loggers.get(veafSpawn.Id):debug(string.format("number of AFAC spawned : %s", veaf.p(veafSpawn.AFAC.numberSpawned[coalition])))

  -- VMR-098: take the first free callsign, and refuse the spawn when there is none. The old
  -- fallback was `callsigns[coalition][numberSpawned]`, so a counter out of step with the taken
  -- flags handed out the callsign of an AFAC that is still flying: two aircraft answering to one
  -- name, and the first watchdog to fire releases a slot the other one is still using.
  local newGroupName = nil
  local AFAC_num = nil
  for i = 1, veafSpawn.AFAC.maximumAmount do
    if veafSpawn.AFAC.callsigns[coalition][i].taken == false then
      newGroupName = veafSpawn.AFAC.callsigns[coalition][i].name
      AFAC_num = i
      break
    end
  end
  if not newGroupName then
    veaf.loggers.get(veafSpawn.Id):info("every AFAC callsign is taken, one needs to be destroyed")
    if not silent then
      trigger.action.outTextForCoalition(coalition, veaf.t("spawn.afac_limit"), 15)
    end
    return false
  end
  veaf.loggers.get(veafSpawn.Id):trace("newGroupName=%s", newGroupName)
  veaf.loggers.get(veafSpawn.Id):trace("AFAC_num=%s", AFAC_num)
  veaf.loggers.get(veafSpawn.Id):trace("AFAC coalition=%s", coalition)

  --essentially the same counter but for the template group itself, not for all AFACs
  if not veafSpawn.spawnedNamesIndex[groupName] then
    veafSpawn.spawnedNamesIndex[groupName] = 1
  end

  local codeDigit = {}
  codeDigit = veaf.laserCodeToDigit(code)

  local altitude = altitude or 15000
  if altitude <= 8000 then
    altitude = 15000 -- ft
  end

  local speed = speed or 150 -- kn
  -- convert speed to m/s
  speed = speed / 1.94384

  -- convert altitude to meters
  altitude = altitude * 0.3048 -- meters

  --convert heading to radians
  if hdg then
    hdg = hdg * math.pi / 180
  else
    hdg = 0
  end

  local distanceFromTeleport = 3000 --distance between the orbit point and the teleport point in meters

  --calculate DCS radio frequency based on which AFAC out of 8 this is
  local dcsFrequency = veafSpawn.AFAC.baseAFACfrequency[coalition] + (AFAC_num - 1) * 50000 -- .05 MHz increments

  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", veaf.lp(spawnSpot))
  veaf.loggers.get(veafSpawn.Id):trace("name=%s", veaf.lp(name))
  veaf.loggers.get(veafSpawn.Id):trace("country=%s", veaf.lp(country))
  veaf.loggers.get(veafSpawn.Id):trace("altitude (m)=%s", veaf.lp(altitude))
  veaf.loggers.get(veafSpawn.Id):trace("speed (m/s)=%s", veaf.lp(speed))
  veaf.loggers.get(veafSpawn.Id):trace("frequency=%s", veaf.lp(frequency))
  veaf.loggers.get(veafSpawn.Id):trace("dcsFrequency=%s", veaf.lp(dcsFrequency))
  veaf.loggers.get(veafSpawn.Id):trace("code=%s", veaf.lp(code))
  veaf.loggers.get(veafSpawn.Id):trace("mod=%s", veaf.lp(mod))
  veaf.loggers.get(veafSpawn.Id):trace("silent=%s", veaf.lp(silent))
  veaf.loggers.get(veafSpawn.Id):trace("hiddenOnMFD=%s", veaf.lp(hiddenOnMFD))

  local teleportSpot = {}
  teleportSpot.x = spawnSpot.x - distanceFromTeleport * math.cos(hdg) --teleport spot is 3km south of the orbit point
  teleportSpot.y = spawnSpot.z - distanceFromTeleport * math.sin(hdg)
  teleportSpot.alt = altitude
  teleportSpot.speed = speed

  --define 2 point route + teleport Waypoint
  local WP = {}
  WP.one = {}
  WP.two = {}
  WP.three = {}
  WP.one.x = teleportSpot.x
  WP.one.y = teleportSpot.y
  WP.two.x = spawnSpot.x - distanceFromTeleport * math.cos(hdg) / 2
  WP.two.y = spawnSpot.z - distanceFromTeleport * math.sin(hdg) / 2
  WP.three.x = spawnSpot.x
  WP.three.y = spawnSpot.z

  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "teleportPoint", WP.one)
  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "setupPoint", WP.two)
  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "AFAC", "orbitPoint", WP.three)

  local newRoute = {
    ["points"] = {
      -- first point
      [1] = {
        ["type"] = "Turning Point",
        ["action"] = "Turning Point",
        ["x"] = WP.two.x, --1500m south of the orbit point
        ["y"] = WP.two.y,
        ["alt"] = altitude, -- in meters
        ["alt_type"] = "BARO",
        ["speed"] = speed, -- speed in m/s
        ["speed_locked"] = true,
        ["task"] = {
          ["id"] = "ComboTask",
          ["params"] = {
            ["tasks"] = {
              [1] = {
                ["id"] = "FAC",
                ["params"] = {
                  ["frequency"] = dcsFrequency,
                  ["modulation"] = 0, --0 is AM, 1 is FM
                  ["callname"] = AFAC_num,
                  ["number"] = 7 + coalition, --number x as in it's callsign Springfield x-1 for example
                  ["priority"] = 0,
                },
              }, -- end of [1]
            }, -- end of tasks
          }, -- end of params
        }, -- end of task
      }, -- end of waypoint 1
      [2] = {
        ["type"] = "Turning Point",
        ["action"] = "Turning Point",
        ["x"] = WP.three.x,
        ["y"] = WP.three.y,
        ["alt"] = altitude, -- in meters
        ["alt_type"] = "BARO",
        ["speed"] = speed, -- speed in m/s
        ["speed_locked"] = true,
        ["task"] = {
          ["id"] = "ComboTask",
          ["params"] = {
            ["tasks"] = {
              [1] = {
                ["id"] = "Orbit",
                ["params"] = {
                  ["altitude"] = altitude, -- in meters,
                  ["pattern"] = "Circle",
                  ["speed"] = speed, -- speed in m/s
                }, -- end of ["params"]
              }, -- end of [1]
            }, -- end of ["tasks"]
          }, -- end of ["params"]
        }, -- end of ["task"]
      }, -- end of waypoint 2
    },
  }

  -- (re)spawn group
  local newGroup = VeafGroupSpawn:new():forGroup(groupName):named(newGroupName):at(teleportSpot):withRoute(newRoute):buildCloneData()
  if not newGroup then
    veaf.loggers.get(veafSpawn.Id):error("cannot respawn group %s", veaf.p(groupName))
    return nil
  end
  if country and #country > 0 then
    newGroup.coalition = coalition
    newGroup.countryId = veaf.getCountryId(country)
  end
  --newGroup.task = "AFAC"
  veaf.loggers.get(veafSpawn.Id):trace("newGroup=%s", veaf.lp(newGroup, nil, { "route", "payload" }))

  --setup of the new group
  local unit = newGroup.units[1]
  if not unit then
    veaf.loggers.get(veafSpawn.Id):error("cannot get first unit of group %s", veaf.p(newGroup:getName()))
    return nil
  end

  unit.skill = "Excellent"
  newGroup.hidden = false
  newGroup.name = newGroupName
  newGroup.hiddenOnMFD = hiddenOnMFD

  local unitName = newGroupName
  veaf.loggers.get(veafSpawn.Id):trace("unitName=%s", unitName)
  unit.unitName = unitName
  unit.name = unitName
  newGroup.sameName = true

  unit.alt = teleportSpot.alt

  veaf.loggers.get(veafSpawn.Id):trace("newGroup=%s", veaf.lp(newGroup, nil, { "route", "payload" }))
  local _spawnedGroup = veaf.addGroup(newGroup)

  if _spawnedGroup then
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s", veaf.lp(_spawnedGroup, nil, { "route", "payload" }))
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup.name=%s", _spawnedGroup.name)
    --veaf.goRoute(_spawnedGroup.name, newRoute)

    _spawnedGroup.category = "AIRPLANE"
    _spawnedGroup.country = country
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s", veaf.lp(_spawnedGroup))
    veafSpawn.AFAC.missionData[coalition][AFAC_num] = _spawnedGroup --since MIST does not store cloned group data, this is a bit of trickery to allow teleporting AFACs

    -- start lasing
    if veaf.isCtldReady() then
      CTLDJTACManager.getInstance():stopAutoLase(_spawnedGroup.name)
      local radioData = { freq = frequency, mod = mod, name = _spawnedGroup.name }
      veafSpawn.JTACAutoLase(_spawnedGroup.name, code, radioData)
    end

    local humanFrequency = dcsFrequency / 1000000
    local text = veaf.t(
      "spawn.afac_report",
      veafSpawn.AFAC.numberSpawned[coalition],
      veafSpawn.AFAC.maximumAmount,
      _spawnedGroup.name,
      country,
      humanFrequency,
      frequency,
      string.upper(mod)
    )
    veaf.loggers.get(veafSpawn.Id):debug(text)
    if not silent then
      trigger.action.outTextForCoalition(coalition, text, 15)
    end

    local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
    local controller = _dcsSpawnedGroup:getController()

    if immortal then
      veaf.loggers.get(veafSpawn.Id):trace("AFAC immortalized")
      -- JTAC needs to be invisible and immortal
      local _setImmortal = {
        id = "SetImmortal",
        params = {
          value = true,
        },
      }
      -- invisible to AI, Shagrat
      local _setInvisible = {
        id = "SetInvisible",
        params = {
          value = true,
        },
      }

      Controller.setCommand(controller, _setImmortal)
      Controller.setCommand(controller, _setInvisible)
    end

    --set the callsign to avoid desyncs in the DCS JTAC menu
    local _setCallsign = {
      id = "SetCallsign",
      params = {
        callname = AFAC_num,
        number = 9,
      },
    }

    Controller.setCommand(controller, _setCallsign)

    if veafNamedPoints and not silent then
      text = veaf.t("spawn.afac_namepoint", _spawnedGroup.name, humanFrequency, frequency, string.upper(mod))
      veafNamedPoints.namePoint({ x = spawnSpot.x, y = altitude, z = spawnSpot.z }, text, veaf.getCoalitionForCountry(country, true), true)
    end

    veafSpawn.afacWatchdog(newGroupName, AFAC_num, coalition, text)
    veafSpawn.AFAC.callsigns[coalition][AFAC_num].taken = true
    veafSpawn.spawnedNamesIndex[groupName] = veafSpawn.spawnedNamesIndex[groupName] + 1
    veafSpawn.AFAC.numberSpawned[coalition] = veafSpawn.AFAC.numberSpawned[coalition] + 1

    return _spawnedGroup.name
  else
    veaf.loggers.get(veafSpawn.Id):error("MIST could not add AFAC")
    return nil
  end
end

function veafSpawn.afacWatchdog(afacGroupName, AFAC_num, coalition, markName)
  if afacGroupName and not Group.getByName(afacGroupName) then
    veaf.loggers
      .get(veafSpawn.Id)
      :debug(string.format("AFAC named=%s is KIA, removing mark (if it exists) and allowing it to be spawned again", veaf.p(afacGroupName)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("markName=%s", veaf.p(markName)))

    if veafNamedPoints and markName then
      local existingPoint = veafNamedPoints.getPoint(markName)
      veaf.loggers.get(veafSpawn.Id):trace(string.format("existingPoint=%s", veaf.p(existingPoint)))
      if existingPoint and existingPoint.markerId then
        -- delete the existing point
        trigger.action.removeMark(existingPoint.markerId)
      end
    end

    --Make the callsign index available again for spawn
    veaf.loggers.get(veafSpawn.Id):trace(string.format("AFAC_num=%s", veaf.p(AFAC_num)))
    veafSpawn.AFAC.callsigns[coalition][AFAC_num].taken = false
    veafSpawn.AFAC.numberSpawned[coalition] = veafSpawn.AFAC.numberSpawned[coalition] - 1
    -- Hand the callsign back, so the next AFAC can spawn under the same name. This used to delete two
    -- mist.DBs entries by hand, with a comment recommending someone find an alternative; the registry
    -- in veafMissionDb is that alternative.
    veaf.releaseSpawnedName(afacGroupName)
    veafSpawn.AFAC.missionData[coalition][AFAC_num] = nil
  else
    veaf.loggers.get(veafSpawn.Id):trace(string.format("AFAC named=%s is alive", veaf.p(afacGroupName)))

    --update the mark if the AFAC moves
    if veafNamedPoints and markName then
      local existingPoint = veafNamedPoints.getPoint(markName)
      veaf.loggers.get(veafSpawn.Id):trace(string.format("existingAFACmarker=%s", veaf.p(existingPoint)))
      if existingPoint and existingPoint.markerId then
        local AFAC_points = veafSpawn.AFAC.missionData[coalition][AFAC_num].route.points
        local orbitPoint = AFAC_points[#AFAC_points]
        if existingPoint.x ~= orbitPoint.x and existingPoint.z ~= orbitPoint.y then
          -- delete the existing point
          veaf.loggers.get(veafSpawn.Id):trace(string.format("Marker needs updating, AFAC moved, newAFACmarker=%s", veaf.p(orbitPoint)))
          trigger.action.removeMark(existingPoint.markerId)
          veafNamedPoints.namePoint({ x = orbitPoint.x, y = orbitPoint.alt, z = orbitPoint.y }, markName, coalition, true)
        end
      end
    end

    veaf.scheduleFunction(veafSpawn.afacWatchdog, { afacGroupName, AFAC_num, coalition, markName }, timer.getTime() + 120)
  end
end

--- Draw a `veafSpawn-` template matching `name` (a pattern; nil matches every template).
---
--- With `side`, only that side's templates and the neutral ones are candidates: the mission's templates
--- of every side used to go into one pool, so a red `-cap` came out as an F-15C (#240 — 7 NATO
--- airframes out of 10 on 2026-08-17). Neutral templates belong to nobody and serve whoever asks;
--- mission makers park templates there (61 of a reference mission's 117). When nothing matches on
--- those, the draw falls back to every match, so a mission that placed its templates on one side only
--- keeps spawning them for both.
--- @param name string|nil
--- @param side number|nil coalition.side of the requester
--- @return string|nil, table|nil the template's group name and its mission data
function veafSpawn.findSpawnableAircraftGroupname(name, side)
  -- find template amongst the existing templates (name can be a regex)
  local nameUpper = (name or ""):upper()
  local regexNameUpper = ".*" .. (nameUpper or ".*") .. ".*"
  if not name then
    regexNameUpper = ".*"
  end
  local escapedNameUpper = veaf.escapeRegex(nameUpper)
  veaf.loggers.get(veafSpawn.Id):trace("nameUpper=%s", veaf.lp(nameUpper))
  local templatesNamesToChooseFrom = {}
  local ownSideTemplatesNames = {}
  local chosenTemplateName = nil
  for templateNameUpper, templateData in pairs(veafSpawn.airUnitTemplates) do
    veaf.loggers.get(veafSpawn.Id):trace("templateNameUpper=%s", veaf.lp(templateNameUpper))
    if templateNameUpper:match(regexNameUpper) or templateNameUpper:match(escapedNameUpper) then
      local templateName = templateData.name
      veaf.loggers.get(veafSpawn.Id):trace("templateName=%s", veaf.lp(templateName))
      table.insert(templatesNamesToChooseFrom, templateName)
      local templateSide = templateData:getCoalition()
      if side and (templateSide == side or templateSide == coalition.side.NEUTRAL) then
        table.insert(ownSideTemplatesNames, templateName)
      end
    end
  end
  if #ownSideTemplatesNames > 0 then
    templatesNamesToChooseFrom = ownSideTemplatesNames
  elseif side and #templatesNamesToChooseFrom > 0 then
    veaf.loggers
      .get(veafSpawn.Id)
      :warn("no template of side %s matches %s; drawing from the other sides' templates", veaf.p(side), veaf.p(name))
  end
  if templatesNamesToChooseFrom and #templatesNamesToChooseFrom > 0 then
    chosenTemplateName = veaf.randomlyChooseFrom(templatesNamesToChooseFrom)
  else
    local message = string.format('The CAP aircraft template could not be found for "%s"', veaf.p(name))
    veaf.loggers.get(veafSpawn.Id):info(message)
    trigger.action.outText(veaf.t("spawn.cap_template_not_found", veaf.p(name)), 15)
    return nil
  end
  veaf.loggers.get(veafSpawn.Id):trace("templatesNamesToChooseFrom=%s", veaf.lp(templatesNamesToChooseFrom))
  local chosenTemplateData = veaf.getGroupData(chosenTemplateName)
  veaf.loggers.get(veafSpawn.Id):trace("found template=%s", chosenTemplateData)
  return chosenTemplateName, chosenTemplateData
end

function veafSpawn.spawnCombatAirPatrol(
  spawnSpot,
  radius,
  name,
  country,
  altitude,
  altitudeDelta,
  hdg,
  distance,
  speed,
  capRadius,
  skill,
  silent,
  hiddenOnMFD
)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.spawnCombatAirPatrol(name=%s)", name)

  -- for compatibility reasons we still have altitude and altitudedelta set to zero by default
  if altitude == 0 then
    altitude = nil
  end
  if altitudeDelta == 0 then
    altitudeDelta = nil
  end

  local coalition = veaf.getCoalitionForCountry(country, true)
  if not coalition then
    veaf.loggers.get(veafSpawn.Id):error("No country/coalition for CAP !")
    return nil
  end

  -- find template amongst the existing templates (name can be a regex)
  local chosenTemplateName, chosenTemplateData = veafSpawn.findSpawnableAircraftGroupname(name, coalition)
  -- Two different failures, and the old message described both as the first one. "could not find a
  -- template for mig29" reads as *that aircraft does not exist*, so it sent every investigation to the
  -- template table and the search pattern -- while the name had in fact been matched and it was the
  -- mission data behind it that came back nil. That is how FIX-GETGROUPDATA-SKIPS-NEUTRALS survived:
  -- the message named the pilot's input, never the template it had just rejected.
  if not chosenTemplateName then
    veaf.loggers.get(veafSpawn.Id):error("spawnCombatAirPatrol: no aircraft template matches %s", veaf.p(name))
    return
  end
  if not chosenTemplateData then
    veaf.loggers.get(veafSpawn.Id):error(
      "spawnCombatAirPatrol: template %s matched %s but has no mission data, and was rejected",
      veaf.p(chosenTemplateName),
      veaf.p(name)
    )
    return
  end

  local function convertSpeeds(speed, mach, altitude)
    local result = speed
    if not result then
      -- compute ground speed in m/s based on MACH and altitude.
      -- `mach` was ignored in favour of a hard 0.3, so the four legs below -- called with 0.3, 0.5,
      -- 0.63 and 0.63 -- all came out at the same speed, and every CAP spawned without an explicit
      -- speed flew its whole route at Mach 0.3 (SECREV-2 / VMR-097). `or 0.3` keeps the old value as
      -- the fallback for a caller that passes nothing.
      result = veaf.convertMachSpeed(mach or 0.3, altitude).TAS_ms
    else
      -- compute ground speed in m/s based on IAS and altitude
      result = veaf.convertIndicatedAirSpeed(speed, altitude).TAS_ms
    end
    return result
  end

  local radius = radius or 5000 -- m
  local altitude = (altitude or 27000) --[[ ft ]] * 0.3048 --[[ meters ]]
  local altitudeDelta = (altitudeDelta or 2000) --[[ ft ]] * 0.3048 --[[ meters ]]
  local hdg = hdg or 0
  local distance = (distance or 20) --[[ nm ]] * 1852 --[[ meters ]]
  local capRadius = (capRadius or 60) * 1852 --[[ meters ]]
  local skill = skill or "random"

  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", veaf.lp(spawnSpot))
  veaf.loggers.get(veafSpawn.Id):trace("radius=%s", veaf.lp(radius))
  veaf.loggers.get(veafSpawn.Id):trace("name=%s", veaf.lp(name))
  veaf.loggers.get(veafSpawn.Id):trace("country=%s", veaf.lp(country))
  veaf.loggers.get(veafSpawn.Id):trace("altitude=%s", veaf.lp(altitude))
  veaf.loggers.get(veafSpawn.Id):trace("altdelta=%s", veaf.lp(altitudeDelta))
  veaf.loggers.get(veafSpawn.Id):trace("hdg=%s", veaf.lp(hdg))
  veaf.loggers.get(veafSpawn.Id):trace("distance=%s", veaf.lp(distance))
  veaf.loggers.get(veafSpawn.Id):trace("capRadius=%s", veaf.lp(capRadius))
  veaf.loggers.get(veafSpawn.Id):trace("skill=%s", veaf.lp(skill))
  veaf.loggers.get(veafSpawn.Id):trace("silent=%s", veaf.lp(silent))
  veaf.loggers.get(veafSpawn.Id):trace("hiddenOnMFD=%s", veaf.lp(hiddenOnMFD))

  -- find spawn spot
  if altitudeDelta then
    altitude = altitude + math.random(0, altitudeDelta * 2) - altitudeDelta
  end
  local position = veaf.getRandomPointInCircle(spawnSpot, radius)
  position.z = position.y
  -- The patrol flies at this altitude too, so it is floored here and not only at the spawn: a CAP lifted
  -- off the trees would otherwise dive straight back to the altitude it was asked.
  altitude = veafAircraftSpawn.flooredAltitude(position, altitude)
  position.y = altitude
  -- from the altitude actually flown, the floor applied
  local speed0 = convertSpeeds(speed, 0.3, altitude)
  local speed1 = convertSpeeds(speed, 0.5, altitude)
  local speed2 = convertSpeeds(speed, 0.63, altitude)
  local speed3 = convertSpeeds(speed, 0.63, altitude)
  veaf.loggers.get(veafSpawn.Id):trace("speed0=%s", veaf.lp(speed0))
  veaf.loggers.get(veafSpawn.Id):trace("speed1=%s", veaf.lp(speed1))
  veaf.loggers.get(veafSpawn.Id):trace("speed2=%s", veaf.lp(speed2))
  veaf.loggers.get(veafSpawn.Id):trace("speed3=%s", veaf.lp(speed3))
  veaf.loggers.get(veafSpawn.Id):debug("final spawn, position=%s", position)

  -- The template's first-waypoint options: the same rule as ever, now shared with every aircraft role.
  local chosenTemplateWp1Task =
    veafAircraftSpawn.firstWaypointOptions(chosenTemplateData and chosenTemplateData.route and chosenTemplateData.route.points)

  -- A template with nothing usable on its first waypoint spawns a CAP with none of the options its
  -- author meant it to fly with — no ROE, no reaction to threat, no radar or ECM setting. 12 of the
  -- 117 `veafSpawn-` templates in the reference mission are in that state (Mig-21, Mig-23S, Mig-25,
  -- F-14A, F-5, M-2000), and until now they spawned silently.
  --
  -- Deliberately a warning and not a fabricated default: air-to-air behaviour is set on the
  -- controller by the watchdog on every tick (`PROHIBIT_AA` and ROE), so a synthesised waypoint task
  -- would add nothing the CAP does not already get. What is missing is the *template author's* own
  -- options, and only he can supply them. Naming the template is what lets him.
  if not chosenTemplateWp1Task then
    veaf.loggers.get(veafSpawn.Id):warn(
      "template %s has no usable task on its first waypoint; the CAP spawns without its options (add a ComboTask with a WrappedAction to the template)",
      veaf.p(chosenTemplateName)
    )
  end

  if not veafSpawn.spawnedNamesIndex[chosenTemplateName] then
    veafSpawn.spawnedNamesIndex[chosenTemplateName] = 1
  else
    veafSpawn.spawnedNamesIndex[chosenTemplateName] = veafSpawn.spawnedNamesIndex[chosenTemplateName] + 1
  end
  local newGroupName = string.format("%s #%04d", chosenTemplateName, veafSpawn.spawnedNamesIndex[chosenTemplateName])
  veaf.loggers.get(veafSpawn.Id):debug("indexed newGroupName=%s", newGroupName)

  -- The route, the options and the watchdog are the `cap` role's (FEAT-AIRCRAFT-ROLES). What stays
  -- here is what makes it the `-cap` command: its options, its template choice, its message.
  local spawn = VeafAircraftSpawn:new()
    :fromGroup(chosenTemplateName)
    :named(newGroupName)
    :at(position)
    :withSkill(skill)
    :shownOnMap(hiddenOnMFD)
    :withFirstWaypointTask(chosenTemplateWp1Task)
    :withRole("cap", {
      heading = hdg,
      distance = distance,
      capRadius = capRadius,
      altitude = altitude,
      speed1 = speed1,
      speed2 = speed2,
      speed3 = speed3,
    })
  if country and #country > 0 then
    spawn:inCountry(veaf.getCountryId(country))
  end
  local spawnedGroupName = spawn:spawn()
  if not spawnedGroupName then
    return nil
  end

  local message = string.format("A CAP of %s (%s) has been spawned", name, country)
  veaf.loggers.get(veafSpawn.Id):debug(message)
  if not silent then
    trigger.action.outText(veaf.t("spawn.cap_spawned", name, country), 15)
  end

  return spawnedGroupName
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- AWACS and escorts (FEAT-AWACS-ESCORT-COMMANDS, #188 and #189)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Altitude an AWACS flies at when the command gives none, in feet.
veafSpawn.AWACS_DEFAULT_ALTITUDE = 30000

--- Mach number an AWACS flies at when the command gives no speed. Between an E-2's cruise and an
--- E-3's; an estimate, not a reading.
veafSpawn.AWACS_DEFAULT_MACH = 0.5

--- Length of the AWACS race-track when the command gives none, in nautical miles.
veafSpawn.AWACS_DEFAULT_LEG = 30

--- Radio frequency of a spawned AWACS when the command gives none, in MHz, AM.
veafSpawn.AWACS_DEFAULT_FREQUENCY = 251

--- How far from the marker `-escort` looks for the airplane to escort, in metres (10 NM).
veafSpawn.ESCORT_SEARCH_RADIUS = 10 * 1852

--- How far behind its charge an escort appears, in metres.
veafSpawn.ESCORT_SPAWN_BEHIND = 3000

--- Appended to the escorted group's name to name its escort: the convention `veafMove` reads on editor
--- groups. A group spawned at runtime has no editor record, so `_move` cannot use it on these.
veafSpawn.EscortGroupNameSuffix = " escort"

--- The templates the F10 menu offers to escort a pilot, one entry each: a search on the `veafSpawn-`
--- templates of their side, as `-escort` takes it. A mission may replace the list.
veafSpawn.EscortRadioMenuTemplates = { "fox3", "fox2" }

--- Spawn an AWACS on its race-track, from its type.
---
--- @param spawnSpot table runtime vec3, where the race-track starts
--- @param options table the marker options: `country`, `type`, `altitude` (ft, 0 = default), `speed`
---   (kt IAS), `heading`, `distance` (NM), `freq` (MHz), `eplrs`, `escortTemplate`, `skill`, `silent`,
---   `showMFD`
--- @return string|nil the AWACS group's name
function veafSpawn.spawnAwacs(spawnSpot, options)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.spawnAwacs(type=%s)", veaf.p(options.type))
  local side = veaf.getCoalitionForCountry(options.country, true)
  if not side then
    veaf.loggers.get(veafSpawn.Id):error("No country/coalition for AWACS !")
    return nil
  end
  local function tell(message)
    veaf.loggers.get(veafSpawn.Id):info(message)
    if not options.silent then
      trigger.action.outText(message, 15)
    end
  end

  local dcsType = veafAircraftSpawn.awacsType(options.type, side)
  if not dcsType then
    local known = {}
    for name, _ in pairs(veafAircraftSpawn.AWACS_TYPES) do
      table.insert(known, name)
    end
    table.sort(known)
    tell(veaf.t("spawn.awacs_unknown_type", tostring(options.type), table.concat(known, ", ")))
    return nil
  end

  local altitude = veafAircraftSpawn.flooredAltitude(
    spawnSpot,
    ((options.altitude and options.altitude > 0) and options.altitude or veafSpawn.AWACS_DEFAULT_ALTITUDE) * 0.3048
  )
  local speed = options.speed and veaf.convertIndicatedAirSpeed(options.speed, altitude).TAS_ms
    or veaf.convertMachSpeed(veafSpawn.AWACS_DEFAULT_MACH, altitude).TAS_ms
  local frequency = tonumber(options.freq) or veafSpawn.AWACS_DEFAULT_FREQUENCY
  local groupName = "AWACS " .. dcsType
  if veaf.isNameTaken(groupName) then
    groupName = veafDcsSpawner.freeNameFrom(groupName)
  end

  local groupData = {
    country = options.country,
    name = groupName,
    hidden = false,
    hiddenOnMFD = not options.showMFD,
    communication = true,
    frequency = frequency,
    modulation = 0, -- AM
    units = {
      {
        type = dcsType,
        name = groupName .. " 1",
        x = spawnSpot.x,
        y = spawnSpot.z,
        alt = altitude,
        heading = math.rad(options.heading or 0),
        skill = options.skill or "Excellent",
        payload = veafAircraftSpawn.awacsPayload(dcsType),
      },
    },
  }
  local spawnedName = veafAircraftSpawn.spawnAirplaneGroup(groupData, "awacs", {
    heading = options.heading or 0,
    distance = (options.distance or veafSpawn.AWACS_DEFAULT_LEG) * 1852,
    altitude = altitude,
    speed = speed,
    eplrs = options.eplrs,
  })
  if not spawnedName then
    return nil
  end
  if not options.silent then
    trigger.action.outText(veaf.t("spawn.awacs_spawned", dcsType, string.format("%.3f", frequency)), 15)
  end

  if options.escortTemplate then
    veafSpawn.spawnEscort(options.escortTemplate, spawnedName, options.country, options.silent, not options.showMFD)
  end
  return spawnedName
end

--- Where an escort appears: `ESCORT_SPAWN_BEHIND` behind its charge's leader, at its altitude.
---
--- @param leader table the escorted group's first unit
--- @return table runtime vec3
function veafSpawn.escortSpawnSpot(leader)
  local position = leader:getPosition()
  local forwardX, forwardZ = position.x.x, position.x.z
  local length = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
  if length < 0.001 then
    forwardX, forwardZ, length = 1, 0, 1
  end
  local behind = veafSpawn.ESCORT_SPAWN_BEHIND / length
  return { x = position.p.x - forwardX * behind, y = position.p.y, z = position.p.z - forwardZ * behind }
end

--- Spawn fighters from a `veafSpawn-` template to escort an airplane group, and defend it.
---
--- @param name string the template search, as `-cap` takes it (`f15-fox3`, `fox3`); blank is any
--- @param escortedGroupName string the group to escort
--- @param country string the country the escort flies for
--- @param silent boolean|nil true: nothing is shown to the players
--- @param hiddenOnMFD boolean|nil
--- @return string|nil the escort group's name
function veafSpawn.spawnEscort(name, escortedGroupName, country, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.spawnEscort(name=%s, escorted=%s)", veaf.p(name), veaf.p(escortedGroupName))
  local side = veaf.getCoalitionForCountry(country, true)
  if not side then
    -- without a side, the template search draws from every side and the escort keeps its template's
    -- country: an enemy of the group it is told to escort
    veaf.loggers.get(veafSpawn.Id):error("spawnEscort: no coalition for country %s", veaf.p(country))
    return nil
  end
  local escorted = Group.getByName(escortedGroupName or "")
  local leader = escorted and escorted:isExist() and escorted:getUnits()[1]
  if not leader then
    local message = veaf.t("spawn.helicopter_escort_no_group", tostring(escortedGroupName))
    veaf.loggers.get(veafSpawn.Id):info(message)
    if not silent then
      trigger.action.outText(message, 15)
    end
    return nil
  end

  -- Every refusal says why: an "Escort me" that answered nothing in game could not be told apart from a
  -- menu that never reached the script (FIX-CAMPAIGN-MISSION-1-FINDINGS ticket 09).
  local templateName, templateData = veafSpawn.findSpawnableAircraftGroupname(name, side)
  if not templateName or not templateData then
    local message = veaf.t("spawn.escort_no_template", tostring(name or ""))
    veaf.loggers.get(veafSpawn.Id):info(message)
    if not silent then
      trigger.action.outText(message, 15)
    end
    return nil
  end

  local groupName = escortedGroupName .. veafSpawn.EscortGroupNameSuffix
  if veaf.isNameTaken(groupName) then
    groupName = veafDcsSpawner.freeNameFrom(groupName)
  end
  local spawn = VeafAircraftSpawn:new()
    :fromGroup(templateName)
    :named(groupName)
    :at(veafSpawn.escortSpawnSpot(leader))
    :shownOnMap(hiddenOnMFD)
    :withRole("air_escort", { escorted = escortedGroupName })
  if country and #country > 0 then
    spawn:inCountry(veaf.getCountryId(country))
  end
  local spawnedName = spawn:spawn()
  if not spawnedName then
    local message = veaf.t("spawn.escort_spawn_failed", templateName, escortedGroupName)
    veaf.loggers.get(veafSpawn.Id):warn(message)
    if not silent then
      trigger.action.outText(message, 15)
    end
    return nil
  end
  if not silent then
    -- the template drawn, not the search: `-escort` alone searches for nothing
    trigger.action.outText(
      veaf.t("spawn.escort_spawned", templateName:sub(veafSpawn.AirUnitTemplatesPrefix:len() + 1), escortedGroupName),
      15
    )
  end
  return spawnedName
end

--- The airplane group nearest a point, within `ESCORT_SEARCH_RADIUS`, of this side or neutral: what a
--- `-escort` marker placed next to an aircraft means to escort.
---
--- @param point table runtime vec3
--- @param side number the coalition asking
--- @return string|nil the group's name
function veafSpawn.findEscortableAircraft(point, side)
  local found, nearest = nil, veafSpawn.ESCORT_SEARCH_RADIUS
  local sides = { side }
  if side ~= coalition.side.NEUTRAL then
    table.insert(sides, coalition.side.NEUTRAL)
  end
  for _, eachSide in ipairs(sides) do
    for _, group in pairs(coalition.getGroups(eachSide, Group.Category.AIRPLANE) or {}) do
      if group:isExist() then
        for _, unit in pairs(group:getUnits() or {}) do
          -- `isActive` too: a late-activated group answers `isExist()` true before it appears
          -- (docs/agents/dcs-runtime-traps.md), and an escort would orbit an aircraft nobody sees
          if unit:isExist() and unit:isActive() then
            local unitPoint = unit:getPoint()
            local dx, dz = unitPoint.x - point.x, unitPoint.z - point.z
            local distance = math.sqrt(dx * dx + dz * dz)
            if distance <= nearest then
              found, nearest = group:getName(), distance
            end
          end
        end
      end
    end
  end
  return found
end

--- The `-escort` marker: escort the airplane it was placed next to.
---
--- @return string|nil the escort group's name
function veafSpawn.spawnEscortNear(point, options)
  local escortedGroupName = veafSpawn.findEscortableAircraft(point, options.side)
  if not escortedGroupName then
    local message = veaf.t("spawn.escort_no_aircraft", veafSpawn.ESCORT_SEARCH_RADIUS / 1852)
    veaf.loggers.get(veafSpawn.Id):info(message)
    if not options.silent then
      trigger.action.outText(message, 15)
    end
    return nil
  end
  return veafSpawn.spawnEscort(options.name, escortedGroupName, options.country, options.silent, not options.showMFD)
end

--- The F10 entry "Escort me": escort the group of the pilot who asked.
---
--- @param parameters table `{ templateSearch, unitName }`, as a per-group radio command receives it
function veafSpawn.escortMe(parameters)
  local name, unitName = veaf.safeUnpack(parameters)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.escortMe(name=%s, unitName=%s)", veaf.p(name), veaf.p(unitName))
  local unit = unitName and Unit.getByName(unitName)
  if not unit or not unit:isExist() then
    -- nobody left to tell: the log is the only trace
    veaf.loggers.get(veafSpawn.Id):info("Escort me: unit [%s] not found, no escort", tostring(unitName))
    return nil
  end
  if unit:getCategoryEx() ~= Unit.Category.AIRPLANE then
    veaf.outTextForUnit(unitName, veaf.t("spawn.escort_not_an_airplane"), 10)
    return nil
  end
  local group = unit:getGroup()
  if not group then
    return nil
  end
  return veafSpawn.spawnEscort(name, group:getName(), veaf.getCountryForCoalition(unit:getCoalition()), false, true)
end

--- Add one "Escort me" entry per `EscortRadioMenuTemplates` to a menu, per group, at the level `-cap`
--- asks of a marker.
function veafSpawn.addEscortRadioCommands(menu)
  for _, name in ipairs(veafSpawn.EscortRadioMenuTemplates) do
    local command =
      veafRadio.addSecuredCommandToSubmenu(veaf.t("menu.spawn.escort_me", name), menu, veafSpawn.escortMe, name, veafRadio.USAGE_ForGroup)
    if command then
      command.securityLevel = veafSecurity.LEVEL_KNOWN_PILOT
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CAP target selection
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What a CAP's radar can hand back, and which of it is worth a second look.
---
--- `Controller.getDetectedTargets` returns **objects**, not aircraft, and DCS has exactly six object
--- categories. They are enumerated here rather than discovered one crash at a time: on 2026-09-01 a
--- detected object that was not a unit raised *"Static doesn't exist"* inside the watchdog, twice, and
--- since the watchdog reschedules itself from its own tail, the raise left that CAP with no watchdog
--- at all for the rest of the mission.
---
--- Only `UNIT` gets past it; the aircraft test proper is `veafSpawn.CAP_AIR_ATTRIBUTE` below.
veafSpawn.CAP_ENGAGEABLE_OBJECT_CATEGORY_NAMES = {
  UNIT = true,
  WEAPON = false, -- a missile in flight: a threat, not a target
  STATIC = false,
  BASE = false,
  SCENERY = false,
  CARGO = false,
}

--- The same enumeration, keyed by the value `getCategory` actually returns.
---
--- Built from the names rather than written as `[Object.Category.CARGO] = false` literals on purpose:
--- a table constructor whose key is nil raises *"table index is nil"*, and this runs at script load,
--- so one enumerator ED renames would stop the whole VEAF framework from loading rather than cost this
--- one filter a line.
veafSpawn.CAP_ENGAGEABLE_OBJECT_CATEGORIES = {}
for categoryName, isEngageable in pairs(veafSpawn.CAP_ENGAGEABLE_OBJECT_CATEGORY_NAMES) do
  local categoryValue = Object.Category[categoryName]
  if categoryValue ~= nil then
    veafSpawn.CAP_ENGAGEABLE_OBJECT_CATEGORIES[categoryValue] = isEngageable
  end
end

--- The unit attribute that tells an aircraft from everything else a radar returns.
---
--- Enumerated from the shipped DCS unit database rather than picked by hand: of its 883 entries, all
--- 170 aircraft carry `Air`, and not one vehicle, ship, static or infantry entry does —
--- `TestVeafSpawnCapTargetFilter:test_air_attribute_marks_exactly_the_aircraft` sweeps the whole table
--- to hold that true, so the day ED adds an aircraft without it the suite says so.
---
--- Why an attribute and not a name: the group category cannot tell an aircraft from a man hanging
--- under a parachute, because an ejected pilot keeps his aircraft's group. Matching on a name
--- (`Pilot`, `Parachutist`, …) would be worse than useless — a mission maker names his units in his
--- own language, and DCS's own default unit name for an *aircraft* is `Pilot #001`, which is exactly
--- what the 2026-09-01 log was full of. An ED attribute is the same string in every mission.
veafSpawn.CAP_AIR_ATTRIBUTE = "Air"

--- Call a method on a detected object without trusting the object to still be there.
---
--- Every accessor on a detected object can raise — that is the *"Static doesn't exist"* above — and a
--- raise anywhere in the watchdog stops it forever. Returns nil for anything that does not answer.
local function askDetectedObject(object, method, ...)
  local objectType = type(object)
  if objectType ~= "table" and objectType ~= "userdata" then
    return nil
  end
  local ok, accessor = pcall(function()
    return object[method]
  end)
  if not ok or type(accessor) ~= "function" then
    return nil
  end
  local called, result = pcall(accessor, object, ...)
  if not called then
    return nil
  end
  return result
end

--- Is this detected object something a CAP should be tasked against?
---
--- @param target table|nil a `getDetectedTargets` entry's `.object`
--- @param capCoalition number the CAP's own coalition
--- @return boolean true when the watchdog should list and engage it
--- @return string|nil why it was refused, for the trace; nil when it was accepted
function veafSpawn.isCapEngageableTarget(target, capCoalition)
  if target == nil then
    return false, "no object"
  end

  local objectCategory = askDetectedObject(target, "getCategory")
  if not veafSpawn.CAP_ENGAGEABLE_OBJECT_CATEGORIES[objectCategory] then
    return false, "object category " .. tostring(objectCategory)
  end

  -- `isActive` keeps a late-activated group out of it; `inAir` is true for anything off the ground,
  -- a man under a parachute included, so it is a necessary test and never a sufficient one.
  if not (askDetectedObject(target, "isActive") and askDetectedObject(target, "inAir")) then
    return false, "not airborne"
  end

  local targetCoalition = askDetectedObject(target, "getCoalition")
  if targetCoalition == nil or targetCoalition == capCoalition then
    return false, "not hostile"
  end

  local targetGroup = askDetectedObject(target, "getGroup")
  local targetGroupCategory = targetGroup and askDetectedObject(targetGroup, "getCategory")
  if targetGroupCategory ~= Group.Category.AIRPLANE and targetGroupCategory ~= Group.Category.HELICOPTER then
    return false, "group category " .. tostring(targetGroupCategory)
  end

  -- The test the group category cannot do. An ejected pilot is still a member of his aircraft's
  -- AIRPLANE group and is still `inAir()` under his canopy; his own descriptor is not an aircraft's.
  local targetDescription = askDetectedObject(target, "getDesc")
  local targetAttributes = targetDescription and targetDescription.attributes
  if type(targetAttributes) ~= "table" or not targetAttributes[veafSpawn.CAP_AIR_ATTRIBUTE] then
    return false, "not an aircraft"
  end

  return true, nil
end

--- Aspect boundaries, in degrees between the target's track and the line from the target to the CAP:
--- up to `CAP_ASPECT_HOT_MAX` it is flying at the CAP, from `CAP_ASPECT_COLD_MIN` it is flying away,
--- flanking in between. An estimate, not a sourced doctrine (FEAT-CAP-WATCHDOG, #187).
veafSpawn.CAP_ASPECT_HOT_MAX = 60
veafSpawn.CAP_ASPECT_COLD_MIN = 120

--- What the aspect does to the distance the priority ladder reads: a hot target counts as twice as
--- close, a cold one as twice as far. An estimate, to be tuned in game.
veafSpawn.CAP_ASPECT_DISTANCE_FACTOR = { hot = 0.5, flanking = 1, cold = 2 }

--- A cold target further than this from the CAP, in metres, is leaving: it is not engaged, and the CAP
--- stays on its zone instead of chasing it. An estimate, to be tuned in game.
veafSpawn.CAP_COLD_CUTOFF = 40000

--- How much further from cold, in degrees, a target past the cut-off must turn before it is picked up
--- again. Without it, a target beaming at about `CAP_ASPECT_COLD_MIN` flips between engaged and dropped
--- every tick, and every drop sets the patrol again.
veafSpawn.CAP_COLD_CUTOFF_HYSTERESIS = 15

--- Where a target points relative to the CAP, on the ground plane.
---
--- @param targetPosition table runtime vec3
--- @param targetVelocity table|nil runtime vec3, m/s
--- @param capPosition table runtime vec3
--- @return string `hot`, `flanking` or `cold`; `flanking`, the neutral weight, when there is no track
---   to read (a hovering helicopter, a velocity that did not answer)
--- @return number|nil the angle, in degrees; nil with no track
function veafSpawn.targetAspect(targetPosition, targetVelocity, capPosition)
  -- a detected object's answer is not trusted: a raise here would stop the watchdog for good
  if type(targetVelocity) ~= "table" or type(targetVelocity.x) ~= "number" or type(targetVelocity.z) ~= "number" then
    return "flanking"
  end
  local toCapX, toCapZ = capPosition.x - targetPosition.x, capPosition.z - targetPosition.z
  local distance = math.sqrt(toCapX * toCapX + toCapZ * toCapZ)
  local speed = math.sqrt(targetVelocity.x * targetVelocity.x + targetVelocity.z * targetVelocity.z)
  if distance < 1 or speed < 1 then
    return "flanking"
  end
  local cosine = (targetVelocity.x * toCapX + targetVelocity.z * toCapZ) / (distance * speed)
  local angle = math.deg(math.acos(math.max(-1, math.min(1, cosine))))
  if angle <= veafSpawn.CAP_ASPECT_HOT_MAX then
    return "hot", angle
  elseif angle >= veafSpawn.CAP_ASPECT_COLD_MIN then
    return "cold", angle
  end
  return "flanking", angle
end

--- Which target each aircraft of a CAP goes for, when there is a choice to make.
---
--- Round the targets in priority order, so the most important one gets the first aircraft and, with
--- more aircraft than targets, the most important ones get the extra aircraft.
---
--- @param unitNames table the CAP's airborne aircraft, in group order
--- @param targets table the targets to engage, most important first, each with a `targetId`
--- @return table unit name -> target id; empty with one target or one aircraft, where the group's own
---   tasks already say everything
function veafSpawn.spreadCapTargets(unitNames, targets)
  local spread = {}
  if #targets < 2 or #unitNames < 2 then
    return spread
  end
  for index, unitName in ipairs(unitNames) do
    spread[unitName] = targets[(index - 1) % #targets + 1].targetId
  end
  return spread
end

--- Give each aircraft of a CAP the target `spread` names, on its own controller, touching only the
--- aircraft whose target changed; an aircraft with no target any more is reset, and follows its
--- group's tasks again. `again` sets every target once more, unchanged or not: the group's task has
--- just been set anew.
---
--- `units` is the whole group, not only the aircraft `spread` covers, so one that left the spread (landed,
--- out of the zone) is reset rather than left on its old target. What was given is remembered by unit
--- **id**: a group respawned under the same names has new ids, and is given its targets again.
local function applyCapSpread(capGroupName, units, spread, again)
  local previous = veafSpawn.capWatchdogAssignments[capGroupName] or {}
  local given = {}
  for _, unit in ipairs(units) do
    local unitName = unit:getName()
    local unitId = unit:getID()
    local targetId = spread[unitName]
    given[unitId] = targetId
    if targetId ~= previous[unitId] or (again and targetId) then
      local unitController = unit:getController()
      if targetId then
        veaf.loggers.get(veafSpawn.Id):debug("CAP aircraft %s goes for target %s", veaf.p(unitName), veaf.p(targetId))
        unitController:setTask({ id = "EngageUnit", params = { unitId = targetId, weaponType = "ALL" } })
      else
        veaf.loggers.get(veafSpawn.Id):debug("CAP aircraft %s follows its group again", veaf.p(unitName))
        unitController:resetTask()
      end
    end
  end
  veafSpawn.capWatchdogAssignments[capGroupName] = given
end

--- Forget what the CAP watchdog keeps about a group, when it stops watching it.
local function forgetCapWatchdog(capGroupName)
  veafSpawn.capWatchdogZones[capGroupName] = nil
  veafSpawn.capWatchdogFlown[capGroupName] = nil
  veafSpawn.capWatchdogAssignments[capGroupName] = nil
  veafAircraftSpawn.forgetGroup(capGroupName)
end

--- One tick of the CAP watchdog, which re-arms itself.
---
--- @param pEngagedTargetIds table|nil the set of target ids that have an `EngageUnit` on the controller,
---   from the previous tick
function veafSpawn.startCapWatchdog(capGroupName, capCoalition, capZone, pTargetsList, pEngagedTargetIds)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.startCapWatchdog(capGroupName=%s)", veaf.lp(capGroupName))
  veaf.loggers.get(veafSpawn.Id):trace("capZone=%s", veaf.lp(capZone))

  if capGroupName == nil then
    veaf.loggers.get(veafSpawn.Id):error("veafSpawn.startCapWatchdog; capGroupName is mandatory !")
    return
  end

  if capCoalition == nil then
    veaf.loggers.get(veafSpawn.Id):error("veafSpawn.startCapWatchdog; capCoalition is mandatory !")
    return
  end

  -- The zone may have changed since this watchdog was scheduled: a role given to the group in flight
  -- re-aims it here rather than starting a second watchdog (FEAT-AIRCRAFT-ROLES).
  capZone = veafSpawn.capWatchdogZones[capGroupName] or capZone

  local capGroup = Group.getByName(capGroupName)
  if not capGroup then
    veaf.loggers.get(veafSpawn.Id):debug("CAP group %s is nowhere to be found, stopping watchdog", veaf.lp(capGroupName))
    forgetCapWatchdog(capGroupName)
    return
  end
  local capGroupPosition = veaf.getAveragePosition(capGroup)
  if not capGroupPosition then
    veaf.loggers.get(veafSpawn.Id):error("CAP group %s has no position!", veaf.p(capGroupName))
    forgetCapWatchdog(capGroupName)
    return
  end

  veaf.loggers.get(veafSpawn.Id):trace("Looking in CAP zone for targets...")
  local timestamp = timer.getTime()
  local targetsList = pTargetsList or {}
  local engagedTargetIds = pEngagedTargetIds or {}
  veaf.loggers.get(veafSpawn.Id):trace("targetsList=%s", veaf.lp(targetsList))
  veaf.loggers.get(veafSpawn.Id):trace("engagedTargetIds=%s", veaf.lp(engagedTargetIds))

  -- check CAP group for state and position
  local capLanded = true
  local capInZone = false
  local capUnits = {} -- every aircraft, for the spread to reset the ones it no longer covers
  local spreadUnitNames = {} -- the aircraft in the air and in the zone: the ones a target may be spread to
  for _, unit in pairs(capGroup:getUnits()) do
    if unit then
      table.insert(capUnits, unit)
    end
    if unit and unit:inAir() then
      capLanded = false
      local isUnitInZone = veaf.isUnitInZone(unit, capZone)
      veaf.loggers.get(veafSpawn.Id):trace("unitName=%s, isUnitInZone=%s", veaf.lp(unit:getName()), veaf.lp(isUnitInZone))
      if isUnitInZone then
        capInZone = true
        table.insert(spreadUnitNames, unit:getName())
        -- unit is in the zone, and in the air, let's test the targets it can see
        local detectedTargets = unit:getController():getDetectedTargets()
        if detectedTargets and #detectedTargets > 0 then
          -- process each target and compute its priority, then add it to the targets list
          for _, detectedTarget in pairs(detectedTargets) do
            local target = detectedTarget.object
            -- The filter runs *before* anything is read off the object. It used to run after four
            -- dereferences, which is how a detected static could raise "Static doesn't exist" and take
            -- the whole watchdog down with it.
            local isEngageable, refusalReason = veafSpawn.isCapEngageableTarget(target, capCoalition)
            if not isEngageable then
              veaf.loggers.get(veafSpawn.Id):trace("Discarding a detected object: %s", veaf.lp(refusalReason))
            else
              local targetId = target:getID()
              local targetName = target:getName()
              local targetGroupName = target:getGroup():getName()
              veaf.loggers.get(veafSpawn.Id):trace(
                "Checking targetGroupName=%s, targetName=%s, targetId=%s",
                veaf.lp(targetGroupName),
                veaf.lp(targetName),
                veaf.lp(targetId)
              )
              local targetPosition = target:getPosition().p
              local targetDistanceFromCapZoneCenter = veaf.get2DDist(targetPosition, capZone)
              veaf.loggers.get(veafSpawn.Id):trace("targetPosition=%s", veaf.lp(targetPosition))
              veaf.loggers.get(veafSpawn.Id):trace("targetDistanceFromCapZoneCenter=%s", veaf.lp(targetDistanceFromCapZoneCenter))
              local targetDistanceFromCapGroup = veaf.get2DDist(targetPosition, capGroupPosition)
              -- From the group's average position, not the aircraft that saw it: every aircraft of the
              -- CAP must reach the same verdict on the same target in the same tick.
              local targetAspect, targetAngle =
                veafSpawn.targetAspect(targetPosition, askDetectedObject(target, "getVelocity"), capGroupPosition)
              -- A target already tracked is dropped once it is cold; one not tracked (never seen, or just
              -- dropped) is picked up only once it has turned `CAP_COLD_CUTOFF_HYSTERESIS` further in.
              local coldFrom = veafSpawn.CAP_ASPECT_COLD_MIN
              if not targetsList[targetId] then
                coldFrom = coldFrom - veafSpawn.CAP_COLD_CUTOFF_HYSTERESIS
              end
              local targetIsLeaving = targetAngle ~= nil
                and targetAngle >= coldFrom
                and targetDistanceFromCapGroup > veafSpawn.CAP_COLD_CUTOFF
              veaf.loggers.get(veafSpawn.Id):trace("targetAspect=%s, targetIsLeaving=%s", veaf.lp(targetAspect), veaf.lp(targetIsLeaving))
              if targetDistanceFromCapZoneCenter <= capZone.radius and not targetIsLeaving then
                -- consider only the targets that are in the CAP zone

                local targetAttributes = target:getDesc().attributes
                local targetType = target:getTypeName()
                veaf.loggers.get(veafSpawn.Id):trace("targetType=%s", veaf.lp(targetType))
                veaf.loggers.get(veafSpawn.Id):trace("targetAttributes=%s", veaf.lp(targetAttributes))
                veaf.loggers.get(veafSpawn.Id):trace("targetDistanceFromCapGroup=%s", veaf.lp(targetDistanceFromCapGroup))

                -- The ladder below reads the distance weighed by the aspect: a hot target counts as
                -- closer than it is, a cold one as further (`CAP_ASPECT_DISTANCE_FACTOR`). Past
                -- `CAP_COLD_CUTOFF`, a cold target never reaches the ladder at all.
                local rankingDistance = targetDistanceFromCapGroup * veafSpawn.CAP_ASPECT_DISTANCE_FACTOR[targetAspect]

                local targetPriority = nil

                if targetAttributes["Fighters"] or targetAttributes["Multirole fighters"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Fighter")
                  targetPriority = math.floor(rankingDistance / 2)
                elseif targetAttributes["Strategic bombers"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a strategic bomber")
                  targetPriority = math.floor(rankingDistance / 1.5) + 10000
                elseif targetAttributes["Bombers"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a bomber")
                  targetPriority = math.floor(rankingDistance / 1) + 15000
                elseif targetAttributes["UAVs"] and targetType ~= "Yak-52" then --wtf ED, Yak-52 UAV master race
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a UAV (except the Yak-52, that shit is not a UAV ED)")
                  targetPriority = math.floor(rankingDistance / 0.5) + 15000
                elseif targetAttributes["AWACS"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is an AWACS")
                  targetPriority = math.floor(rankingDistance / 0.5) + 15000
                elseif targetAttributes["Transports"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Transport")
                  targetPriority = math.floor(rankingDistance / 0.5) + 15000
                elseif targetAttributes["Battle airplanes"] or targetAttributes["Battleplanes"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a generic Battleplane")
                  targetPriority = math.floor(rankingDistance / 0.25) + 15000
                elseif
                  targetAttributes["Helicopters"]
                  or targetAttributes["Attack helicopters"]
                  or targetAttributes["Transport helicopters"]
                then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Helicopter")
                  targetPriority = math.floor(rankingDistance / 0.1) + 20000
                else
                  veaf.loggers.get(veafSpawn.Id):trace("Target has unknown attributes, calculating generic priority")
                  targetPriority = math.floor(rankingDistance / 0.25) + 15000
                end
                -- https://www.geogebra.org/calculator if you want to visualize, type in functions y=x/factor + offset and set points on each curve. y is the priority, x the distance

                veaf.loggers.get(veafSpawn.Id):trace("priority=%s", veaf.lp(targetPriority))

                local targetData = targetsList[targetId]
                if targetData then
                  -- this target has already been detected; was it in the same run, by another plane from the CAP group ?
                  if targetData.seenAt == timestamp then
                    -- yes, we can only increase the priority (never decrease it)
                    veaf.loggers.get(veafSpawn.Id):debug("redetection (same run) of targetName=%s", veaf.lp(targetName))
                    if targetData.priority < targetPriority then
                      veaf.loggers
                        .get(veafSpawn.Id)
                        :debug("increasing priority of targetName=%s to %s", veaf.lp(targetName), veaf.lp(targetPriority))
                      targetData.priority = targetPriority
                    end
                  else
                    -- no, it's an old target, let's mark it as old
                    veaf.loggers.get(veafSpawn.Id):debug("redetection (previous run) of targetName=%s", veaf.lp(targetName))
                    targetData.isNew = false
                    -- This is a *tracking* list: a target the CAP still has on radar is not a stale
                    -- one. Leaving `seenAt` at the first sighting made every contact expire after
                    -- `CAP_WATCHDOG_DELAY * 2` and be re-registered as brand new on the next tick —
                    -- the endless "new detection of targetName=..." the 2026-09-01 log is full of, and
                    -- a fresh `EngageUnit` pushed onto the AI every couple of ticks for a target it
                    -- was already attacking.
                    targetData.seenAt = timestamp
                    targetData.priority = targetPriority
                    targetData.target = target
                  end
                else
                  -- new target! register in into the target list
                  veaf.loggers
                    .get(veafSpawn.Id)
                    :debug("new detection of targetName=%s, priority=%s", veaf.lp(targetName), veaf.lp(targetPriority))
                  -- `target`, not the CAP aircraft that saw it. The field used to hold the *detecting*
                  -- unit, so the freshness check below asked whether the patrol's own aeroplane was
                  -- still flying instead of whether the enemy was still there. On 2026-09-01 that made
                  -- a watchdog throw away four freshly detected F-14s in the same tick it registered
                  -- them, engaging nothing while reporting that it had targets.
                  targetsList[targetId] =
                    { isNew = true, seenAt = timestamp, priority = targetPriority, targetId = targetId, target = target }
                end
              elseif targetIsLeaving then
                -- dropped now rather than left to expire, so a chase in progress stops on this tick
                veaf.loggers.get(veafSpawn.Id):debug("targetName=%s is leaving, not chasing it", veaf.lp(targetName))
                targetsList[targetId] = nil
              end
            end
          end
        end
      end
    end
  end

  if not capLanded then
    veafSpawn.capWatchdogFlown[capGroupName] = true
  elseif not veafSpawn.capWatchdogFlown[capGroupName] then
    -- still on its parking spot or its runway: it has not taken off yet, it has not landed
    veaf.loggers.get(veafSpawn.Id):debug("CAP group %s has not taken off yet, waiting for it", veaf.lp(capGroupName))
    veaf.scheduleFunction(
      veafSpawn.startCapWatchdog,
      { capGroupName, capCoalition, capZone, targetsList, engagedTargetIds },
      timer.getTime() + veafSpawn.CAP_WATCHDOG_DELAY
    )
    return
  end

  if capLanded then
    forgetCapWatchdog(capGroupName)
    capGroup:destroy()
    veaf.loggers.get(veafSpawn.Id):debug("CAP group %s is landed, destroying it and stopping watchdog", veaf.lp(capGroupName))
    return
  end

  local controller = capGroup:getController()
  if capInZone then
    veaf.loggers.get(veafSpawn.Id):debug("CAP group is still in the CAP zone...")
    if not controller then
      veaf.loggers.get(veafSpawn.Id):error("cannot find controller for CAP group!")
      forgetCapWatchdog(capGroupName)
      return
    end

    -- The list is keyed by DCS unit id, so it is a map and never an array: `#targetsList` is 0 and
    -- `table.sort` on it sorted nothing at all, which is how the priority ladder computed above came
    -- to decide nothing. Copied into a real array first, and iterated from that copy — which also
    -- makes it safe to delete entries from the map while walking it.
    --
    -- Sorted in reverse priority order so that the last task pushed — the one that ends up on top of
    -- the controller's stack — is the lowest-priority one. That is the original author's call, kept.
    local sortedTargets = {}
    for _, targetData in pairs(targetsList) do
      table.insert(sortedTargets, targetData)
    end
    table.sort(sortedTargets, function(a, b)
      return a.priority < b.priority
    end)
    veaf.loggers.get(veafSpawn.Id):trace("targetsList=%s", veaf.lp(targetsList))

    -- What is worth engaging this tick. Counted from targets actually **engaged**, not targets listed:
    -- the count used to be set on the first entry of the list, before that entry had been checked, so a
    -- list holding nothing but stale contacts still lifted `PROHIBIT_AA` and skipped the branch that
    -- hands the CAP back its patrol — "they never returned fire", from the cockpit.
    local toEngage = {}
    local toEngageIds = {}
    for _, targetData in ipairs(sortedTargets) do
      local targetId = targetData.targetId
      if
        not veafSpawn.isCapEngageableTarget(targetData.target, capCoalition)
        or timestamp > targetData.seenAt + veafSpawn.CAP_WATCHDOG_DELAY * 2
      then
        veaf.loggers.get(veafSpawn.Id):trace("Target is outdated, landed or doesn't exist, removing it from the list")
        targetsList[targetId] = nil
      else
        table.insert(toEngage, targetData)
        toEngageIds[targetId] = true
      end
    end

    -- The controller is touched only when the set of targets changed. An `EngageUnit` used to be pushed
    -- for every target on every tick, so a CAP tracking five aircraft stacked five more tasks each ten
    -- seconds — the counter read 38, 43, 49 in game on 2026-10-03 — and no task could ever be taken
    -- back individually: `popTask` only removes the top of the queue. So a target **leaving** rebuilds
    -- the queue instead of patching it — the patrol handed back whole, then one task per target still
    -- there — and a target **arriving** only gets its own task, so the ones in progress are not cut.
    local someLeft = false
    for targetId in pairs(engagedTargetIds) do
      if not toEngageIds[targetId] then
        someLeft = true
      end
    end
    local rebuilt = someLeft and veafAircraftSpawn.resumePatrol(capGroupName)
    for _, targetData in ipairs(toEngage) do
      -- Without a rebuild (nothing left, or no patrol to hand back) only the newcomers are pushed: pushing
      -- the others again is the accumulation this replaces.
      if rebuilt or not engagedTargetIds[targetData.targetId] then
        veaf.loggers.get(veafSpawn.Id):trace("Engaging target!")
        controller:pushTask({
          id = "EngageUnit",
          params = {
            unitId = targetData.targetId,
            weaponType = "ALL",
            priority = targetData.priority,
          },
        })
      end
    end
    engagedTargetIds = toEngageIds

    -- Each aircraft its own target when there is a choice (FEAT-CAP-WATCHDOG, #187). The group's tasks
    -- above stay as they were; whether DCS lets an aircraft's own task win over them is the in-game check
    -- of the lot. A rebuild sets the group's task again, so the spread is set again on top of it.
    applyCapSpread(capGroupName, capUnits, veafSpawn.spreadCapTargets(spreadUnitNames, toEngage), rebuilt)

    if #toEngage > 0 then
      veaf.loggers.get(veafSpawn.Id):debug("Watchdog has %s target(s) ! Allowing AA for CAP", veaf.lp(#toEngage))
      controller:setOption(AI.Option.Air.id.PROHIBIT_AA, false)
      controller:setOption(0, 0) --weapons free
    else
      veaf.loggers.get(veafSpawn.Id):debug("Watchdog found no targets, the CAP flies its patrol and prohibits AA")
      controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
      controller:setOption(0, 3) --return fire
    end
  else
    veaf.loggers.get(veafSpawn.Id):debug("CAP is outside of its area ! Discarding targets...")
    -- Holding fire is not enough: every `EngageUnit` left on the queue kept the CAP flying after its
    -- targets, out of its zone, weapons safe (ticket 06 of FIX-IN-GAME-SESSION-2026-10-03).
    if next(engagedTargetIds) then
      veafAircraftSpawn.resumePatrol(capGroupName)
      engagedTargetIds = {}
    end
    applyCapSpread(capGroupName, capUnits, {})
    controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
    controller:setOption(0, 3) --return fire
  end

  veaf.loggers.get(veafSpawn.Id):debug(string.format("Rescheduling watchdog in %s seconds", veafSpawn.CAP_WATCHDOG_DELAY))
  veaf.loggers.get(veafSpawn.Id):debug("===============================================================================")
  veaf.scheduleFunction(
    veafSpawn.startCapWatchdog,
    { capGroupName, capCoalition, capZone, targetsList, engagedTargetIds },
    timer.getTime() + veafSpawn.CAP_WATCHDOG_DELAY
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Aircraft spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What a marker asks a spawned helicopter to do, read from its options (FEAT-HELICOPTER-SPAWN): the
--- `task`, the first `dest` point, `alt` (feet above the ground) and `speed` (knots) — the units
--- `-afac` and `-cap` read them in — and `capradius`, the engagement radius in metres. Ignored by any
--- other unit.
--- @param options table the parsed marker options
--- @return table `{ task, destination, altitude, speed, radius }`, altitude in metres and speed in m/s
function veafSpawn.helicopterJob(options)
  local altitude = options.altitude and options.altitude > 0 and options.altitude * 0.3048 or nil
  local speed = options.speed and options.speed > 0 and options.speed / 1.94384 or nil
  return { task = options.task, destination = options.destination, altitude = altitude, speed = speed, radius = options.capradius }
end

veafSpawn.registerCommandHandler("unit", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local code = options.laserCode
  local channel = options.freq
  local band = options.mod
  if options.role == "tacan" then
    channel = options.tacanChannel or 99
    code = options.tacanCode or ("T" .. tostring(channel))
    band = options.tacanBand or "X"
  end
  local g = veafSpawn.spawnUnit(
    eventPos,
    options.radius,
    options.name,
    options.czName,
    options.country,
    options.altitude,
    options.heading,
    options.unitName,
    options.role,
    options.forceStatic,
    code,
    channel,
    band,
    options.silent,
    not options.showMFD,
    veafSpawn.helicopterJob(options)
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("afac", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnAFAC(
    eventPos,
    options.name,
    options.country,
    options.altitude,
    options.speed,
    options.heading,
    options.freq,
    options.mod,
    options.laserCode,
    options.immortal,
    false,
    -- VMR-099: `hiddenOnMFD`, so the flag is negated here as in every other handler. Passing
    -- `options.showMFD` straight through left the AFAC visible on every MFD by default and
    -- hid it when the mission maker asked for it.
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("cap", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnCombatAirPatrol(
    eventPos,
    options.radius,
    options.name,
    options.country,
    options.altitude,
    options.altitudedelta,
    options.heading,
    options.distance,
    options.speed,
    options.capradius,
    options.skill,
    options.silent,
    not options.showMFD -- VMR-099: same inversion as the afac handler above
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("awacs", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  return veafSpawn.spawnAwacs(eventPos, options), nil, false
end)

veafSpawn.registerCommandHandler("escort", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  return veafSpawn.spawnEscortNear(eventPos, options), nil, false
end)
