------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- Ground spawn sub-module: FARP, FOB, infantry, armored, air defense, convoy
-- Part of veafSpawn.lua split (LUAR-001)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

--- Spawn a FARP
function veafSpawn.spawnFarp(
  spawnSpot,
  radius,
  name,
  country,
  farptype,
  side,
  hdg,
  spacing,
  silent,
  hiddenOnMFD,
  noFarpMarkers,
  code,
  freq,
  mod
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnFarp(name=%s, country=%s, farptype=%s, side=%s, hdg=%s, spacing=%s, silent=%s, hiddenOnMFD=%s, noFarpMarkers=%s)",
    veaf.lp(name),
    veaf.lp(country),
    veaf.lp(farptype),
    veaf.lp(side),
    veaf.lp(hdg),
    veaf.lp(spacing),
    veaf.lp(silent),
    veaf.lp(hiddenOnMFD),
    veaf.lp(noFarpMarkers)
  )

  local radius = radius or 0
  local name = name
  local hdg = hdg or 0
  local side = side or 1
  local country = country or "usa"
  local farptype = farptype or ""
  local noFarpMarkers = noFarpMarkers or false

  local spawnPosition = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers.get(veafSpawn.Id):trace("spawnPosition=%s", veaf.lp(spawnPosition))
  if not name or name == "" then
    local _lat, _lon = coord.LOtoLL(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace("_lat=%s", veaf.lp(_lat))
    veaf.loggers.get(veafSpawn.Id):trace("_lon=%s", veaf.lp(_lon))
    local _mgrs = coord.LLtoMGRS(_lat, _lon)
    veaf.loggers.get(veafSpawn.Id):trace("_mgrs=%s", veaf.lp(_mgrs))
    local _UTM = _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
    name = "FARP " .. _UTM:upper() .. "-" .. timer.getTime()
  end

  local _type = "Invisible FARP"
  local _shape = "invisiblefarp"
  if farptype:lower() == "quad" then
    _type = "FARP"
    _shape = "FARPs"
  elseif farptype:lower() == "single" then
    _type = "FARP"
    _shape = "FARP"
  elseif farptype:lower() == "pad" then
    _type = "FARP_SINGLE_01"
    _shape = "FARP_SINGLE_01"
  elseif farptype:lower() == "invisible" then
    _type = "Invisible FARP"
    _shape = "invisiblefarp"
  end

  -- spawn the FARP
  local _farpStatic = {
    ["category"] = "Heliports",
    ["shape_name"] = _shape,
    ["type"] = _type,
    ["unitId"] = mist.getNextUnitId(),
    ["y"] = spawnPosition.z,
    ["x"] = spawnPosition.x,
    ["groupName"] = name,
    ["name"] = name,
    ["canCargo"] = false,
    ["heading"] = mist.utils.toRadian(hdg),
    ["country"] = country,
    ["coalition"] = side,
    ["dead"] = false,
    ["dynamicCargo"] = true,
    ["dynamicSpawn"] = true,
    ["allowHotStart"] = true,
    --["unlimitedAircrafts"] = true,
    ["unlimitedFuel"] = true,
    ["unlimitedMunitions"] = true,
  }
  mist.dynAddStatic(_farpStatic)
  local _spawnedFARP = StaticObject.getByName(name)
  veaf.loggers.get(veafSpawn.Id):trace("_spawnedFARP=%s", veaf.lp(_spawnedFARP))

  if _spawnedFARP then
    veaf.loggers.get(veafSpawn.Id):debug("Spawned the FARP static %s", veaf.lp(name))

    -- populate the FARP but make the units invisible to MFDs as they are redundant (FARP already shows if wanted)
    veafGrass.buildFarpUnits(_farpStatic, nil, name, hiddenOnMFD, noFarpMarkers, code, freq, mod)
  end

  return name
end

--- Spawn a FARP
function veafSpawn.spawnFob(spawnSpot, radius, name, country, fobtype, side, hdg, spacing, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnFob(name=%s, country=%s, fobtype=%s, side=%s, hdg=%s, spacing=%s, silent=%s, hiddenOnMFD=%s)",
    veaf.lp(name),
    veaf.lp(country),
    veaf.lp(fobtype),
    veaf.lp(side),
    veaf.lp(hdg),
    veaf.lp(spacing),
    veaf.lp(silent),
    veaf.lp(hiddenOnMFD)
  )
  local TOWER_DISTANCE = 20
  local BEACON_DISTANCE = 3

  -- veaf.ctld_initialized went with the v1 init wrapper. CTLD 2 is a registered VEAF module,
  -- so the framework's own gate answers the same question — and answers it correctly when the
  -- mission disabled the module rather than merely failing to load the script.
  if not (ctld and veaf.isEnabled("ctld")) then
    veaf.loggers.get(veafSpawn.Id):error("spawnFob([%s]): cannot spawn FOB without CTLD!)", veaf.p(name))
    return nil
  end

  local _radius = radius or 0
  local _fobName = name
  local _side = side or 1
  local _country = country or "usa"
  local _fobtype = fobtype or "" -- only a single FOB type in CTLD, yet
  local _hdg = hdg or 0

  local _spawnPosition = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, _radius))
  veaf.loggers.get(veafSpawn.Id):trace("spawnPosition=%s", veaf.lp(_spawnPosition))
  if not _fobName or _fobName == "" then
    local _lat, _lon = coord.LOtoLL(spawnSpot)
    veaf.loggers.get(veafSpawn.Id):trace("_lat=%s", veaf.lp(_lat))
    veaf.loggers.get(veafSpawn.Id):trace("_lon=%s", veaf.lp(_lon))
    local _mgrs = coord.LLtoMGRS(_lat, _lon)
    veaf.loggers.get(veafSpawn.Id):trace("_mgrs=%s", veaf.lp(_mgrs))
    local _UTM = _mgrs.MGRSDigraph .. math.floor(_mgrs.Easting / 1000) .. math.floor(_mgrs.Northing / 1000)
    _fobName = "FOB " .. _UTM:upper()
  end

  -- make name unique
  _fobName = string.format("%s #%i", _fobName, veaf.getUniqueIdentifier())

  -- spawn the FOB buildings
  local _outpost = {
    category = "Fortifications",
    type = "outpost",
    y = _spawnPosition.z,
    x = _spawnPosition.x,
    name = _fobName,
    canCargo = false,
    heading = mist.utils.toRadian(hdg),
    country = _country,
  }
  mist.dynAddStatic(_outpost)
  local _fob = StaticObject.getByName(_outpost["name"])

  local _tower = {
    type = "house2arm",
    rate = 100,
    y = _outpost.y + TOWER_DISTANCE * math.sin(mist.utils.toRadian(_hdg)),
    x = _outpost.x + TOWER_DISTANCE * math.cos(mist.utils.toRadian(_hdg)),
    name = _fobName .. " Watchtower #002",
    category = "Fortifications",
    canCargo = false,
    heading = mist.utils.toRadian(_hdg),
    country = _country,
  }
  mist.dynAddStatic(_tower)

  -- add the FOB to the named points
  local _namedPoint = _spawnPosition
  _namedPoint.atc = true
  _namedPoint.runways = {}

  if ctld and veaf.isEnabled("ctld") then
    -- make it able to deploy crates and pickup troops. CTLD 2 owns the FOB list itself
    -- (CTLDFOBManager), so the logistic zone is the only thing we declare.
    CTLDZoneManager.getInstance():registerFOBAsLogistic(_fobName, _spawnPosition, nil, _side)

    -- spawn a beacon. Its name is CTLD's to allocate now — the "FOB Beacon #N" counter
    -- VEAF kept was a second numbering next to the manager's own.
    local _beaconPoint = {
      z = _tower.y + BEACON_DISTANCE * math.sin(mist.utils.toRadian(_hdg)),
      x = _tower.x + BEACON_DISTANCE * math.cos(mist.utils.toRadian(_hdg)),
      y = _spawnPosition.y,
    }
    local _beacon = CTLDBeaconManager.getInstance():createAtPoint(_beaconPoint, _side, _country, { isFOB = true })
    if _beacon ~= nil then
      _namedPoint.tacan =
        string.format("ADF : %.2f KHz - %.2f MHz - %.2f MHz FM", _beacon.vhf / 1000, _beacon.uhf / 1000000, _beacon.fm / 1000000)
      veaf.loggers.get(veafSpawn.Id):trace("_namedPoint.tacan=%s", veaf.lp(_namedPoint.tacan))
    end
  end
  trigger.action.outTextForCoalition(_side, veaf.t("spawn.fob_built", _fobName), 10)

  _namedPoint.tower = "No Control"

  veaf.loggers.get(veafSpawn.Id):trace("_namedPoint=%s", veaf.lp(_namedPoint))

  veafNamedPoints.addPoint(_fobName, _namedPoint)

  veaf.loggers.get(veafSpawn.Id):info("Spawned FOB %s", veaf.p(_fobName))
  return _fobName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnGroup(spawnSpot, radius, name, czName, country, alt, hdg, spacing, groupName, silent, hasDest, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnGroup(name=%s, czName=%s, country=%s, alt=%s, hdg=%s, spacing=%s, groupName=%s, silent=%s, hiddenOnMFD=%s)",
    name,
    czName,
    country,
    alt,
    hdg,
    spacing,
    silent,
    groupName,
    hiddenOnMFD
  )

  local spawnedGroupName =
    veafSpawn.doSpawnGroup(spawnSpot, radius, name, czName, country, alt, hdg, spacing, groupName, silent, hasDest, hiddenOnMFD)

  return spawnedGroupName
