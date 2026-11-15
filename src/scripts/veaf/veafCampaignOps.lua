------------------------------------------------------------------
-- VEAF persistent campaign: the AI sorties
-- By Zip (2026)
--
-- Features (FEAT-DYNAMIC-CAMPAIGN tickets 04 and 05):
-- ---------
-- * AI supply helicopters: a side flies one to a neutral zone it borders, which it captures by landing
--   there, or to its most damaged zone, which it reinforces; built on veafAircraftSpawn's `transport`
--   job, the one read in game (R24-R28).
-- * Enemy air: a CAP over the front, as many as the opposition level asks, and CAS or SEAD strikes on
--   the enemy zone with the most to hit; aircraft built from type and payload, no template needed.
-- * Hunter: two fighters scrambled at a player on a kill streak.
--
-- Runs inside veafCampaign's single loop (`veafCampaign.beatHooks`), and only in a persistent campaign.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafCampaignOps = {}

--- Identifier. All output in DCS.log will start with this.
veafCampaignOps.Id = "CAMPAIGNOPS"

-- trace level, specific to this module
--veafCampaignOps.LogLevel = "trace"
veaf.loggers.new(veafCampaignOps.Id, veafCampaignOps.LogLevel)

--- Seconds a supply helicopter stays on the ground in a friendly zone after its delivery.
veafCampaignOps.UNLOAD_SECONDS = 30

--- How high a strike and a CAP start, in metres above the airfield they leave from.
veafCampaignOps.STRIKE_ALTITUDE = 2500
veafCampaignOps.CAP_ALTITUDE = 6000

--- Speeds, in m/s: a strike's cruise, an interceptor's.
veafCampaignOps.STRIKE_SPEED = 200
veafCampaignOps.INTERCEPT_SPEED = 250

--- Seconds a strike orbits over its target, engaging, before it goes home.
veafCampaignOps.STRIKE_ORBIT_SECONDS = 600

--- How far around its zone a CAP looks for aircraft, in metres.
veafCampaignOps.CAP_RADIUS = 40000

--- What each strike role engages.
veafCampaignOps.STRIKE_TARGETS = { cas = { "Ground Units" }, sead = { "Air Defence" } }

--- The supply helicopters sent, and the flights launched: records the self-check counts.
veafCampaignOps.helicopters = {}
veafCampaignOps.flights = {}

--- When each side sends its next helicopter, and its next strike.
veafCampaignOps.nextSupply = {}
veafCampaignOps.nextStrike = {}

--- The Hunter's books, by player name: `{ ground, air, groundNeeded, airNeeded, spent }`.
veafCampaignOps.hunted = {}

--- What has happened, for the self-check.
veafCampaignOps.counters = {}

local function logger()
  return veaf.loggers.get(veafCampaignOps.Id)
end

--- A group name nobody uses yet.
local function uniqueGroupName(base)
  local name, index = base, 1
  while Group.getByName(name) do
    index = index + 1
    name = string.format("%s %d", base, index)
  end
  return name
end

--- Whether a group still flies: it exists and has a live unit.
local function liveUnit(groupName)
  local group = Group.getByName(groupName)
  if not (group and group:isExist()) then
    return nil
  end
  for _, unit in ipairs(group:getUnits() or {}) do
    if unit and unit:isExist() and unit:getLife() >= 1 then
      return unit
    end
  end
  return nil
end

local function destroyGroup(groupName)
  local group = Group.getByName(groupName)
  if group then
    pcall(group.destroy, group)
  end
end

