------------------------------------------------------------------
-- VEAF Reactive Zone for DCS World
-- The plumbing shared by veafQraCore and veafAirWaves (FEAT-AIRWAVES-QRA-MERGE).
--
-- Features:
-- ---------
-- * where a zone is: a trigger zone, a centre and radius, or either one following a unit
-- * which units are in it, between its altitude floor and ceiling
-- * spawning a `[lat,lon]` VEAF command or a mission editor group around it
-- * what it depends on: airbases, ships, groups or statics whose loss pauses or stops it
-- * drawing and erasing it on the map
--
-- A QRA and an air-wave zone are not one behaviour: the QRA defends its ground in an endless loop,
-- the air-wave zone runs a game that ends. What they share is everything below their state machine,
-- and that used to be written twice — an axis swap fixed in four places (FIX-WAVE-OFFSET-AXES), a
-- missing-zone crash fixed in one module and not the other (VMR-085). The written comparison is
-- `.backlog/FEAT-AIRWAVES-QRA-MERGE/comparison.md`.
--
-- Every function takes the zone object first and reads these fields, which both classes carry:
-- `name`, `triggerZoneName`, `zoneCenter`, `zoneRadius`, `followUnitName`, `respawnDefaultOffset`,
-- `respawnRadius`, `minimumAltitude`, `maximumAltitude`, `links`, `zoneDrawing`.
------------------------------------------------------------------

veafReactiveZone = {}

--- Identifier. All output in DCS.log will start with this.
veafReactiveZone.Id = "REACTIVEZONE"

-- trace level, specific to this module
--veafReactiveZone.LogLevel = "trace"

veaf.loggers.new(veafReactiveZone.Id, veafReactiveZone.LogLevel)

--- What a link check answers.
veafReactiveZone.LINKS_OK = "ok"
--- A linked airbase or FARP is captured or too damaged: the zone waits until it is retaken.
veafReactiveZone.LINKS_PAUSED = "paused"
--- A linked ship, group, static or unit is destroyed: nothing brings it back.
veafReactiveZone.LINKS_LOST = "lost"