end

local function validateSpawnPosition(spawnPosition, unit, silent)
  if not veafUnits.checkPositionForUnit(spawnPosition, unit) then
    veaf.loggers.get(veafSpawn.Id):info("Cannot find a suitable position for spawning unit " .. unit.typeName)
    if not silent then
      trigger.action.outText(veaf.t("spawn.no_position_unit", unit.typeName), 5)
    end
    return false
  end
  return true
end

function veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._createDcsUnits([%s])", country or ""))

  if hasDest then
    mist.scheduleFunction(veafUnits.removePathfindingFixUnit, { groupName }, timer.getTime() + veafUnits.delayBeforePathfindingFix)
  end

  local dcsUnits = {}
  for i = 1, #units do
    local unit = units[i]
    local unitType = unit.typeName
    local unitNameTemplate = "%s - %s"
    if veafSpawn.HideTypeFromGroupNames then
      unitNameTemplate = "%s"
    end
    local unitName = string.format(unitNameTemplate, groupName, unit.displayName)
    local spawnPosition = unit.spawnPoint
    local hdg = spawnPosition.hdg or math.random(0, 359)

    if validateSpawnPosition(spawnPosition, unit, false) then
      local toInsert = {
        ["x"] = spawnPosition.x,
        ["y"] = spawnPosition.z,
        ["alt"] = spawnPosition.y,
        ["type"] = unitType,
        ["name"] = unitName,
        ["speed"] = 0,
        ["skill"] = "Excellent",
        ["heading"] = hdg,
      }

      veaf.loggers.get(veafSpawn.Id):trace(
        "toInsert x=%.1f y=%.1f, alt=%.1f, type=%s, name=%s, speed=%d, heading=%d, skill=%s, country=%s",
        toInsert.x,
        toInsert.y,
        toInsert.alt,
        toInsert.type,
        toInsert.name,
        toInsert.speed,
        toInsert.heading,
        toInsert.skill,
        country
      )
      table.insert(dcsUnits, toInsert)
    end
  end

  -- actually spawn groups
  mist.dynAdd({ country = country, category = "GROUND_UNIT", name = groupName, hidden = false, units = dcsUnits, hiddenOnMFD = hiddenOnMFD })
