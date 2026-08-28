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

  -- Deliberately NOT using veaf.findSpawnPoint here: a FARP goes exactly where the user pointed
  -- (David, 2026-08-27). The tooling does not choose this position, a person looking at the map does,
  -- so it is never moved to find clear ground — and `radius or 0` above means the default is exact.
  -- A caller-supplied radius is the user asking for the dispersion, so it keeps jittering.
  --
  -- The FARP's **escort** is a different matter: veafGrass.findClearBearing does search for clear
  -- ground for it, and FIX-PLACEMENT-IGNORES-SCENERY adds the scenery criterion there. Both
  -- statements are true at once — exact platform, searched escort — so do not read one for the other.
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
    ["heading"] = math.rad(hdg),
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
  -- mission disabled the module rather than merely failing to load the script, or left the
  -- engine parked because nothing ever called veaf.ctld_initialize() (that third state is what
  -- FIX-CTLD-NEVER-INITIALIZED found, and it is the one that used to crash here).
  if not veaf.isCtldReady() then
    -- "not usable" rather than "without CTLD": the script may well be loaded, and
    -- veaf.isCtldReady() has already logged which of the three states it is in.
    veaf.loggers.get(veafSpawn.Id):error("spawnFob([%s]): CTLD is not usable, cannot spawn a FOB", veaf.p(name))
    return nil
  end

  local _radius = radius or 0
  local _fobName = name
  local _side = side or 1
  local _country = country or "usa"
  local _fobtype = fobtype or "" -- only a single FOB type in CTLD, yet
  local _hdg = hdg or 0

  -- Deliberately NOT using veaf.findSpawnPoint here: a FOB goes exactly where the user pointed
  -- (David, 2026-08-27) — same rule as the FARP above. The watchtower below is offset from this
  -- point on purpose; that offset is a layout decision, not a search.
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
    heading = math.rad(hdg),
    country = _country,
  }
  mist.dynAddStatic(_outpost)
  local _fob = StaticObject.getByName(_outpost["name"])

  local _tower = {
    type = "house2arm",
    rate = 100,
    y = _outpost.y + TOWER_DISTANCE * math.sin(math.rad(_hdg)),
    x = _outpost.x + TOWER_DISTANCE * math.cos(math.rad(_hdg)),
    name = _fobName .. " Watchtower #002",
    category = "Fortifications",
    canCargo = false,
    heading = math.rad(_hdg),
    country = _country,
  }
  mist.dynAddStatic(_tower)

  -- add the FOB to the named points
  local _namedPoint = _spawnPosition
  _namedPoint.atc = true
  _namedPoint.runways = {}

  if veaf.isCtldReady() then
    -- make it able to deploy crates and pickup troops. CTLD 2 owns the FOB list itself
    -- (CTLDFOBManager), so the logistic zone is the only thing we declare.
    CTLDZoneManager.getInstance():registerFOBAsLogistic(_fobName, _spawnPosition, nil, _side)

    -- spawn a beacon. Its name is CTLD's to allocate now — the "FOB Beacon #N" counter
    -- VEAF kept was a second numbering next to the manager's own.
    local _beaconPoint = {
      z = _tower.y + BEACON_DISTANCE * math.sin(math.rad(_hdg)),
      x = _tower.x + BEACON_DISTANCE * math.cos(math.rad(_hdg)),
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

--- Spawn a radio beacon through CTLD, and tell the player its frequencies.
---
--- FEAT-RADIO-BEACONS. `CTLDBeaconManager:createAtPoint` is CTLD 2's script-facing beacon spawner: it
--- needs no transport, no zone and no player, and it lights **three** beacons at once — VHF, UHF and FM.
--- The FM one is what issue #38 asked for, and it comes for free rather than as an option.
---
--- The frequencies are CTLD's to choose: it draws each from an internal pool and exposes no way to
--- request one. So the command's job is to *report* what it got, which is why this does not copy
--- `-tacan` — that command emits no message at all, and a beacon nobody knows the frequency of is not a
--- beacon. A `freq` option is asked for upstream (VEAF/CTLD#128) and can be added here once it lands.
---
--- @param spawnSpot table where the marker was dropped
--- @param radius number|nil scatter radius, 0 for the exact spot
--- @param name string|nil display name; CTLD allocates "Beacon #N" when absent
--- @param country string|nil country name or id — `ctld.utils.dynAdd` resolves either
--- @param side number|nil coalition id
--- @param silent boolean|nil mute the message to players
--- @return nil always: the beacon is three groups and CTLD owns all of them
function veafSpawn.spawnBeacon(spawnSpot, radius, name, country, side, silent)
  veaf.loggers
    .get(veafSpawn.Id)
    :debug("spawnBeacon(name=%s, country=%s, side=%s, radius=%s)", veaf.lp(name), veaf.lp(country), veaf.lp(side), veaf.lp(radius))

  if not veaf.isCtldReady() then
    -- Said out loud rather than logged: the pilot dropped a marker and is waiting for something to
    -- happen. `isCtldReady` has already written the *why* to the log for whoever built the mission.
    if not silent then
      trigger.action.outText(veaf.t("spawn.beacon_needs_ctld"), 10)
    end
    return nil
  end

  local _side = side or coalition.side.BLUE
  local _country = country or "usa"
  -- Deliberately NOT using veaf.findSpawnPoint here: a beacon goes exactly where the user pointed
  -- (David, 2026-08-27) — same rule as the FARP and the FOB above.
  local _position = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius or 0))

  local _beacon = CTLDBeaconManager.getInstance():createAtPoint(_position, _side, _country, { name = name })
  if not _beacon then
    if not silent then
      trigger.action.outTextForCoalition(_side, veaf.t("spawn.beacon_failed"), 10)
    end
    return nil
  end

  -- Same units the FOB beacon reports in and the same order, because a pilot who has seen one should
  -- not have to work out whether this one means kHz or MHz.
  if not silent then
    trigger.action.outTextForCoalition(
      _side,
      veaf.t("spawn.beacon_spawned", _beacon.vhf / 1000, _beacon.uhf / 1000000, _beacon.fm / 1000000),
      15
    )
  end
  veaf.loggers
    .get(veafSpawn.Id)
    :info("Spawned beacon: %.2f kHz / %.2f MHz / %.2f MHz FM", _beacon.vhf / 1000, _beacon.uhf / 1000000, _beacon.fm / 1000000)

  -- Deliberately nil. The dispatcher reads this as a *group name* and then runs its own
  -- post-processing on it (alarm state, MFD hiding, platform registration). A beacon is three groups
  -- with CTLD's own battery timer, removal and map layer on top; handing it one of them would let VEAF
  -- reconfigure something it does not own.
  return nil
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
    veaf.scheduleFunction(veafUnits.removePathfindingFixUnit, { groupName }, timer.getTime() + veafUnits.delayBeforePathfindingFix)
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

  local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
  if not spawnSpot then
    return veafSpawn._reportNoGroupPosition(silent)
  end
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
  hiddenOnMFD,
  itinerary
)
  veaf.loggers.get(veafSpawn.Id):debug(
    "spawnConvoy(czName=[%s], spawnSpot=[%s], name=[%s], radius=[%s], country=[%s], side=[%s], speed=[%s], patrol=[%s], offroad=[%s], destination=[%s], defense=[%s], size=[%s], armor=[%s], silent=[%s], hiddenOnMFD=[%s], itinerary=[%s])",
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
    hiddenOnMFD,
    itinerary
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

    -- One point or several, the convoy is stored the same way: an itinerary and the leg it is on.
    -- A single `dest` is a one-point itinerary, so nothing downstream needs to know the difference.
    -- `patrol` only applies once the last point is reached — patrolling between two waypoints of an
    -- itinerary would contradict the itinerary itself.
    itinerary = itinerary or { destination }
    local lastLeg = #itinerary == 1
    local route = veaf.generateVehiclesRoute(spawnSpot, destination, not offroad, speed, patrol and lastLeg, groupName)
    veafSpawn.spawnedConvoys[groupName] = {
      route = route,
      name = groupName,
      itinerary = itinerary,
      -- The index of the point the convoy is driving **toward**, not the one it left. It starts at 1
      -- because the departure route goes to `itinerary[1]`. Read the other way round, every message and
      -- every check here is off by one — a reviewer of PR #781 read it that way and proposed naming
      -- `legIndex + 1` in the hold message, which would have named the point *after* the one the convoy
      -- parks at. A test pins the correct reading.
      legIndex = 1,
      speed = speed,
      offroad = offroad,
      patrol = patrol,
    }

    --  make the group go to destination
    veaf.loggers.get(veafSpawn.Id):trace("make the group go to destination : " .. groupName)
    mist.goRoute(groupName, route)

    -- Only an itinerary needs watching. A single `dest` has no next leg, so a one-point convoy keeps
    -- exactly the behaviour it had before this lot — no watchdog, nothing rescheduled.
    if #itinerary > 1 then
      veaf.scheduleFunction(veafSpawn.convoyArrivalWatchdog, { groupName }, timer.getTime() + veafSpawn.CONVOY_WATCHDOG_PERIOD_SECONDS)
    end

    if not silent then
      trigger.action.outText(veaf.t("spawn.spawned_convoy", groupName), 5)
    end
  end

  return groupName
end

--- How close a convoy must get to a point to count as having arrived, in metres.
---
--- Generous on purpose. A convoy stops where the terrain lets it, the route's last waypoint is snapped
--- to a road, and the position compared against it is the group's **average** — so the head of a long
--- column can be well past the point while the average is not. `PatrolWatchdog` uses 10 m because it
--- watches a single lead vehicle returning to a mark; that would strand a column here.
veafSpawn.CONVOY_ARRIVAL_RADIUS_METRES = 150

--- How often the arrival watch runs, in seconds. Same cadence as `veaf.PatrolWatchdog`.
veafSpawn.CONVOY_WATCHDOG_PERIOD_SECONDS = 30

--- Watch a convoy for arrival at the point it is heading for, and start the next leg when it gets there.
---
--- Reschedules itself, so one call at spawn keeps a convoy walking its whole itinerary unaided — the
--- arrival half of David's arbitration.
---
--- It reads the convoy's **average** position rather than its lead vehicle's, which is where it departs
--- from `veaf.PatrolWatchdog`. That is deliberate, and it answers one of the two questions the PRD
--- asked, by removing it: an average has no lead vehicle to lose when the front truck burns, and it
--- comes back nil exactly when nothing is left alive — which is the signal to stop watching rather than
--- a case to handle.
---
--- The watch ends, without rescheduling, when the convoy is gone from the registry, has no position
--- left, or has reached the last point of its itinerary. It survives a player stop: he may resume.
---
--- @param convoyName string
function veafSpawn.convoyArrivalWatchdog(convoyName)
  veaf.loggers.get(veafSpawn.Id):trace("veafSpawn.convoyArrivalWatchdog(convoyName=%s)", veaf.p(convoyName))
  local convoy = veafSpawn.spawnedConvoys[convoyName]
  if not convoy or not convoy.itinerary then
    return -- cleaned up, or never had an itinerary: nothing to watch
  end
  if convoy.legIndex >= #convoy.itinerary then
    veaf.loggers.get(veafSpawn.Id):debug("convoy %s reached the end of its itinerary, stopping the watch", veaf.p(convoyName))
    return
  end

  local position = veaf.getAveragePosition(convoyName)
  if not position then
    veaf.loggers.get(veafSpawn.Id):debug("convoy %s has no position left, stopping the watch", veaf.p(convoyName))
    return
  end

  if not convoy.stopped and veafSpawn._convoyHasReachedItsPoint(convoy, position) then
    if convoy.holding then
      -- `hold until further orders`: the leg was allowed to finish, and this is where it parks.
      convoy.holding = false
      convoy.heldAt = convoy.itinerary[convoy.legIndex]
      trigger.action.outText(veaf.t("spawn.convoy_holding_at", convoyName, convoy.heldAt), 10)
    else
      veafSpawn.advanceConvoy(convoyName)
    end
  end

  veaf.scheduleFunction(veafSpawn.convoyArrivalWatchdog, { convoyName }, timer.getTime() + veafSpawn.CONVOY_WATCHDOG_PERIOD_SECONDS)
end

--- Has the convoy reached the last waypoint of its current route?
---
--- The route is in **mission-table** form, where a waypoint's `y` is the easting; the position handed in
--- is a **runtime vec3**, where `y` is the altitude and `z` is the easting. Comparing `y` to `y` here
--- raises no error and is simply wrong, which is what `docs/agents/dcs-coordinates.md` exists for.
--- Altitude is deliberately ignored: a convoy arrives in two dimensions.
---
--- @param convoy table the convoy record
--- @param position table a runtime vec3
--- @return boolean
function veafSpawn._convoyHasReachedItsPoint(convoy, position)
  local route = convoy.route
  if not route or #route == 0 then
    return false
  end
  local target = route[#route]
  if not target or not target.x or not target.y then
    return false
  end
  local dNorth = position.x - target.x
  local dEast = position.z - target.y
  return (dNorth * dNorth + dEast * dEast) <= (veafSpawn.CONVOY_ARRIVAL_RADIUS_METRES * veafSpawn.CONVOY_ARRIVAL_RADIUS_METRES)
end

--- Move a convoy onto the next leg of its itinerary.
---
--- Called by the arrival watchdog and by the player's "advance" menu alike — David's arbitration is
--- that **both** advance a convoy, so there is one implementation and two callers rather than two
--- code paths that drift.
---
--- The leg is generated from **where the convoy is now**, not from its original spawn point. It has
--- driven since; re-using the old origin would route it back to the start before setting off, which is
--- the same defect FIX-COMBATZONE-SPAWN-ROUTE-OFFSET fixed for combat zones.
---
--- `patrol` is honoured only on the final leg: patrolling between two waypoints of an itinerary would
--- contradict the itinerary.
---
--- @param convoyName string
--- @return boolean true if a new leg was started; false when there is nowhere left to go, the convoy
---         is unknown, or it has no position left to start from
function veafSpawn.advanceConvoy(convoyName)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.advanceConvoy(convoyName=%s)", veaf.p(convoyName))
  local convoy = veafSpawn.spawnedConvoys[convoyName]
  if not convoy or not convoy.itinerary then
    return false
  end

  local nextLeg = (convoy.legIndex or 1) + 1
  local destination = convoy.itinerary[nextLeg]
  if not destination then
    veaf.loggers.get(veafSpawn.Id):debug("convoy %s is on the last point of its itinerary", veaf.p(convoyName))
    return false
  end

  local currentPosition = veaf.getAveragePosition(convoyName)
  if not currentPosition then
    veaf.loggers.get(veafSpawn.Id):warn("cannot advance convoy %s: it has no position left", veaf.p(convoyName))
    return false
  end

  local isLastLeg = nextLeg == #convoy.itinerary
  local route =
    veaf.generateVehiclesRoute(currentPosition, destination, not convoy.offroad, convoy.speed, convoy.patrol and isLastLeg, convoyName)
  if not route then
    -- generateVehiclesRoute already told the player the point could not be resolved
    return false
  end

  convoy.legIndex = nextLeg
  convoy.route = route
  convoy.stopped = false
  mist.goRoute(convoyName, route)
  return true
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

--- Advance the closest convoy to the next point of its itinerary, without waiting for arrival.
---
--- The radio half of David's arbitration — **both** arrival and the player advance a convoy. It calls
--- the same `advanceConvoy` the watchdog does, so the two cannot drift apart.
---
--- Advancing also releases a `hold`: a game master who pushes the convoy on has plainly changed his
--- mind about parking it.
function veafSpawn.advanceClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.advanceClosestConvoy(unitName=%s)", veaf.p(unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if not convoyName then
    return false
  end
  local convoy = veafSpawn.spawnedConvoys[convoyName]
  convoy.holding = false
  if not veafSpawn.advanceConvoy(convoyName) then
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_itinerary_finished", convoyName), 10)
    return false
  end
  veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_advancing_to", convoyName, convoy.itinerary[convoy.legIndex]), 10)
  return true
end

--- Hold the closest convoy **at its next point**, letting the current leg finish.
---
--- Not a brake, and that is the whole distinction: `stop` halts a convoy where it stands, for a mission
--- going wrong; `hold` parks it somewhere sensible, for a mission being paced. Naming them alike would
--- make the useful one unusable, so they set different state and say different things.
---
--- On the last leg there is no next point to park at. It says so rather than doing nothing, or a game
--- master would believe the convoy is under orders when it is simply finishing.
function veafSpawn.holdClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug("veafSpawn.holdClosestConvoy(unitName=%s)", veaf.p(unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if not convoyName then
    return false
  end
  local convoy = veafSpawn.spawnedConvoys[convoyName]
  local point = convoy.itinerary and convoy.itinerary[convoy.legIndex]
  if not point or convoy.legIndex >= #convoy.itinerary then
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_cannot_hold", convoyName), 10)
    return false
  end
  convoy.holding = true
  veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_will_hold_at", convoyName, point), 10)
  return true
end

--- Halt the closest convoy **where it stands**. The other brake — see `holdClosestConvoy`, which lets
--- the leg finish and parks at the next point. Both report, and they must not report alike.
function veafSpawn.stopClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.stopClosestConvoy(unitName=%s)", unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if not convoyName then
    return
  end
  local halted = veafSpawn._commandConvoy(convoyName, true)
  if halted == false then
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_already_halted", convoyName), 10)
  else
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_halted_here", convoyName), 10)
  end
  return halted
end

--- Send the closest convoy on its way again after a halt, on the leg it was already walking. Distinct
--- from `advanceClosestConvoy`, which skips to the *next* point.
function veafSpawn.moveClosestConvoy(unitName)
  veaf.loggers.get(veafSpawn.Id):debug(string.format("veafSpawn.moveClosestConvoy(unitName=%s)", unitName))
  local convoyName = veafSpawn._getConvoyOrWarn(unitName)
  if not convoyName then
    return
  end
  local resumed = veafSpawn._commandConvoy(convoyName, false)
  if resumed == false then
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_already_rolling", convoyName), 10)
  else
    veaf.outTextForUnit(unitName, veaf.t("spawn.convoy_resumed", convoyName), 10)
  end
  return resumed
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
      local llString = veaf.toStringLL(lat, lon, 0, true)
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

veafSpawn.registerCommandHandler("farp", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    not options.showMFD,
    options.noFarpMarkers,
    options.tacanCode,
    options.tacanChannel,
    options.tacanBand
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("fob", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  local g = veafSpawn.spawnFob(
    eventPos,
    options.radius,
    options.name,
    options.country,
    options.type,
    options.side,
    options.heading,
    options.spacing,
    options.silent,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("beacon", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
  -- `silent` is options.silent and NOT bypassSecurity: FIX-SPAWN-BYPASSSECURITY-AS-SILENT records why
  -- the neighbours conflate the two, and it is what makes `-tacan` mute. A beacon must report its
  -- frequencies whether or not the command needed a password.
  veafSpawn.spawnBeacon(eventPos, options.radius, options.name, options.country, options.side, options.silent)
  return nil, nil, false
end)

veafSpawn.registerCommandHandler("group", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("infantryGroup", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("armoredPlatoon", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("airDefenseBattery", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("transportCompany", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    hasDest,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("fullCombatGroup", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    not options.showMFD
  )
  return g, nil, false
end)

veafSpawn.registerCommandHandler("convoy", "KNOWN_PILOT", function(eventPos, options, coalition, markId, bypassSecurity)
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
    options.silent,
    not options.showMFD,
    options.itinerary
  )
  return g, true, false
end)