--- How long a command that returned without spawning anything is waited for, in seconds.
---
--- A command carrying `delayed <n>` or `repeat <n>` returns before it spawns (#1078). Its group is
--- expected, and the zone must not call the wave dead meanwhile; but a deferred spawn that fails says
--- nothing, and an endless wait would hold the zone open for ever. Ten minutes covers any delay a
--- mission declares in practice.
veafReactiveZone.PENDING_SPAWN_TIMEOUT = 600

--- The lists `deployGroups` returned that their zone has done with: a group a deferred command spawns
--- into one of them is destroyed on arrival, as `veafCombatZone` does for a deactivated zone (#66).
veafReactiveZone.retiredLists = setmetatable({}, { __mode = "k" })

--- For each list `deployGroups` returned, the commands still expected to spawn: `{ [index] = deadline }`.
veafReactiveZone.pendingSpawns = setmetatable({}, { __mode = "k" })

local function logger(moduleId)
  return veaf.loggers.get(moduleId or veafReactiveZone.Id)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Where the zone is
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The DCS trigger zone of this zone, or nil when it has none or the name matches no zone.
function veafReactiveZone.getTriggerZone(zone)
  if veaf.isNullOrEmpty(zone.triggerZoneName) then
    return nil
  end
  return veaf.getTriggerZone(zone.triggerZoneName)
end

--- The live unit this zone follows, or nil.
---
--- Two ways to say it (#186, decided 2026-10-05): `followUnitName`, or the "link to unit" the mission
--- editor puts on a trigger zone (`linkUnit`, an editor unit id — the `edit_zone` MCP action writes it
--- too). A zone whose unit is dead answers nil here, and `getCenter` keeps it where it was last seen.
--- @return table|nil, table the unit, and the offset from it to the zone centre (`{ x, z }`, metres)
function veafReactiveZone.getFollowedUnit(zone)
  local unitName = zone.followUnitName
  local offset = { x = 0, z = 0 }
  if not unitName then
    local triggerZone = veafReactiveZone.getTriggerZone(zone)
    if triggerZone and triggerZone.linkUnit then
      local record = veafMissionDb.getUnitRecordById(triggerZone.linkUnit)
      unitName = record and record.unitName
      if record and record.x and record.y then
        -- where the editor drew the zone relative to the unit, both in the mission-table shape: the
        -- zone keeps that offset as the unit moves (0 when the editor centred it on the unit)
        offset = { x = triggerZone.x - record.x, z = triggerZone.y - record.y }
      end
    end
  end
  if not unitName then
    return nil, offset
  end
  local unit = Unit.getByName(unitName)
  if unit and unit:isExist() then
    return unit, offset
  end
  return nil, offset
end

--- True when the zone is declared as following a unit, alive or not.
function veafReactiveZone.isMobile(zone)
  if zone.followUnitName then
    return true
  end
  local triggerZone = veafReactiveZone.getTriggerZone(zone)
  return triggerZone ~= nil and triggerZone.linkUnit ~= nil
end

--- The zone centre, as a runtime vec3: `x` the northing, `z` the easting, `y` the altitude.
---
--- A trigger zone is a mission-table position (easting in `y`, no altitude), so it is converted here
--- once, with an altitude of 0. A configured centre keeps its own altitude. See
--- docs/agents/dcs-coordinates.md.
--- @return table|nil nil when the zone has neither a trigger zone nor a centre
function veafReactiveZone.getCenter(zone)
  if veafReactiveZone.isMobile(zone) then
    local unit, offset = veafReactiveZone.getFollowedUnit(zone)
    if unit then
      local point = unit:getPoint()
      zone._lastFollowedCenter = { x = point.x + offset.x, y = 0, z = point.z + offset.z }
    end
    if zone._lastFollowedCenter then
      return zone._lastFollowedCenter
    end
  end
  local triggerZone = veafReactiveZone.getTriggerZone(zone)
  if triggerZone then
    return { x = triggerZone.x, y = 0, z = triggerZone.y }
  end
  return zone.zoneCenter
end

--- The zone radius in metres: the trigger zone's, else the configured one.
function veafReactiveZone.getRadius(zone)
  local triggerZone = veafReactiveZone.getTriggerZone(zone)
  if triggerZone and triggerZone.radius then
    return triggerZone.radius
  end
  return zone.zoneRadius
end

--- Which of the named units are inside the zone.
---
--- Returns **nil** for a zone that cannot be read, as `veaf.getUnitsInTriggerZone` does: callers treat
--- it as "nobody", the safe conduct, and the error is in the log. A mobile zone is a circle around its
--- current centre, whatever the shape drawn in the editor.
function veafReactiveZone.findUnitsInZone(zone, unitNames, moduleId)
  if veafReactiveZone.isMobile(zone) then
    local center = veafReactiveZone.getCenter(zone)
    local radius = veafReactiveZone.getRadius(zone)
    if center and radius then
      return veaf.findUnitsInCircle(center, radius, false, unitNames)
    end
    logger(moduleId):error("zone [%s] follows a unit but has no centre or radius yet", veaf.p(zone.name))
    return nil
  end
  if not veaf.isNullOrEmpty(zone.triggerZoneName) then
    if veaf.getTriggerZone(zone.triggerZoneName) then
      return veaf.getUnitsInTriggerZone(zone.triggerZoneName, unitNames, moduleId)
    end
    if not zone.zoneCenter then
      logger(moduleId):error("zone [%s] has a non-existent trigger zone: %s", veaf.p(zone.name), veaf.p(zone.triggerZoneName))
      return nil
    end
  end
  if zone.zoneCenter then
    return veaf.findUnitsInCircle(zone.zoneCenter, zone.zoneRadius, false, unitNames)
  end
  -- once: the watchdog asks again every few seconds for the whole mission
  if not zone._reportedNoGeometry then
    zone._reportedNoGeometry = true
    logger(moduleId):error("zone [%s] has no trigger zone, and no zone center/radius defined", veaf.p(zone.name))
  end
  return nil
end

--- True when the unit stands inside the zone (horizontal test only).
function veafReactiveZone.isUnitInZone(zone, unit)
  local triggerZone = veafReactiveZone.getTriggerZone(zone)
  if triggerZone and not veafReactiveZone.isMobile(zone) then
    return veaf.isUnitInZone(unit, triggerZone)
  end
  local center = veafReactiveZone.getCenter(zone)
  local radius = veafReactiveZone.getRadius(zone)
  local position = unit:getPosition()
  if not (center and radius and position and position.p) then
    return false
  end
  local pos = position.p
  return ((pos.x - center.x) ^ 2 + (pos.z - center.z) ^ 2) ^ 0.5 <= radius
end

--- The units of the list that exist, are airborne, and fly between the zone floor and ceiling.
---
--- A landed aircraft never counts: a QRA must not scramble on a jet parked in its zone.
function veafReactiveZone.filterAirborne(zone, units)
  local result = {}
  for _, unit in pairs(units or {}) do
    if unit:isExist() and unit:inAir() then
      local alt = unit:getPoint().y
      if alt >= zone.minimumAltitude and alt <= zone.maximumAltitude then
        table.insert(result, unit)
      end
    end
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- What the zone spawns
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- `number` entries drawn at random from `groups`, shifted by `bias`; the list unchanged when the
--- draw parameters are not numbers (a plain list of groups to deploy as such).
function veafReactiveZone.pickGroups(groups, number, bias)
  if type(groups) == "table" and type(number) == "number" and type(bias) == "number" then
    local result = {}
    for _ = 1, number do
      table.insert(result, veaf.randomlyChooseFrom(groups, bias))
    end
    return result
  end
  return groups
end

--- Like `pickGroups`, but drawn without replacement: a group is never picked twice, and the draw stops
--- when the list is exhausted. A QRA tier saying "2 of [MiG-29, Su-27]" means both, not the same pair
--- twice — which, for an editor group respawned by name, is that pair once
--- (FEAT-OPPOSITION-SCALES-WITH-PLAYERS). The air waves keep `pickGroups`: their `number` may exceed
--- the list on purpose.
function veafReactiveZone.pickDistinctGroups(groups, number, bias)
  if type(groups) == "table" and type(number) == "number" and type(bias) == "number" then
    local remaining = {}
    for _, group in ipairs(groups) do
      table.insert(remaining, group)
    end
    local result = {}
    while #result < number and #remaining > 0 do
      local index = math.min(math.max(math.random(1, #remaining) + bias, 1), #remaining)
      table.insert(result, table.remove(remaining, index))
    end
    return result
  end
  return groups
end

--- Spawn each entry around the zone, and return the names of the groups that reached DCS.
---
--- An entry starting with `[` or `-` is a VEAF command, optionally prefixed with `[latDelta,lonDelta]`
--- in metres from the zone centre (the zone's `respawnDefaultOffset` otherwise); any other entry is a
--- mission editor group, respawned where the editor placed it.
---
--- @param zone table
--- @param entries table the groups and commands to spawn
--- @param side number the coalition a command spawns for — a command that names no side or country
---   would otherwise fall back to red (`veaf.getCountryForCoalition(nil)`), which is how an air-wave
---   zone with red players used to send them red enemies
--- @param moduleId string|nil the caller's logger id
--- @return table the spawned group names
function veafReactiveZone.deployGroups(zone, entries, side, moduleId)
  local spawnedGroupsNames = {}
  local pending = {}
  veafReactiveZone.pendingSpawns[spawnedGroupsNames] = pending
  local commandIndex = 0
  local zoneCenter = veafReactiveZone.getCenter(zone)
  if not zoneCenter then
    -- VMR-085, now for both modules: a missing trigger zone and no centre spawn nothing, loudly.
    logger(moduleId):error("zone [%s] has no trigger zone, and no zone center defined: nothing deployed", veaf.p(zone.name))
    return spawnedGroupsNames
  end
  -- what a CAP or Intercept with no job of its own defends (FEAT-AIRCRAFT-ROLES)
  local zoneToDefend = nil
  if veafReactiveZone.isMobile(zone) then
    zoneToDefend = veafAircraftSpawn.zoneToDefend(nil, zoneCenter, veafReactiveZone.getRadius(zone))
  else
    zoneToDefend = veafAircraftSpawn.zoneToDefend(veafReactiveZone.getTriggerZone(zone), zone.zoneCenter, zone.zoneRadius)
  end
  for _, groupNameOrCommand in pairs(entries or {}) do
    if veaf.startsWith(groupNameOrCommand, "[") or veaf.startsWith(groupNameOrCommand, "-") then
      local command = groupNameOrCommand
      local latDelta = zone.respawnDefaultOffset.latDelta
      local lonDelta = zone.respawnDefaultOffset.lonDelta
      if veaf.startsWith(groupNameOrCommand, "[") then
        local coords
        coords, command = groupNameOrCommand:match("%[(.*)%](.*)")
        if coords then
          latDelta, lonDelta = coords:match("([%+-%d]+),%s*([%+-%d]+)")
        end
      end
      logger(moduleId):debug("running command [%s]", veaf.lp(command))
      -- Latitude delta on the northing (`x`), longitude delta on the easting (`z`), both added.
      -- Until 2026-09-01 the twins of this line read `x = zoneCenter.x - lonDelta, z = zoneCenter.z +
      -- latDelta`, which sent the first bracket number east and the second one south
      -- (FIX-WAVE-OFFSET-AXES).
      local position = { x = zoneCenter.x + latDelta, y = zoneCenter.y, z = zoneCenter.z + lonDelta }
      -- The draw answers the mission-table shape — `{ x, y }`, easting in `y`, no `z` — while
      -- `veafInterpreter.execute` takes a runtime vec3 whose easting is `z` and whose `y` is the
      -- altitude, which is what `veafSpawnGround` reads. Passed over untouched, the command spawned on
      -- the theatre's central meridian. The altitude is the zone centre's, as for an editor group.
      local randomPosition = veaf.getRandomPointInCircle(position, zone.respawnRadius)
      randomPosition.z = randomPosition.y
      randomPosition.y = position.y
      -- #1078, the #66 fix of `veafCombatZone` ported: a hook rather than reading the table after the
      -- call. A command carrying `delayed` or `repeat` returns *before* it spawns, so the table read
      -- here stayed empty: the CAP guarded the wrong zone, the wave was called dead the next tick, and
      -- nothing could destroy the group afterwards. The hook fires now or in thirty seconds alike.
      commandIndex = commandIndex + 1
      local pendingKey = commandIndex
      local commandGroupsNames = {}
      veaf.registerSpawnedGroupsHook(commandGroupsNames, function(newGroupName)
        pending[pendingKey] = nil
        if veafReactiveZone.retiredLists[spawnedGroupsNames] then
          -- the zone moved on while the command waited out its delay: nothing to register it with
          logger(moduleId):debug("zone [%s] spawned [%s] after its wave ended, destroying it", veaf.p(zone.name), veaf.p(newGroupName))
          veafReactiveZone.destroyGroups({ newGroupName })
          return
        end
        -- a `-cap` patrols this zone, not the one its own leg drew (FEAT-AIRCRAFT-ROLES)
        veafAircraftSpawn.defendZoneWithCaps({ newGroupName }, zoneToDefend)
        table.insert(spawnedGroupsNames, newGroupName)
      end)
      local handled = veafInterpreter.execute(command, randomPosition, side, nil, commandGroupsNames)
      if handled and #commandGroupsNames == 0 and veafReactiveZone.isDeferredCommand(command) then
        -- accepted, nothing spawned yet, and said so: a deferred spawn is on its way. A command that
        -- spawned nothing without asking for a delay failed, and is not waited for.
        pending[pendingKey] = timer.getTime() + veafReactiveZone.PENDING_SPAWN_TIMEOUT
      end
    else
      local groupName = groupNameOrCommand
      logger(moduleId):debug("spawning group [%s]", veaf.lp(groupName))
      -- the editor record first: it answers for a late-activated group DCS does not return yet
      local groupData = veaf.getGroupRecord(groupName)
      local liveGroup = Group.getByName(groupName)
      if not groupData and not liveGroup then
        logger(moduleId):error("group [%s] does not exist in the mission!", veaf.p(groupName))
      else
        local spawnSpot = {
          x = zoneCenter.x + zone.respawnDefaultOffset.latDelta,
          y = zoneCenter.y,
          z = zoneCenter.z + zone.respawnDefaultOffset.lonDelta,
        }
        -- Where the mission editor placed it, when that can be read. DCS sometimes returns no units
        -- for a group; the default offset is the fallback, as for a command.
        if groupData and groupData.units and groupData.units[1] then
          spawnSpot = { x = groupData.units[1].x, y = groupData.units[1].alt, z = groupData.units[1].y }
        elseif liveGroup and liveGroup:getUnit(1) then
          spawnSpot = liveGroup:getUnit(1):getPoint()
        else
          logger(moduleId):warn("group [%s] does not have any unit!", veaf.p(groupName))
        end
        -- A group placed with one waypoint and no task reached the end of its route the moment it
        -- appeared, and landed: the Sayqal QRA of *Ligne rouge d'At Tanf*. One tasked CAP or
        -- Intercept with no air engagement now defends the zone.
        local newGroupName = veafAircraftSpawn.deployEditorGroup(groupName, spawnSpot, zone.respawnRadius, zoneToDefend)
        if newGroupName then
          table.insert(spawnedGroupsNames, newGroupName)
        end
      end
    end
  end
  return spawnedGroupsNames
end

--- True when a VEAF command asks for its spawn to start later (`delayed <n>`, `veafSpawnParser`).
---
--- `repeat` is not one: its first group spawns at once, and the following ones reach the hook.
function veafReactiveZone.isDeferredCommand(command)
  return type(command) == "string" and command:lower():find("%f[%w]delayed%f[%W]") ~= nil
end

--- True while a command of the list returned by `deployGroups` is still expected to spawn (#1078).
function veafReactiveZone.hasPendingSpawns(groupsNames)
  local pending = groupsNames and veafReactiveZone.pendingSpawns[groupsNames]
  if not pending then
    return false
  end
  for _, deadline in pairs(pending) do
    if timer.getTime() < deadline then
      return true
    end
  end
  return false
end

--- Destroy every group of the list that still exists, and retire the list: a deferred spawn that
--- arrives into it later is destroyed on arrival rather than left flying, unknown to its zone.
function veafReactiveZone.destroyGroups(groupsNames)
  if groupsNames then
    veafReactiveZone.retiredLists[groupsNames] = true
    veafReactiveZone.pendingSpawns[groupsNames] = nil
  end
  for _, groupName in pairs(groupsNames or {}) do
    local group = Group.getByName(groupName)
    if group then
      group:destroy()
    end
  end
end

--- True when no group of the list has a unit alive.
function veafReactiveZone.areGroupsDead(groupsNames)
  for _, groupName in pairs(groupsNames or {}) do
    local group = Group.getByName(groupName)
    if group then
      for _, unit in pairs(group:getUnits() or {}) do
        if unit and unit:isExist() and unit:getLife() >= 1 then
          return false
        end
      end
    end
  end
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- What the zone depends on (#183)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What kind of entity a name designates now, or nil when nothing answers to it.
local function linkKind(name)
  local airbase = Airbase.getByName(name)
  if airbase then
    local desc = airbase:getDesc()
    if desc and desc.category == Airbase.Category.SHIP then
      return "ship"
    end
    return "airbase"
  end
  if Group.getByName(name) then
    return "group"
  end
  if StaticObject.getByName(name) then
    return "static"
  end
  if Unit.getByName(name) then
    return "unit"
  end
  return nil
end

local function isObjectAlive(object)
  return object ~= nil and object:isExist() and object:getLife() >= 1
end

--- The state of one link: LINKS_OK, LINKS_PAUSED or LINKS_LOST.
local function linkState(kind, name, side, minLifePercent)
  if kind == "airbase" or kind == "ship" then
    local airbase = Airbase.getByName(name)
    if kind == "ship" and not (airbase and airbase:isExist()) then
      return veafReactiveZone.LINKS_LOST
    end
    -- the QRA `airport_link` rule, unchanged: held by the zone's side and above its minimum life
    if not veaf.getAirbaseForCoalition(name, side) or veaf.getAirbaseLife(name, true) < minLifePercent then
      return veafReactiveZone.LINKS_PAUSED
    end
    return veafReactiveZone.LINKS_OK
  end
  if kind == "group" then
    if veafReactiveZone.areGroupsDead({ name }) then
      return veafReactiveZone.LINKS_LOST
    end
    return veafReactiveZone.LINKS_OK
  end
  if kind == "static" then
    return isObjectAlive(StaticObject.getByName(name)) and veafReactiveZone.LINKS_OK or veafReactiveZone.LINKS_LOST
  end
  return isObjectAlive(Unit.getByName(name)) and veafReactiveZone.LINKS_OK or veafReactiveZone.LINKS_LOST
end

--- The state of all the zone's links, and the name of the first one that is not OK.
---
--- Decided 2026-10-05: one lost link is enough. A ship, group, static or unit destroyed stops the zone
--- for good; an airbase or FARP captured, or under `minLifePercent`, pauses it until it is retaken.
--- The kind of each link is read the first time it answers and remembered: a sunk ship answers to
--- nothing, and must still be known as a ship.
--- @param zone table carrying `links` (a list of names)
--- @param side number the coalition that must hold an airbase
--- @param minLifePercent number from 0 to 1
--- @param moduleId string|nil
--- @return string, string|nil
function veafReactiveZone.checkLinks(zone, side, minLifePercent, moduleId)
  if not zone.links or #zone.links == 0 then
    return veafReactiveZone.LINKS_OK, nil
  end
  zone._linkKinds = zone._linkKinds or {}
  local result, culprit = veafReactiveZone.LINKS_OK, nil
  for _, name in ipairs(zone.links) do
    local kind = zone._linkKinds[name]
    if not kind then
      -- looked for on every check until found: a FOB or a site spawned during the mission answers later
      kind = linkKind(name)
      if kind then
        zone._linkKinds[name] = kind
      else
        kind = "unknown"
        zone._unknownLinksReported = zone._unknownLinksReported or {}
      end
      if kind == "unknown" and not zone._unknownLinksReported[name] then
        zone._unknownLinksReported[name] = true
        logger(moduleId):error(
          "zone [%s] is linked to [%s], which is no airbase, ship, group, static or unit",
          veaf.p(zone.name),
          veaf.p(name)
        )
      end
    end
    if kind ~= "unknown" then
      local state = linkState(kind, name, side, minLifePercent)
      if state == veafReactiveZone.LINKS_LOST then
        return state, name
      elseif state == veafReactiveZone.LINKS_PAUSED and result == veafReactiveZone.LINKS_OK then
        result, culprit = state, name
      end
    end
  end
  return result, culprit
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Drawing
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Draw the zone on the F10 map for a coalition, with its description. A mobile zone is drawn where it
--- stands when this is called: the drawing does not follow the unit.
function veafReactiveZone.draw(zone, side, description)
  if zone.triggerZoneName and veafReactiveZone.getTriggerZone(zone) and not veafReactiveZone.isMobile(zone) then
    zone.zoneDrawing = veaf.drawTriggerZone(zone.triggerZoneName, { message = description })
    zone._drawnAsTriggerZone = true
  else
    zone.zoneDrawing = VeafCircleOnMap:new()
      :setName(zone:getName())
      :setCoalition(side)
      :setCenter(veafReactiveZone.getCenter(zone))
      :setRadius(veafReactiveZone.getRadius(zone))
      :setLineType("dashed")
      :setColor("white")
      :setFillColor("transparent")
      :draw()
    zone._drawnAsTriggerZone = false
  end
end

--- Erase the zone drawing, if any.
function veafReactiveZone.erase(zone)
  if zone.zoneDrawing then
    if zone._drawnAsTriggerZone then
      veaf.removeDrawing(zone.zoneDrawing.markId)
    else
      zone.zoneDrawing:erase()
    end
    zone.zoneDrawing = nil
  end
end

veaf.loggers.get(veafReactiveZone.Id):info(veaf.loggers.get(veafReactiveZone.Id):getVersionInfo())