end

--- Spawns a dynamic infantry group
function veafSpawn.spawnInfantryGroup(spawnSpot, radius, czName, country, side, heading, spacing, defense, armor, size, silent, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnInfantryGroup(czName=%s, country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hiddenOnMFD=%s)",
    czName,
    country,
    side,
    heading,
    spacing,
    defense,
    armor,
    size,
    silent,
    hiddenOnMFD
  )

  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
  local groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Infantry Section", czName)
  local group = veafCasMission.generateInfantryGroup(groupName, defense, armor, side, size)
  local group = veafUnits.processGroup(group)
  local groupPosition = veaf.placePointOnLand(spawnSpot)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s", veaf.vecToString(groupPosition)))
  local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading)

  -- shuffle the units in the group
  local units = veaf.shuffle(group.units)

  veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD)

  if not silent then
    trigger.action.outText(veaf.t("spawn.spawned_infantry", groupName), 5)
  end

  return groupName
end

--- Spawns a dynamic armored platoon
function veafSpawn.spawnArmoredPlatoon(
  spawnSpot,
  radius,
  czName,
  country,
  side,
  heading,
  spacing,
  defense,
  armor,
  size,
  silent,
  hasDest,
  hiddenOnMFD
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnArmoredPlatoon(czName=%s, country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hiddenOnMFD=%s)",
    czName,
    country,
    side,
    heading,
    spacing,
    defense,
    armor,
    size,
    silent,
    hiddenOnMFD
  )
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=%s", spawnSpot)
  local groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Armored Platoon", czName)
  veaf.loggers.get(veafSpawn.Id):trace("groupName=%s", groupName)
  local group = veafCasMission.generateArmorPlatoon(groupName, defense, armor, side, size)
  local group = veafUnits.processGroup(group)
  local groupPosition = veaf.placePointOnLand(spawnSpot)
  veaf.loggers.get(veafSpawn.Id):trace("groupPosition=%s", groupPosition)
  local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

  -- shuffle the units in the group
  local units = group.units
  if not hasDest then
    units = veaf.shuffle(group.units)
  end

  veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)

  if not silent then
    trigger.action.outText(veaf.t("spawn.spawned_armored", groupName), 5)
  end

  return groupName
