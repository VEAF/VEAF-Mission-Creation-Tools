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
  hiddenOnMFD
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

  -- cannot spawn planes or helos yet [TODO], however spawning them as a static is fine
  if unit.air and not static then
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
    spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnPosition, radius))
    veaf.loggers
      .get(veafSpawn.Id)
      :trace(string.format("spawnUnit: spawnSpot  x=%.1f y=%.1f, z=%.1f", spawnSpot.x, spawnSpot.y, spawnSpot.z))
    if alt > 0 then
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
    end

    table.insert(units, toInsert)
  end

  veaf.loggers.get(veafSpawn.Id):trace(string.format("unitData = %s", veaf.p(units)))

  -- actually spawn the unit
  if unit.static or static then --if the unit was forced to spawn as a static it could still be an air or a naval unit so this check goes first
    veaf.loggers.get(veafSpawn.Id):trace("Spawning STATIC")
    mist.dynAddStatic({ country = country, groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
    --groupName = nil --statics do not have a group name, you must set groupName to nil to avoid other scripts interacting
  elseif unit.air then
    veaf.loggers.get(veafSpawn.Id):trace("Spawning AIRPLANE")
    mist.dynAdd({ country = country, category = "PLANE", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
  elseif unit.naval then
    veaf.loggers.get(veafSpawn.Id):trace("Spawning SHIP")
    mist.dynAdd({ country = country, category = "SHIP", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
  else
    veaf.loggers.get(veafSpawn.Id):trace("Spawning GROUND_UNIT")
    mist.dynAdd({ country = country, category = "GROUND_UNIT", groupName = groupName, units = units, hiddenOnMFD = hiddenOnMFD })
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
    local _template = VeafAirUnitTemplate:new():setName(_groupName)
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
  local groupName = veafSpawn.findSpawnableAircraftGroupname(name)
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

  veaf.loggers.get(veafSpawn.Id):info(string.format("number of AFAC spawned : %s", veaf.p(veafSpawn.AFAC.numberSpawned[coalition])))

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
  local vars = {}
  vars.gpName = groupName
  vars.name = groupName
  --vars.groupData = _template:getGroupData()
  --replace the callsign to prevent interractions
  vars.route = newRoute
  vars.action = "clone"
  vars.point = teleportSpot
  vars.newGroupName = newGroupName

  local newGroup = mist.teleportToPoint(vars, true)
  if not newGroup then
    veaf.loggers.get(veafSpawn.Id):error("cannot respawn group %s", veaf.p(vars.name))
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
  local _spawnedGroup = mist.dynAdd(newGroup)

  if _spawnedGroup then
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup=%s", veaf.lp(_spawnedGroup, nil, { "route", "payload" }))
    veaf.loggers.get(veafSpawn.Id):trace("_spawnedGroup.name=%s", _spawnedGroup.name)
    --mist.goRoute(_spawnedGroup.name, newRoute)

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
    veaf.loggers.get(veafSpawn.Id):info(text)
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
      :info(string.format("AFAC named=%s is KIA, removing mark (if it exists) and allowing it to be spawned again", veaf.p(afacGroupName)))
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

function veafSpawn.findSpawnableAircraftGroupname(name)
  -- find template amongst the existing templates (name can be a regex)
  local nameUpper = (name or ""):upper()
  local regexNameUpper = ".*" .. (nameUpper or ".*") .. ".*"
  if not name then
    regexNameUpper = ".*"
  end
  local escapedNameUpper = veaf.escapeRegex(nameUpper)
  veaf.loggers.get(veafSpawn.Id):trace("nameUpper=%s", veaf.lp(nameUpper))
  local templatesNamesToChooseFrom = {}
  local chosenTemplateName = nil
  for templateNameUpper, templateData in pairs(veafSpawn.airUnitTemplates) do
    veaf.loggers.get(veafSpawn.Id):trace("templateNameUpper=%s", veaf.lp(templateNameUpper))
    if templateNameUpper:match(regexNameUpper) or templateNameUpper:match(escapedNameUpper) then
      local templateName = templateData.name
      veaf.loggers.get(veafSpawn.Id):trace("templateName=%s", veaf.lp(templateName))
      table.insert(templatesNamesToChooseFrom, templateName)
    end
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
  local chosenTemplateName, chosenTemplateData = veafSpawn.findSpawnableAircraftGroupname(name)
  if not chosenTemplateName or not chosenTemplateData then
    veaf.loggers.get(veafSpawn.Id):error("spawnCombatAirPatrol: could not find a template for %s", veaf.p(name))
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
  local speed0 = convertSpeeds(speed, 0.3, altitude)
  local speed1 = convertSpeeds(speed, 0.5, altitude)
  local speed2 = convertSpeeds(speed, 0.63, altitude)
  local speed3 = convertSpeeds(speed, 0.63, altitude)
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
  veaf.loggers.get(veafSpawn.Id):trace("speed0=%s", veaf.lp(speed0))
  veaf.loggers.get(veafSpawn.Id):trace("speed1=%s", veaf.lp(speed1))
  veaf.loggers.get(veafSpawn.Id):trace("speed2=%s", veaf.lp(speed2))
  veaf.loggers.get(veafSpawn.Id):trace("speed3=%s", veaf.lp(speed3))
  veaf.loggers.get(veafSpawn.Id):trace("capRadius=%s", veaf.lp(capRadius))
  veaf.loggers.get(veafSpawn.Id):trace("skill=%s", veaf.lp(skill))
  veaf.loggers.get(veafSpawn.Id):trace("silent=%s", veaf.lp(silent))
  veaf.loggers.get(veafSpawn.Id):trace("hiddenOnMFD=%s", veaf.lp(hiddenOnMFD))

  local getRoute = function(parameters)
    local newRoute = {
      ["points"] = {
        [1] = {
          ["alt"] = parameters.altitude,
          ["action"] = "Turning Point",
          ["alt_type"] = "BARO",
          ["speed"] = parameters.speed1,
          ["properties"] = {
            ["addopt"] = {}, -- end of ["addopt"]
          }, -- end of ["properties"]
          ["task"] = parameters.wp1Options,
          ["type"] = "Turning Point",
          ["ETA"] = 10000,
          ["ETA_locked"] = false,
          ["y"] = parameters.wp1.y,
          ["x"] = parameters.wp1.x,
          ["formation_template"] = "",
          ["speed_locked"] = true,
        }, -- end of [1]
        [2] = {
          ["alt"] = parameters.altitude,
          ["action"] = "Turning Point",
          ["alt_type"] = "BARO",
          ["speed"] = parameters.speed2,
          ["properties"] = {
            ["addopt"] = {}, -- end of ["addopt"]
          }, -- end of ["properties"]
          ["task"] = {
            ["id"] = "ComboTask",
            ["params"] = {
              ["tasks"] = {
                -- [1] =
                -- {
                --     ["number"] = 1,
                --     ["auto"] = false,
                --     ["enabled"] = true,
                --     ["id"] = "EngageTargetsInZone",
                --     ["params"] = {
                --         ["noTargetTypes"] = {
                --             [1] = "Cruise missiles",
                --             [2] = "Antiship Missiles",
                --             [3] = "AA Missiles",
                --             [4] = "AG Missiles",
                --             [5] = "SA Missiles",
                --         }, -- end of ["noTargetTypes"]
                --         ["priority"] = 0,
                --         ["targetTypes"] = {
                --             [1] = "Air",
                --         }, -- end of ["targetTypes"]
                --         ["value"] = "Air;",
                --         ["x"] = parameters.targetZone.x,
                --         ["y"] = parameters.targetZone.y,
                --         ["zoneRadius"] = parameters.targetZone.radius,
                --     }, -- end of ["params"]
                -- }, -- end of [1]
              }, -- end of ["tasks"]
            }, -- end of ["params"]
          }, -- end of ["task"]
          ["type"] = "Turning Point",
          ["ETA"] = 20000,
          ["ETA_locked"] = false,
          ["y"] = parameters.wp2.y,
          ["x"] = parameters.wp2.x,
          ["formation_template"] = "",
          ["speed_locked"] = true,
        }, -- end of [2]
        [3] = {
          ["alt"] = parameters.altitude,
          ["action"] = "Turning Point",
          ["alt_type"] = "BARO",
          ["speed"] = parameters.speed3,
          ["properties"] = {
            ["addopt"] = {}, -- end of ["addopt"]
          }, -- end of ["properties"]
          ["task"] = {
            ["id"] = "ComboTask",
            ["params"] = {
              ["tasks"] = {
                [1] = {
                  ["enabled"] = true,
                  ["auto"] = false,
                  ["id"] = "WrappedAction",
                  ["number"] = 1,
                  ["params"] = {
                    ["action"] = {
                      ["id"] = "SwitchWaypoint",
                      ["params"] = {
                        ["goToWaypointIndex"] = 2,
                        ["fromWaypointIndex"] = 3,
                      }, -- end of ["params"]
                    }, -- end of ["action"]
                  }, -- end of ["params"]
                }, -- end of [1]
              }, -- end of ["tasks"]
            }, -- end of ["params"]
          }, -- end of ["task"]
          ["type"] = "Turning Point",
          ["ETA"] = 30000,
          ["ETA_locked"] = false,
          ["y"] = parameters.wp3.y,
          ["x"] = parameters.wp3.x,
          ["formation_template"] = "",
          ["speed_locked"] = true,
        }, -- end of [3]
      },
    }

    return newRoute
  end

  -- find spawn spot
  if altitudeDelta then
    altitude = altitude + math.random(0, altitudeDelta * 2) - altitudeDelta
  end
  local position = mist.getRandPointInCircle(spawnSpot, radius)
  position.z = position.y
  position.y = altitude
  veaf.loggers.get(veafSpawn.Id):debug("final spawn, position=%s", position)

  -- get the template first waypoint's options
  veaf.loggers.get(veafSpawn.Id):trace("chosenTemplateData=%s", veaf.lp(chosenTemplateData))
  local chosenTemplateWp1Task = nil
  if chosenTemplateData then
    local _route = chosenTemplateData.route
    --veaf.loggers.get(veafSpawn.Id):trace("_route=%s", veaf.p(_route))
    if _route then
      local _points = _route.points
      --veaf.loggers.get(veafSpawn.Id):trace("_points=%s", veaf.p(_points))
      if _points then
        local _point1 = _points[1]
        --veaf.loggers.get(veafSpawn.Id):trace("_point1=%s", veaf.p(_point1))
        if _point1 then
          local _task = _point1.task
          --veaf.loggers.get(veafSpawn.Id):trace("_task=%s", veaf.p(_task))
          if _task and "ComboTask" == _task.id then
            local _params = _task.params
            --veaf.loggers.get(veafSpawn.Id):trace("_params=%s", veaf.p(_params))
            if _params then
              local _tasks = _params.tasks
              --veaf.loggers.get(veafSpawn.Id):trace("_tasks=%s", veaf.p(_tasks))
              if _tasks then
                for _, _taskData in pairs(_tasks) do
                  if "WrappedAction" == _taskData.id then
                    chosenTemplateWp1Task = veaf.deepCopy(_task) -- if we found a WrappedAction task then we're on the right way, clone the whole task package
                    break
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  --veaf.loggers.get(veafSpawn.Id):trace("chosenTemplateWp1Task=%s", veaf.p(chosenTemplateWp1Task))

  -- compute route
  local headingRad = math.rad(hdg)
  local parameters = {
    altitude = altitude,
    speed0 = speed0,
    speed1 = speed1,
    speed2 = speed2,
    speed3 = speed3,
    wp1 = { x = position.x, y = position.z },
    wp1Options = chosenTemplateWp1Task,
  }
  parameters.wp2 = { x = parameters.wp1.x + 2500 * math.cos(headingRad), y = parameters.wp1.y + 2500 * math.sin(headingRad) } -- second wp at 2500m in the right direction
  parameters.wp3 = { x = parameters.wp2.x + distance * math.cos(headingRad), y = parameters.wp2.y + distance * math.sin(headingRad) } -- last wp at the right distance in the right direction
  parameters.targetZone =
    { x = (parameters.wp2.x + parameters.wp3.x) / 2, y = (parameters.wp2.y + parameters.wp3.y) / 2, radius = capRadius } -- target zone at the middle point between wp2 and wp3

  veaf.loggers.get(veafSpawn.Id):trace("to create route, parameters=%s", parameters)
  local newRoute = getRoute(parameters)

  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp1", parameters.wp1)
  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp2", parameters.wp2)
  veafSpawn.traceMarkerId = veaf.loggers.get(veafSpawn.Id):marker(veafSpawn.traceMarkerId, "CAP", "wp3", parameters.wp3)
  veafSpawn.traceMarkerId = veaf.loggers
    .get(veafSpawn.Id)
    :marker(veafSpawn.traceMarkerId, "CAP", "targetZone", parameters.targetZone, nil, capRadius, { 1, 0, 0, 0.15 })

  if not veafSpawn.spawnedNamesIndex[chosenTemplateName] then
    veafSpawn.spawnedNamesIndex[chosenTemplateName] = 1
  else
    veafSpawn.spawnedNamesIndex[chosenTemplateName] = veafSpawn.spawnedNamesIndex[chosenTemplateName] + 1
  end
  local newGroupName = string.format("%s #%04d", chosenTemplateName, veafSpawn.spawnedNamesIndex[chosenTemplateName])
  veaf.loggers.get(veafSpawn.Id):debug("indexed newGroupName=%s", newGroupName)

  -- (re)spawn group
  local vars = {}
  vars.gpName = chosenTemplateName
  vars.name = chosenTemplateName
  --vars.groupData = _template:getGroupData()
  vars.route = newRoute
  vars.action = "clone"
  vars.point = position
  vars.newGroupName = newGroupName

  local newGroup = mist.teleportToPoint(vars, true)
  if not newGroup then
    veaf.loggers.get(veafSpawn.Id):error("cannot respawn group %s", veaf.p(vars.name))
    return nil
  end
  if country and #country > 0 then
    newGroup.countryId = veaf.getCountryId(country)
  end
  --newGroup.task = "CAP" --needs to be set in the editor
  veaf.loggers.get(veafSpawn.Id):trace("after preparation by MIST, newGroup=%s", veaf.lp(newGroup, nil, { "route", "payload" }))

  newGroup.hidden = false
  newGroup.name = newGroupName
  newGroup.hiddenOnMFD = hiddenOnMFD

  for _, unit in pairs(newGroup.units) do
    unit.skill = skill
    local unitName = unit.unitName or unit.name
    veaf.loggers.get(veafSpawn.Id):trace("original unitName=%s", unitName)
    if not veafSpawn.spawnedNamesIndex[unitName] then
      veafSpawn.spawnedNamesIndex[unitName] = 1
    else
      veafSpawn.spawnedNamesIndex[unitName] = veafSpawn.spawnedNamesIndex[unitName] + 1
    end
    local spawnedUnitName = string.format("%s #%04d", unitName, veafSpawn.spawnedNamesIndex[unitName])
    unit.name = spawnedUnitName
    unit.alt = position.y
    veaf.loggers.get(veafSpawn.Id):debug("indexed spawnedUnitName=%s", spawnedUnitName)
  end

  veaf.loggers.get(veafSpawn.Id):trace("before mist.dynAdd, newGroup=%s", veaf.lp(newGroup, nil, { "route", "payload" }))
  local _spawnedGroup = mist.dynAdd(newGroup)
  if not _spawnedGroup then
    veaf.loggers.get(veafSpawn.Id):error("cannot spawn group %s", veaf.p(newGroup.name))
    return nil
  end
  veaf.loggers.get(veafSpawn.Id):debug("after mist.dynAdd, _spawnedGroup.name=%s", _spawnedGroup.name)
  veaf.loggers.get(veafSpawn.Id):trace("after mist.dynAdd, _spawnedGroup=%s", veaf.lp(_spawnedGroup, nil, { "route", "payload" }))

  local _dcsSpawnedGroup = Group.getByName(_spawnedGroup.name)
  veaf.loggers
    .get(veafSpawn.Id)
    :trace("result of dcs side getByName, _dcsSpawnedGroup=%s", veaf.lp(_dcsSpawnedGroup, nil, { "route", "payload" }))
  veaf.loggers.get(veafSpawn.Id):debug("result of dcs side getByName, _dcsSpawnedGroup.name=%s", _dcsSpawnedGroup:getName())
  for index, unit in pairs(_dcsSpawnedGroup:getUnits()) do
    veaf.loggers.get(veafSpawn.Id):debug("result of dcs side getByName, _dcsSpawnedGroup.unit[%s].name=%s", index, unit:getName())
  end

  local controller = _dcsSpawnedGroup:getController()
  controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)

  veaf.loggers.get(veafSpawn.Id):debug("starting CAP target watchdog...")
  veaf.scheduleFunction(veafSpawn.startCapWatchdog, { _spawnedGroup.name, coalition, parameters.targetZone }, timer.getTime() + 1)

  local message = string.format("A CAP of %s (%s) has been spawned", name, country)
  veaf.loggers.get(veafSpawn.Id):info(message)
  if not silent then
    trigger.action.outText(veaf.t("spawn.cap_spawned", name, country), 15)
  end

  return _spawnedGroup.name
end

function veafSpawn.startCapWatchdog(capGroupName, capCoalition, capZone, pTargetsList, pNumberOfTasksAddedByWatchdog)
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

  local capGroup = Group.getByName(capGroupName)
  if not capGroup then
    veaf.loggers.get(veafSpawn.Id):debug("CAP group %s is nowhere to be found, stopping watchdog", veaf.lp(capGroupName))
    return
  end
  local capGroupPosition = veaf.getAveragePosition(capGroup)
  if not capGroupPosition then
    veaf.loggers.get(veafSpawn.Id):error("CAP group %s has no position!", veaf.p(capGroupName))
    return
  end

  veaf.loggers.get(veafSpawn.Id):trace("Looking in CAP zone for targets...")
  local timestamp = timer.getTime()
  local targetsList = pTargetsList or {}
  local numberOfTasksAddedByWatchdog = pNumberOfTasksAddedByWatchdog or 0
  veaf.loggers.get(veafSpawn.Id):trace("targetsList=%s", veaf.lp(targetsList))
  veaf.loggers.get(veafSpawn.Id):trace("numberOfTasksAddedByWatchdog=%s", veaf.lp(numberOfTasksAddedByWatchdog))

  -- check CAP group for state and position
  local capLanded = true
  local capInZone = false
  for _, unit in pairs(capGroup:getUnits()) do
    if unit and unit:inAir() then
      capLanded = false
      local isUnitInZone = veaf.isUnitInZone(unit, capZone)
      veaf.loggers.get(veafSpawn.Id):trace("unitName=%s, isUnitInZone=%s", veaf.lp(unit:getName()), veaf.lp(isUnitInZone))
      if isUnitInZone then
        capInZone = true
        -- unit is in the zone, and in the air, let's test the targets it can see
        local detectedTargets = unit:getController():getDetectedTargets()
        if detectedTargets and #detectedTargets > 0 then
          -- process each target and compute its priority, then add it to the targets list
          for _, detectedTarget in pairs(detectedTargets) do
            local target = detectedTarget.object
            local targetId = target:getID()
            local targetGroup = target:getGroup()
            local targetGroupName = targetGroup:getName()
            local targetName = target:getName()
            veaf.loggers.get(veafSpawn.Id):trace(
              "Checking targetGroupName=%s, targetName=%s, targetId=%s",
              veaf.lp(targetGroupName),
              veaf.lp(targetName),
              veaf.lp(targetId)
            )
            local targetIsAirborne = target:isActive() and target:inAir()
            local targetCoalition = target:getCoalition()
            local targetGroupCategory = targetGroup:getCategory()
            veaf.loggers.get(veafSpawn.Id):trace("targetIsAirborne=%s", veaf.lp(targetIsAirborne))
            veaf.loggers.get(veafSpawn.Id):trace("targetCoalition=%s", veaf.lp(targetCoalition))
            veaf.loggers.get(veafSpawn.Id):trace("targetGroupCategory=%s", veaf.lp(targetGroupCategory))

            if
              targetIsAirborne ~= nil
              and targetGroupCategory ~= nil
              and targetCoalition ~= nil
              and targetCoalition ~= capCoalition
              and (targetGroupCategory == Group.Category.AIRPLANE or targetGroupCategory == Group.Category.HELICOPTER)
            then
              local targetPosition = target:getPosition().p
              local targetDistanceFromCapZoneCenter = veaf.get2DDist(targetPosition, capZone)
              veaf.loggers.get(veafSpawn.Id):trace("targetPosition=%s", veaf.lp(targetPosition))
              veaf.loggers.get(veafSpawn.Id):trace("targetDistanceFromCapZoneCenter=%s", veaf.lp(targetDistanceFromCapZoneCenter))
              if targetDistanceFromCapZoneCenter <= capZone.radius then
                -- consider only the targets that are in the CAP zone

                local targetAttributes = target:getDesc().attributes
                local targetType = target:getTypeName()
                local targetDistanceFromCapGroup = veaf.get2DDist(targetPosition, capGroupPosition)
                veaf.loggers.get(veafSpawn.Id):trace("targetType=%s", veaf.lp(targetType))
                veaf.loggers.get(veafSpawn.Id):trace("targetAttributes=%s", veaf.lp(targetAttributes))
                veaf.loggers.get(veafSpawn.Id):trace("targetDistanceFromCapGroup=%s", veaf.lp(targetDistanceFromCapGroup))

                local targetPriority = nil

                if targetAttributes["Fighters"] or targetAttributes["Multirole fighters"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Fighter")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 2)
                elseif targetAttributes["Strategic bombers"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a strategic bomber")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 1.5) + 10000
                elseif targetAttributes["Bombers"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a bomber")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 1) + 15000
                elseif targetAttributes["UAVs"] and targetType ~= "Yak-52" then --wtf ED, Yak-52 UAV master race
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a UAV (except the Yak-52, that shit is not a UAV ED)")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.5) + 15000
                elseif targetAttributes["AWACS"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is an AWACS")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.5) + 15000
                elseif targetAttributes["Transports"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Transport")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.5) + 15000
                elseif targetAttributes["Battle airplanes"] or targetAttributes["Battleplanes"] then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a generic Battleplane")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.25) + 15000
                elseif
                  targetAttributes["Helicopters"]
                  or targetAttributes["Attack helicopters"]
                  or targetAttributes["Transport helicopters"]
                then
                  veaf.loggers.get(veafSpawn.Id):trace("Target is a Helicopter")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.1) + 20000
                else
                  veaf.loggers.get(veafSpawn.Id):trace("Target has unknown attributes, calculating generic priority")
                  targetPriority = math.floor(targetDistanceFromCapGroup / 0.25) + 15000
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
                  end
                else
                  -- new target! register in into the target list
                  veaf.loggers
                    .get(veafSpawn.Id)
                    :debug("new detection of targetName=%s, priority=%s", veaf.lp(targetName), veaf.lp(targetPriority))
                  targetsList[targetId] = { isNew = true, seenAt = timestamp, priority = targetPriority, targetId = targetId, unit = unit }
                end
              end
            end
          end
        end
      end
    end
  end

  if capLanded then
    capGroup:destroy()
    veaf.loggers.get(veafSpawn.Id):debug("CAP group %s is landed, destroying it and stopping watchdog", veaf.lp(capGroupName))
    return
  end

  local controller = capGroup:getController()
  if capInZone then
    veaf.loggers.get(veafSpawn.Id):debug("CAP group is still in the CAP zone...")
    if not controller then
      veaf.loggers.get(veafSpawn.Id):error("cannot find controller for CAP group!")
      return
    end

    controller:setOption(AI.Option.Air.id.PROHIBIT_AA, false)
    controller:setOption(0, 0) --weapons free
    --sort the list in reverse priority order so that the last task to be pushed in spot #1 is the one with the lowest priority, couldn't quite figure out which way works best, since this one makes the least sense it seems appropriate for DCS
    table.sort(targetsList, function(a, b)
      return a.priority < b.priority
    end)
    veaf.loggers.get(veafSpawn.Id):trace("targetsList=%s", veaf.lp(targetsList))
    local foundTargets = false
    for targetId, targetData in pairs(targetsList) do
      if not foundTargets then
        -- only write that once!
        veaf.loggers.get(veafSpawn.Id):debug("Watchdog has targets ! Allowing AA for CAP")
        foundTargets = true
      end
      if
        not Unit.isExist(targetData.unit)
        or not targetData.unit:inAir()
        or timestamp > targetData.seenAt + veafSpawn.CAP_WATCHDOG_DELAY * 2
      then
        veaf.loggers.get(veafSpawn.Id):trace("Target is outdated, landed or doesn't exist, removing it from the list")
        targetsList[targetId] = nil
      else
        veaf.loggers.get(veafSpawn.Id):trace("Engaging target!")
        local engageUnit = {
          id = "EngageUnit",
          params = {
            unitId = targetId,
            weaponType = "ALL",
            priority = targetData.priority,
          },
        }
        controller:pushTask(engageUnit)
        numberOfTasksAddedByWatchdog = numberOfTasksAddedByWatchdog + 1
      end
    end

    if not foundTargets then
      -- no targets, let's remove all the tasks we added (taking care not to remove the original task, which is to fly along the route)
      veaf.loggers.get(veafSpawn.Id):debug("Watchdog found no targets, removing all tasks and prohibiting AA for CAP")
      while controller:hasTask() and numberOfTasksAddedByWatchdog > 0 do
        veaf.loggers.get(veafSpawn.Id):trace("numberOfTasksAddedByWatchdog=%s", veaf.lp(numberOfTasksAddedByWatchdog))
        controller:resetTask()
        veaf.loggers.get(veafSpawn.Id):trace("resetTask() called")
        numberOfTasksAddedByWatchdog = numberOfTasksAddedByWatchdog - 1
      end
      controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
      controller:setOption(0, 3) --return fire
    end
  else
    veaf.loggers.get(veafSpawn.Id):debug("CAP is outside of its area ! Discarding targets...")
    controller:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
    controller:setOption(0, 3) --return fire
  end

  veaf.loggers.get(veafSpawn.Id):debug(string.format("Rescheduling watchdog in %s seconds", veafSpawn.CAP_WATCHDOG_DELAY))
  veaf.loggers.get(veafSpawn.Id):debug("===============================================================================")
  veaf.scheduleFunction(
    veafSpawn.startCapWatchdog,
    { capGroupName, capCoalition, capZone, targetsList, numberOfTasksAddedByWatchdog },
    timer.getTime() + veafSpawn.CAP_WATCHDOG_DELAY
  )
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Aircraft spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

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
    not options.showMFD
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