local function distance2d(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Supply helicopters (ticket 04)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Whether a helicopter of that side is already flying to that zone.
local function helicopterUnderway(side, zoneName)
  for _, record in ipairs(veafCampaignOps.helicopters) do
    if record.side == side and record.to == zoneName and not record.done then
      return true
    end
  end
  return false
end

--- How many of a side's supply helicopters are out.
function veafCampaignOps.helicoptersOut(side)
  local count = 0
  for _, record in ipairs(veafCampaignOps.helicopters) do
    if record.side == side and not record.done then
      count = count + 1
    end
  end
  return count
end

--- Where a side's helicopter goes: first a neutral zone connected to one of the side's, to capture it;
--- else the side's most damaged zone, to reinforce it. A zone a helicopter of the side already flies to
--- is left out.
--- @param side string
--- @return table|nil the zone
--- @return string|nil "capture" or "resupply"
function veafCampaignOps.supplyTarget(side)
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == "neutral" and not helicopterUnderway(side, zone.name) then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner == side then
          return zone, "capture"
        end
      end
    end
  end
  local worst, worstStrength = nil, 100
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone:isDamaged() and not helicopterUnderway(side, zone.name) then
      local strength = zone:strengthPercent()
      if strength < worstStrength then
        worst, worstStrength = zone, strength
      end
    end
  end
  if worst then
    return worst, "resupply"
  end
  return nil
end

--- The side's zone a helicopter leaves from: the nearest to the target, the target itself excepted.
function veafCampaignOps.nearestOwnZone(side, target, airfieldsOnly)
  local best, bestDistance = nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone ~= target and zone.entry.owner == side and (not airfieldsOnly or zone.entry.airbase) then
      local d = distance2d(zone:getCenter(), target:getCenter())
      if not bestDistance or d < bestDistance then
        best, bestDistance = zone, d
      end
    end
  end
  return best
end

--- Send a supply helicopter from the side's nearest zone to the target, with veafAircraftSpawn's
--- `transport` job: a `Land` task on the nearest clearing to the target's centre.
--- @param side string
--- @param target table the zone
--- @param kind string "capture" or "resupply"
--- @return table|nil the helicopter's record
function veafCampaignOps.sendHelicopter(side, target, kind)
  local source = veafCampaignOps.nearestOwnZone(side, target)
  if not source then
    return nil
  end
  local typeName = veafCampaign.setting("helicopter")[side] or veafCampaign.DYNAMIC_DEFAULTS.helicopter[side]
  local center = target:getCenter()
  local pointName = "CAMPAIGN SUPPLY " .. target.name
  veafNamedPoints.addPoint(pointName, { x = center.x, y = 0, z = center.z })
  local start = source:getCenter()
  start = veaf.findSpawnPoint(start, 600, 30, nil, true) or start
  local name = uniqueGroupName(string.format("%s supply %s", side, target.name))
  local groupData = {
    country = veaf.getCountryForCoalition(veafCampaign.SIDES[side]),
    name = name,
    units = {
      {
        x = start.x,
        y = start.z,
        alt = land.getHeight({ x = start.x, y = start.z }),
        type = typeName,
        name = name .. " #1",
        heading = 0,
        skill = "High",
        payload = veafUnits.aircraftPayload({ typeName = typeName }),
      },
    },
  }
  local spawned = veafAircraftSpawn.spawnHelicopterGroup(groupData, { task = "transport", destination = pointName }, true)
  if not spawned then
    logger():error("the %s supply helicopter for [%s] could not be spawned", side, target.name)
    return nil
  end
  local record = { name = spawned, side = side, from = source.name, to = target.name, kind = kind, startedAt = timer.getTime() }
  table.insert(veafCampaignOps.helicopters, record)
  veafCampaignOps.counters.helicoptersSent = veafCampaignOps.counters.helicoptersSent + 1
  veafCampaign.keepAwake(target, veafCampaign.setting("helicopter_timeout"))
  logger():info("%s supply helicopter [%s] leaves [%s] to %s [%s]", side, spawned, source.name, kind, target.name)
  trigger.action.outTextForCoalition(veafCampaign.SIDES[side], veaf.t("campaign.helicopter_sent", source.name, target.name), 15)
  return record
end

--- Close a helicopter's record, and take the helicopter away.
local function finish(record, outcome)
  record.done, record.outcome = true, outcome
  destroyGroup(record.name)
  if outcome == "failed" then
    veafCampaignOps.counters.helicoptersFailed = veafCampaignOps.counters.helicoptersFailed + 1
  end
  logger():info("supply helicopter [%s] to [%s]: %s", record.name, record.to, outcome)
end

--- Follow one helicopter: landed in its zone, it captures (by holding the ground, the capture rule does
--- it) or delivers; destroyed, or still flying after `helicopter_timeout`, it has failed.
--- @param record table
--- @param now number the mission time
function veafCampaignOps.followHelicopter(record, now)
  if record.done then
    return
  end
  local target = veafCampaign.zones[record.to]
  if record.unloadUntil then
    if now >= record.unloadUntil then
      finish(record, "delivered")
    end
    return
  end
  local unit = liveUnit(record.name)
  if not unit then
    record.done, record.outcome = true, "destroyed"
    veafCampaignOps.counters.helicoptersFailed = veafCampaignOps.counters.helicoptersFailed + 1
    logger():info("supply helicopter [%s] to [%s] destroyed", record.name, record.to)
    return
  end
  local landedHere = not unit:inAir() and distance2d(unit:getPoint(), target:getCenter()) <= (target.entry.radius or 2000)
  if landedHere and not record.landedAt then
    record.landedAt = now
    veafCampaignOps.counters.helicoptersLanded = veafCampaignOps.counters.helicoptersLanded + 1
    -- the measure the in-game check reads: how far from the zone's centre it put down
    logger():info(
      "supply helicopter [%s] landed %d m from [%s]'s centre",
      record.name,
      math.floor(distance2d(unit:getPoint(), target:getCenter())),
      record.to
    )
  end
  if landedHere and target.entry.owner == record.side then
    if record.kind == "capture" then
      finish(record, "captured") -- consumed by the capture, as Foothold's
    else
      veafCampaign.deliver(target, record.side, "helicopter")
      record.unloadUntil = now + veafCampaignOps.UNLOAD_SECONDS
    end
    return
  end
  if target.entry.owner == veafCampaign.enemyOf(record.side) then
    finish(record, "aborted") -- the other side took the zone first
    return
  end
  if not record.landedAt and now - record.startedAt >= veafCampaign.setting("helicopter_timeout") then
    finish(record, "failed")
  end
end

--- Send the helicopters that are due, for every side listed in `supply`.
function veafCampaignOps.dispatchHelicopters(now)
  for _, side in ipairs({ "red", "blue" }) do
    if veafCampaign.sideListed("supply", side) then
      local due = veafCampaignOps.nextSupply[side]
      if due == nil then
        veafCampaignOps.nextSupply[side] = now + veafCampaign.setting("supply_seconds")
      elseif now >= due then
        veafCampaignOps.nextSupply[side] = now + veafCampaign.setting("supply_seconds")
        if veafCampaignOps.helicoptersOut(side) < veafCampaign.setting("max_helicopters") then
          local target, kind = veafCampaignOps.supplyTarget(side)
          if target then
            veafCampaignOps.sendHelicopter(side, target, kind)
          end
        end
      end
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Enemy air (ticket 05)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The aircraft a side flies for a role, as the tools resolved it: `{ type, count, payload }`, or nil.
function veafCampaignOps.aircraft(side, role)
  local air = veafCampaign.data.dynamic and veafCampaign.data.dynamic.air
  return air and air[side] and air[side][role]
end

--- How many of a side's flights fly now, by role or all of them.
function veafCampaignOps.flightsUp(side, role)
  local count = 0
  for _, flight in ipairs(veafCampaignOps.flights) do
    if not flight.done and flight.side == side and (role == nil or flight.role == role) then
      if liveUnit(flight.name) then
        count = count + 1
      else
        flight.done = true
      end
    end
  end
  return count
end

--- The side's zones on the front: its zones connected to a zone it does not hold.
function veafCampaignOps.frontZones(side)
  local front = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner ~= side then
          table.insert(front, zone)
          break
        end
      end
    end
  end
  return front
end

--- How many CAP a side keeps up: one per `cap_per_players` the opposition is sized for, at least one,
--- at most `max_flights`. With no opposition level, one.
function veafCampaignOps.wantedCaps()
  local level = veafOpposition and veafOpposition.getLevel and veafOpposition.getLevel()
  if veafOpposition and veafOpposition.isNoAircraft and veafOpposition.isNoAircraft() then
    return 0
  end
  local wanted = level and math.ceil(level / veafCampaign.setting("air", "cap_per_players")) or 1
  return math.max(1, math.min(wanted, veafCampaign.setting("air", "max_flights")))
end

--- The zone a side's CAP covers: its front zone nearest the other side's players, else its first front zone.
function veafCampaignOps.capZone(side)
  local front = veafCampaignOps.frontZones(side)
  local players = {}
  for _, unit in ipairs(coalition.getPlayers(veafCampaign.SIDES[veafCampaign.enemyOf(side)]) or {}) do
    if unit and unit:isExist() then
      table.insert(players, unit:getPoint())
    end
  end
  local best, bestDistance = front[1], nil
  for _, zone in ipairs(front) do
    for _, point in ipairs(players) do
      local d = distance2d(zone:getCenter(), point)
      if not bestDistance or d < bestDistance then
        best, bestDistance = zone, d
      end
    end
  end
  return best
end

--- How many of a zone's live garrison units count for a strike role: all of them for CAS, the air
--- defence for SEAD.
local function strikeValue(zone, role)
  local value = 0
  for _, group in ipairs(zone.entry.garrison or {}) do
    for _, unit in ipairs(group.units) do
      if unit.alive and (role == "cas" or veafCampaign.reserveCategory(unit.type) == "air_defense") then
        value = value + 1
      end
    end
  end
  return value
end

--- The enemy zone a side strikes: among the enemy zones connected to one of its own, the one with the
--- most to hit for the role; nil when none has anything.
function veafCampaignOps.strikeTarget(side, role)
  local enemy = veafCampaign.enemyOf(side)
  local best, bestValue = nil, 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner == side then
          local value = strikeValue(zone, role)
          if value > bestValue then
            best, bestValue = zone, value
          end
          break
        end
      end
    end
  end
  return best
end

--- A strike: start over the home airfield, engage the role's targets in the zone's circle, orbit there
--- for `STRIKE_ORBIT_SECONDS`, then land at home.
---
--- `params`: `target` (vec3), `radius` (m), `targetTypes`, `airdromeId`, `home` (vec3).
veafAircraftSpawn.roles.campaign_strike = {
  buildRoute = function(context)
    local params, spot = context.params, context.spot
    local speed, altitude = veafCampaignOps.STRIKE_SPEED, spot.y
    local function point(x, z, tasks, extra)
      local wp = {
        x = x,
        y = z,
        alt = altitude,
        alt_type = "BARO",
        type = "Turning Point",
        action = "Turning Point",
        speed = speed,
        speed_locked = true,
        task = { id = "ComboTask", params = { tasks = tasks } },
      }
      for key, value in pairs(extra or {}) do
        wp[key] = value
      end
      return wp
    end
    local engage = {
      id = "EngageTargetsInZone",
      params = {
        point = { x = params.target.x, y = params.target.z },
        zoneRadius = params.radius,
        targetTypes = params.targetTypes,
        priority = 0,
      },
    }
    local roe = { id = "WrappedAction", params = { action = { id = "Option", params = { name = 0, value = 0 } } } }
    local orbit = {
      id = "ControlledTask",
      params = {
        task = { id = "Orbit", params = { pattern = "Circle", altitude = altitude, speed = speed } },
        stopCondition = { duration = veafCampaignOps.STRIKE_ORBIT_SECONDS },
      },
    }
    local route = {
      point(spot.x, spot.z, { roe, engage }),
      point(params.target.x, params.target.z, { orbit }),
    }
    local home = point(params.home.x, params.home.z, {}, { type = "Land", action = "Landing", airdromeId = params.airdromeId })
    table.insert(route, home)
    for _, wp in ipairs(route) do
      for index, task in ipairs(wp.task.params.tasks) do
        task.number, task.enabled, task.auto = index, true, false
      end
    end
    return route, { task = params.task }
  end,
  afterSpawn = function() end,
}

--- An interception: start over the airfield and attack one group (the Hunter).
---
--- `params`: `groupId`, `target` (vec3).
veafAircraftSpawn.roles.campaign_intercept = {
  buildRoute = function(context)
    local params, spot = context.params, context.spot
    local tasks = {
      { id = "WrappedAction", params = { action = { id = "Option", params = { name = 0, value = 0 } } } },
      { id = "AttackGroup", params = { groupId = params.groupId } },
    }
    for index, task in ipairs(tasks) do
      task.number, task.enabled, task.auto = index, true, false
    end
    local function point(x, z, pointTasks)
      return {
        x = x,
        y = z,
        alt = spot.y,
        alt_type = "BARO",
        type = "Turning Point",
        action = "Turning Point",
        speed = veafCampaignOps.INTERCEPT_SPEED,
        speed_locked = true,
        task = { id = "ComboTask", params = { tasks = pointTasks } },
      }
    end
    return { point(spot.x, spot.z, tasks), point(params.target.x, params.target.z, {}) }, { task = "CAP" }
  end,
  afterSpawn = function() end,
}

--- Spawn a flight of the side's aircraft for a role, in the air over an airfield zone, with a role of
--- veafAircraftSpawn.
--- @param side string
--- @param aircraftRole string "cap", "cas" or "sead": which declared aircraft
--- @param origin table the airfield zone it starts over
--- @param roleName string the veafAircraftSpawn role
--- @param params table the role's parameters
--- @param altitude number metres above the field
--- @return string|nil the group's name
function veafCampaignOps.spawnFlight(side, aircraftRole, origin, roleName, params, altitude)
  local aircraft = veafCampaignOps.aircraft(side, aircraftRole)
  if not aircraft then
    logger():warn("no %s aircraft declared for %s", aircraftRole, side)
    return nil
  end
  local center = origin:getCenter()
  local alt = land.getHeight({ x = center.x, y = center.z }) + altitude
  local name = uniqueGroupName(string.format("%s %s %s", side, aircraftRole, origin.name))
  local units = {}
  for index = 1, aircraft.count do
    table.insert(units, {
      x = center.x - 150 * (index - 1),
      y = center.z - 150 * (index - 1),
      alt = alt,
      type = aircraft.type,
      name = string.format("%s #%d", name, index),
      heading = 0,
      skill = "High",
      payload = veaf.deepCopy(aircraft.payload),
    })
  end
  local groupData = { country = veaf.getCountryForCoalition(veafCampaign.SIDES[side]), name = name, units = units }
  local spawned = veafAircraftSpawn.spawnAirplaneGroup(groupData, roleName, params)
  if spawned then
    table.insert(veafCampaignOps.flights, { name = spawned, side = side, role = aircraftRole, origin = origin.name })
    veafCampaignOps.counters.flights = veafCampaignOps.counters.flights + 1
    logger():info("%s %s flight [%s] leaves [%s]", side, aircraftRole, spawned, origin.name)
  else
    logger():error("the %s %s flight from [%s] could not be spawned", side, aircraftRole, origin.name)
  end
  return spawned
end

--- Keep the enemy's CAP up, over the front zone nearest the players.
function veafCampaignOps.maintainCaps(side)
  local missing = veafCampaignOps.wantedCaps() - veafCampaignOps.flightsUp(side, "cap")
  if missing <= 0 or veafCampaignOps.flightsUp(side) >= veafCampaign.setting("air", "max_flights") then
    return
  end
  local zone = veafCampaignOps.capZone(side)
  local origin = zone and veafCampaignOps.nearestOwnZone(side, zone, true)
  if zone and zone.entry.airbase then
    origin = zone
  end
  if not (zone and origin) then
    return
  end
  local center = zone:getCenter()
  veafCampaignOps.spawnFlight(
    side,
    "cap",
    origin,
    "zone_defense",
    { zone = { x = center.x, y = center.z, radius = veafCampaignOps.CAP_RADIUS } },
    veafCampaignOps.CAP_ALTITUDE
  )
end

--- Launch a strike on its cadence: CAS and SEAD in turn, at the enemy zone with the most to hit.
function veafCampaignOps.launchStrike(side, now)
  local due = veafCampaignOps.nextStrike[side]
  if due == nil then
    veafCampaignOps.nextStrike[side] = now + veafCampaign.setting("air", "strike_seconds")
    return
  end
  if now < due then
    return
  end
  veafCampaignOps.nextStrike[side] = now + veafCampaign.setting("air", "strike_seconds")
  if veafCampaignOps.flightsUp(side) >= veafCampaign.setting("air", "max_flights") then
    return
  end
  veafCampaignOps.strikeCount = (veafCampaignOps.strikeCount or 0) + 1
  local role = (veafCampaignOps.strikeCount % 2 == 0) and "sead" or "cas"
  local target = veafCampaignOps.strikeTarget(side, role)
  if not target and role == "sead" then
    role, target = "cas", veafCampaignOps.strikeTarget(side, "cas")
  end
  local origin = target and veafCampaignOps.nearestOwnZone(side, target, true)
  if not (target and origin) then
    return
  end
  local airbase = Airbase.getByName(origin.entry.airbase)
  veafCampaign.keepAwake(target, veafCampaignOps.STRIKE_ORBIT_SECONDS * 3)
  veafCampaignOps.spawnFlight(side, role, origin, "campaign_strike", {
    target = target:getCenter(),
    radius = target.entry.radius or 2000,
    targetTypes = veafCampaignOps.STRIKE_TARGETS[role],
    airdromeId = airbase and airbase:getID(),
    home = origin:getCenter(),
    task = role == "sead" and "SEAD" or "CAS",
  }, veafCampaignOps.STRIKE_ALTITUDE)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Hunter (ticket 05)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A kill: if a player of the players' side made it, count it towards the Hunter.
function veafCampaignOps.onKill(event)
  local kill = veafCampaign.readPlayerKill(event)
  if veafCampaign.over or not kill or not veafCampaign.setting("hunter", "enabled") then
    return
  end
  local killer, player = kill.unit, kill.player
  local books = veafCampaignOps.hunted[player]
  if not books then
    local ground, air = veafCampaign.setting("hunter", "ground_kills"), veafCampaign.setting("hunter", "air_kills")
    books = { ground = 0, air = 0, groundNeeded = math.random(ground, 2 * ground), airNeeded = math.random(air, 2 * air) }
    veafCampaignOps.hunted[player] = books
  end
  if kill.air then
    books.air = books.air + 1
  else
    books.ground = books.ground + 1
  end
  if books.spent or (books.ground < books.groundNeeded and books.air < books.airNeeded) then
    return
  end
  if math.random(100) <= veafCampaign.setting("hunter", "chance") then
    books.spent = true
    veafCampaignOps.launchHunter(killer, player)
  end
end

--- A player starts a new life: the Hunter's books start again.
function veafCampaignOps.onBirth(event)
  local _, player = veafCampaign.playerUnitOf(event)
  if player then
    veafCampaignOps.hunted[player] = nil
  end
end

--- Scramble two enemy fighters at a player, from the enemy airfield zone nearest him.
function veafCampaignOps.launchHunter(unit, player)
  local enemy = veafCampaign.enemyOf(veafCampaign.playerSide())
  local point = unit:getPoint()
  local origin, best = nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy and zone.entry.airbase then
      local d = distance2d(zone:getCenter(), point)
      if not best or d < best then
        origin, best = zone, d
      end
    end
  end
  local group = unit:getGroup()
  if not (origin and group) then
    return nil
  end
  local spawned = veafCampaignOps.spawnFlight(
    enemy,
    "cap",
    origin,
    "campaign_intercept",
    { groupId = group:getID(), target = point },
    veafCampaignOps.CAP_ALTITUDE
  )
  if spawned then
    veafCampaignOps.counters.hunters = veafCampaignOps.counters.hunters + 1
    trigger.action.outTextForCoalition(veafCampaign.SIDES[veafCampaign.playerSide()], veaf.t("campaign.hunter", player, origin.name), 20)
  end
  return spawned
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Loop, self-check, initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- One beat, inside veafCampaign's loop.
function veafCampaignOps.beat(now)
  for _, record in ipairs(veafCampaignOps.helicopters) do
    veafCampaignOps.followHelicopter(record, now)
  end
  if veafCampaign.over then
    return
  end
  veafCampaignOps.dispatchHelicopters(now)
  local enemy = veafCampaign.enemyOf(veafCampaign.playerSide())
  veafCampaignOps.maintainCaps(enemy)
  veafCampaignOps.launchStrike(enemy, now)
end

--- The self-check's lines for the sorties.
function veafCampaignOps.selfCheck(verdict)
  local c = veafCampaignOps.counters
  local enemy = veafCampaign.enemyOf(veafCampaign.playerSide())
  return {
    verdict(
      c.helicoptersSent == 0 or c.helicoptersLanded > 0 or c.helicoptersFailed == 0,
      "campaign.check.helicopters",
      c.helicoptersSent,
      c.helicoptersLanded,
      c.helicoptersFailed
    ),
    verdict(true, "campaign.check.air", c.flights, veafCampaignOps.flightsUp(enemy, "cap"), veafCampaignOps.wantedCaps(), c.hunters),
  }
end

--- Start the sorties of a persistent campaign. Called by veafCampaign.initialize.
function veafCampaignOps.initialize()
  logger():info("Initializing module")
  veafCampaignOps.helicopters, veafCampaignOps.flights, veafCampaignOps.hunted = {}, {}, {}
  veafCampaignOps.nextSupply, veafCampaignOps.nextStrike, veafCampaignOps.strikeCount = {}, {}, 0
  veafCampaignOps.counters = { helicoptersSent = 0, helicoptersLanded = 0, helicoptersFailed = 0, flights = 0, hunters = 0 }
  table.insert(veafCampaign.beatHooks, veafCampaignOps.beat)
  table.insert(veafCampaign.selfChecks, veafCampaignOps.selfCheck)
  veafEventHandler.addCallback("veafCampaignOps.onKill", { "S_EVENT_KILL" }, veafCampaignOps.onKill)
  veafEventHandler.addCallback("veafCampaignOps.onBirth", { "S_EVENT_BIRTH" }, veafCampaignOps.onBirth)
  return true
end

veaf.loggers.get(veafCampaignOps.Id):info(veaf.loggers.get(veafCampaignOps.Id):getVersionInfo())