end

--- Spawns a dynamic air defense battery
function veafSpawn.spawnAirDefenseBattery(spawnSpot, radius, czName, country, side, heading, spacing, defense, silent, hasDest, hiddenOnMFD)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnAirDefenseBattery(czName=%s, country=%s, side=%s, heading=%s, spacing=%s, defense=%s, silent=%s, hiddenOnMFD=%s)",
    czName,
    country,
    side,
    heading,
    spacing,
    defense,
    silent,
    hiddenOnMFD
  )

  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
  local groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Air Defense Battery", czName)
  local group = veafCasMission.generateAirDefenseGroup(groupName, defense, side)
  local group = veafUnits.processGroup(group)
  local groupPosition = veaf.placePointOnLand(spawnSpot)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s", veaf.vecToString(groupPosition)))
  local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

  -- shuffle the units in the group
  local units = group.units
  if not hasDest then
    units = veaf.shuffle(group.units)
  end

  veafSpawn._createDcsUnits(country or veaf.getCountryForCoalition(side), units, groupName, hiddenOnMFD, hasDest)

  if not silent then
    trigger.action.outText(veaf.t("spawn.spawned_airdef", groupName), 5)
  end

  return groupName
end

--- Spawns a dynamic transport company
function veafSpawn.spawnTransportCompany(
  spawnSpot,
  radius,
  czName,
  country,
  side,
  heading,
  spacing,
  defense,
  size,
  silent,
  hasDest,
  hiddenOnMFD
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnTransportCompany(czName=%s, country=%s, side=%s, heading=%s, spacing=%s, defense=%s, size=%s, silent=%s, hiddenOnMFD=%s)",
    czName,
    country,
    side,
    heading,
    spacing,
    defense,
    size,
    silent,
    hiddenOnMFD
  )

  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
  local groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Transport Company", czName)
  local group = veafCasMission.generateTransportCompany(groupName, defense, side, size)
  local group = veafUnits.processGroup(group)
  local groupPosition = veaf.placePointOnLand(spawnSpot)
  veaf.loggers.get(veafSpawn.Id):trace(string.format("groupPosition = %s", veaf.vecToString(groupPosition)))
  local group, cells = veafUnits.placeGroup(group, groupPosition, spacing, heading, hasDest)

  -- shuffle the units in the group
  local units = group.units
  if not hasDest then
    units = veaf.shuffle(group.units)
  end

  veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest)

  if not silent then
    trigger.action.outText(veaf.t("spawn.spawned_transport", groupName), 5)
  end

  return groupName
end

--- Spawns a dynamic full combat group composed of multiple platoons
function veafSpawn.spawnFullCombatGroup(
  spawnSpot,
  radius,
  czName,
  country,
  side,
  heading,
  spacing,
  defense,
  armor,
  size,
  silent,
  hiddenOnMFD
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnFullCombatGroup(czName=%s, country=%s, side=%s, heading=%s, spacing=%s, defense=%s, armor=%s, size=%s, silent=%s, hiddenOnMFD=%s)",
    czName,
    country,
    side,
    heading,
    spacing,
    defense,
    armor,
    size,
    silent,
    hiddenOnMFD
  )

  local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))
  local groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Full Combat Group", czName)
  local groupPosition = veaf.placePointOnLand(spawnSpot)
  local units = veafCasMission.generateCasGroup(groupName, groupPosition, size, defense, armor, spacing, side)

  veafSpawn._createDcsUnits(country, units, groupName, hiddenOnMFD)

  if not silent then
    trigger.action.outText(veaf.t("spawn.spawned_combat", groupName), 5)
  end

  return groupName
end

--- Spawn a specific group at a specific spot
function veafSpawn.spawnConvoy(
  spawnSpot,
  name,
  czName,
  radius,
  country,
  side,
  heading,
  spacing,
  speed,
  patrol,
  offroad,
  destination,
  defense,
  size,
  armor,
  silent,
  hiddenOnMFD
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnConvoy(czName=[%s], spawnSpot=[%s], name=[%s], radius=[%s], country=[%s], side=[%s], speed=[%s], patrol=[%s], offroad=[%s], destination=[%s], defense=[%s], size=[%s], armor=[%s], silent=[%s], hiddenOnMFD=[%s])",
    czName,
    spawnSpot,
    name,
    radius,
    country,
    side,
    speed,
    patrol,
    offroad,
    destination,
    defense,
    size,
    armor,
    silent,
    hiddenOnMFD
  )

  if not destination then
    trigger.action.outText(veaf.t("spawn.no_destination"), 5)
    return false
  end

  local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
  veaf.loggers.get(veafSpawn.Id):trace("spawnSpot=" .. veaf.vecToString(spawnSpot))

  -- check that destination exists
  local point = nil
  if destination then
    point = veafNamedPoints.getPoint(destination)
  end
  if not point then
    local _lat, _lon = veaf.computeLLFromString(destination)
    veaf.loggers.get(veafSpawn.Id):trace(string.format("_lat=%s", veaf.p(_lat)))
    veaf.loggers.get(veafSpawn.Id):trace(string.format("_lon=%s", veaf.p(_lon)))
    if _lat and _lon then
      point = coord.LLtoLO(_lat, _lon)
      veaf.loggers.get(veafSpawn.Id):trace(string.format("point=%s", veaf.p(point)))
    end
  end
  if not point then
    trigger.action.outText(veaf.t("spawn.point_not_found", destination), 5)
    return false
  end

  local groupUnits = {}
  groupUnits.units = {}
  local groupId = math.random(99999)
  local groupName = name
  if not groupName or groupName == "" then
    groupName = veaf.getNameForSpawnedGroup(veaf.getCoalitionForCountry(country, true), "Convoy", czName)
  end

  -- generate the transport vehicles and air defense
  if size and size > 0 then -- this is only for reading clarity sake
    -- generate the group
    local group = veafCasMission.generateTransportCompany(groupId, defense, side, size)

    -- process the group
    local group = veafUnits.processGroup(group)

    -- add the units to the global units list
    for _, u in pairs(group.units) do
      table.insert(groupUnits.units, u)
    end
  end

  -- generate the armored vehicles
  if armor and armor > 0 then
    -- generate the group (size may be nil here; the platoon is half the convoy size)
    local platoonSize = size and (size / 2) or nil
    local group = veafCasMission.generateArmorPlatoon(groupId, defense, armor, side, platoonSize)

    -- process the group
    local group = veafUnits.processGroup(group)

    -- add the units to the global units list
    for _, u in pairs(group.units) do
      table.insert(groupUnits.units, u)
    end
  end

  if groupUnits.units then
    -- place its units
    -- Deliberately NOT using veaf.findSpawnPoint here: spawnSpot is the convoy's departure
    -- point, and generateVehiclesRoute below builds the route *from that same point*, so
    -- moving the spawn laterally would desync the route origin from where the vehicles are.
    local groupUnits, cells = veafUnits.placeGroup(groupUnits, veaf.placePointOnLand(spawnSpot), spacing, heading, true)
    veafUnits.traceGroup(groupUnits, cells)

    -- shuffle the units in the convoy
    --disabled the shuffle to not have interractions with the line spawn put in place for faster departure times, which shuffles units anyways
    --units = veaf.shuffle(units)

    veafSpawn._createDcsUnits(country, groupUnits.units, groupName, hiddenOnMFD, true)

    local route = veaf.generateVehiclesRoute(spawnSpot, destination, not offroad, speed, patrol, groupName)
    veafSpawn.spawnedConvoys[groupName] = { route = route, name = groupName }

    --  make the group go to destination
    veaf.loggers.get(veafSpawn.Id):trace("make the group go to destination : " .. groupName)
    mist.goRoute(groupName, route)

    if not silent then
      trigger.action.outText(veaf.t("spawn.spawned_convoy", groupName), 5)
    end
  end

  return groupName
end

function veafSpawn._findClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn._findClosestConvoy(%s)", unitName))
  local closestConvoyName = nil
  local minDistance = 99999999
  local unit = veafRadio.getHumanUnitOrWingman(unitName)
  if unit then
    for name, _ in pairs(veafSpawn.spawnedConvoys) do
      local averageGroupPosition = veaf.getAveragePosition(name)
      -- VMR-101: skip the convoy, do not abandon the search. A destroyed convoy still listed in
      -- spawnedConvoys has no average position, and returning here hid every live convoy from
      -- "mark/stop/move closest convoy". The name logged was the player's, not the convoy's.
      if not averageGroupPosition then
        veaf.loggers.get(veafSpawn.Id):warn("cannot get average position of convoy %s, skipping it", veaf.p(name))
      else
        local distanceFromPlayer = (
          (averageGroupPosition.x - unit:getPosition().p.x) ^ 2 + (averageGroupPosition.z - unit:getPosition().p.z) ^ 2
        ) ^ 0.5
        veaf.loggers.get(veafSpawn.Id):trace(string.format("distanceFromPlayer = %d", distanceFromPlayer))
        if distanceFromPlayer < minDistance then
          minDistance = distanceFromPlayer
          closestConvoyName = name
          veaf.loggers.get(veafSpawn.Id):trace(string.format("convoy %s is closest", closestConvoyName))
        end
      end
    end
  end
  return closestConvoyName
end

function veafSpawn._commandConvoy(convoyName, stop)
  local group = Group.getByName(convoyName)
  if group then
    if stop then
      local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
      if stopped then
        -- already stopped !
        return false
      else
        local task = {
          id = "Hold",
          params = {},
        }
        group:getController():pushTask(task)
        veafSpawn.spawnedConvoys[convoyName].stopped = true
      end
    else
      local stopped = veafSpawn.spawnedConvoys[convoyName].stopped
      if stopped then
        mist.goRoute(convoyName, veafSpawn.spawnedConvoys[convoyName].route)
        veafSpawn.spawnedConvoys[convoyName].stopped = false
      else
        -- not stopped !
        return false
      end
    end
  end
end

--- Find the closest convoy to unitName and warn if none found.
--- Returns the convoy name, or nil (with "No convoy found" message) if not found.
function veafSpawn._getConvoyOrWarn(unitName)
  local convoyName = veafSpawn._findClosestConvoy(unitName)
  if not convoyName then
    veaf.outTextForUnit(unitName, veaf.t("spawn.no_convoy"), 10)
    return nil
  end
  return convoyName
end

function veafSpawn.stopClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.stopClosestConvoy(unitName=%s)", unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if convoyName then
    return veafSpawn._commandConvoy(convoyName, true)
  end
end

function veafSpawn.moveClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.moveClosestConvoy(unitName=%s)", unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if convoyName then
    return veafSpawn._commandConvoy(convoyName, false)
  end
end

function veafSpawn._markClosestConvoyWithSmoke(unitName, markRoute)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.markClosestConvoyWithSmoke(unitName=%s)", unitName))
  local closestConvoyName = veafSpawn._getConvoyOrWarn(unitName)
  if closestConvoyName then
    if markRoute then
      local route = veafSpawn.spawnedConvoys[closestConvoyName].route
      local startPoint = veaf.placePointOnLand({ x = route[1].x, y = 0, z = route[1].y })
      local endPoint = veaf.placePointOnLand({ x = route[2].x, y = 0, z = route[2].y })
      trigger.action.smoke(startPoint, trigger.smokeColor.GREEN)
      trigger.action.smoke(endPoint, trigger.smokeColor.RED)
      veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_smoke_switch", closestConvoyName), 10)
    else
      local averageGroupPosition = veaf.getAveragePosition(closestConvoyName)
      ---@diagnostic disable-next-line: param-type-mismatch
      trigger.action.smoke(averageGroupPosition, trigger.smokeColor.WHITE)
      veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_white_smoke", closestConvoyName), 10)
    end
  end
end

function veafSpawn.markClosestConvoyWithSmoke(unitName)
  return veafSpawn._markClosestConvoyWithSmoke(unitName, false)
end

function veafSpawn.markClosestConvoyRouteWithSmoke(unitName)
  return veafSpawn._markClosestConvoyWithSmoke(unitName, true)
end

function veafSpawn.infoOnAllConvoys(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.infoOnAllConvoys(unitName=%s)", unitName))
  local text = ""
  for name, _ in pairs(veafSpawn.spawnedConvoys) do
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
    if nbVehicles > 0 then
      local averageGroupPosition = veaf.getAveragePosition(name)
      ---@diagnostic disable-next-line: param-type-mismatch
      local lat, lon = coord.LOtoLL(averageGroupPosition)
      local llString = mist.tostringLL(lat, lon, 0, true)
      text = text .. veaf.t("spawn.convoy_info", name, nbVehicles, llString)
      if veafSpawn.spawnedConvoys[name].stopped then
        text = text .. veaf.t("spawn.convoy_stopped")
      end
    else
      text = text .. veaf.t("spawn.convoy_destroyed", name)
      -- convoy has been dispatched, remove it from the convoys list
      veafSpawn.spawnedConvoys[name] = nil
    end
  end
  if text == "" then
    veaf.outTextForUnit(unitName, veaf.t("spawn.no_convoy"), 10)
  else
    veaf.outTextForUnit(unitName, text, 30)
  end
end

function veafSpawn.cleanupAllConvoys()
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.cleanupAllConvoys()")
  local foundOne = false
  for name, _ in pairs(veafSpawn.spawnedConvoys) do
    foundOne = true
    local nbVehicles, nbInfantry = veafUnits.countInfantryAndVehicles(name)
    if nbVehicles > 0 then
      local group = Group.getByName(name)
      if group then
        Group.destroy(group)
      end
    end
    -- convoy has been dispatched, remove it from the convoys list
    veafSpawn.spawnedConvoys[name] = nil
  end
  if foundOne then
    trigger.action.outText(veaf.t("spawn.convoys_cleaned"), 10)
  else
    trigger.action.outText(veaf.t("spawn.no_convoy"), 10)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Ground spawn command handlers
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafSpawn.registerCommandHandler("farp", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  if not options.type then
    options.type = "invisible"
  end
  local g = veafSpawn.spawnFarp(
    eventPos,
    options.radius,
    options.name,
    options.country,
    options.type,
    options.side,
    options.heading,
    options.spacing,
    bypassSecurity,
    not options.showMFD,
    options.noFarpMarkers,
    options.tacanCode,
    options.tacanChannel,
    options.tacanBand
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("fob", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnFob(
    eventPos,
    options.radius,
    options.name,
    options.country,
    options.type,
    options.side,
    options.heading,
    options.spacing,
    bypassSecurity,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("group", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local hasDest = options.destination ~= nil
  local g = veafSpawn.spawnGroup(
    eventPos,
    options.radius,
    options.name,
    options.czName,
    options.country,
    options.altitude,
    options.heading,
    options.spacing,
    options.unitName,
    bypassSecurity,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("infantryGroup", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnInfantryGroup(
    eventPos,
    options.radius,
    options.czName,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.defense,
    options.armor,
    options.size,
    bypassSecurity,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("armoredPlatoon", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local hasDest = options.destination ~= nil
  local g = veafSpawn.spawnArmoredPlatoon(
    eventPos,
    options.radius,
    options.czName,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.defense,
    options.armor,
    options.size,
    bypassSecurity,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("airDefenseBattery", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local hasDest = options.destination ~= nil
  local g = veafSpawn.spawnAirDefenseBattery(
    eventPos,
    options.radius,
    options.czName,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.defense,
    bypassSecurity,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("transportCompany", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local hasDest = options.destination ~= nil
  local g = veafSpawn.spawnTransportCompany(
    eventPos,
    options.radius,
    options.czName,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.defense,
    options.size,
    bypassSecurity,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("fullCombatGroup", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnFullCombatGroup(
    eventPos,
    options.radius,
    options.czName,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.defense,
    options.armor,
    options.size,
    bypassSecurity,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("convoy", "L9", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnConvoy(
    eventPos,
    options.name,
    options.czName,
    options.radius,
    options.country,
    options.side,
    options.heading,
    options.spacing,
    options.speed,
    options.patrol,
    options.offroad,
    options.destination,
    options.defense,
    options.size,
    options.armor,
    bypassSecurity,
    not options.showMFD
  )
  return g, true, false
end)
