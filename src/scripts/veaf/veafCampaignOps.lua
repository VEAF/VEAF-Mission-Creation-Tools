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
-- * Strategic bombers (V1.5, ticket 17): an escorted enemy raid on the players' zones, a raid the players
--   buy in the shop.
-- * In the V1.5, every sortie the AI flies is paid from its side's resources (ticket 12).
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

--- How far around its zone a CAP looks for aircraft, in metres: at most, since it stops short of the
--- enemy's air defence (David, 2026-11-16), and at least `CAP_MIN_RADIUS` over its own zone.
veafCampaignOps.CAP_RADIUS = 40000

--- How far an escort bought in the shop patrols around a helicopter it covers, in metres: fighters cannot
--- fly at a helicopter's speed, so they hold a circle over it rather than the DCS `Escort` task.
veafCampaignOps.ESCORT_HELICOPTER_RADIUS = 15000

--- Whether a DCS unit is a helicopter or a ground-attack airplane (A-10, Su-25, AV-8B...): what Foothold's
--- `InvisibleA10` spares. The enemy CAP leaves them alone unless they lose the draw, the Hunter never chases
--- them, and they neither size nor place the enemy CAP (David, 2026-11-16).
--- @param unit table a DCS unit or object
--- @return boolean
function veafCampaignOps.isSpared(unit)
  if not (unit and unit.hasAttribute) then
    return false
  end
  local ok, spared = pcall(function()
    return unit:hasAttribute("Helicopters") or unit:hasAttribute("Battleplanes") or unit:hasAttribute("Battle airplanes")
  end)
  return ok and spared or false
end

--- Whether a player's aircraft counts as a fighter for the enemy CAP: in the air, armed with a radar-guided
--- air-to-air missile (the opposition's `air_to_air` count), and neither a helicopter nor an attack airplane.
--- @param unit table a DCS unit
--- @return boolean
function veafCampaignOps.isFighter(unit)
  if not (unit and unit:isExist() and unit:inAir()) or veafCampaignOps.isSpared(unit) then
    return false
  end
  return not (veafOpposition and veafOpposition.armedForAirToAir) or veafOpposition.armedForAirToAir(unit)
end

--- Whether the enemy CAP engages a target it detected: any airplane but an attack one; a helicopter or an
--- attack airplane on a draw of `air.cap_helicopter_chance`, made once per target and CAP group, so that a
--- spared target is not drawn again at every sweep of the watchdog.
--- @param capGroupName string
--- @param target table the detected DCS unit
--- @return boolean
function veafCampaignOps.capEngages(capGroupName, target)
  if not veafCampaignOps.isSpared(target) then
    return true
  end
  local draws = veafCampaignOps.capDraws[capGroupName]
  if not draws then
    draws = {}
    veafCampaignOps.capDraws[capGroupName] = draws
  end
  local id = target:getID()
  if draws[id] == nil then
    draws[id] = math.random(100) <= veafCampaign.setting("air", "cap_helicopter_chance")
  end
  return draws[id]
end
veafCampaignOps.CAP_MIN_RADIUS = 5000

--- The stand types a fighter or a strike aircraft may start on: every one but the runway (16) and the
--- helicopter pads (40). Read from `Airbase:getParking()`'s `Term_Type`.
veafCampaignOps.EXCLUDED_STAND_TYPES = { [16] = true, [40] = true }

--- The hardened shelters' `Term_Type`. A fighter takes them first: at Senaki the open stands line the strip
--- to the runway, and groups sharing them deadlock on the taxiway (measured 2026-11-16).
veafCampaignOps.SHELTER_STAND_TYPE = 68

--- The aircraft too large for a shelter: `getParking` gives no stand size, so they are listed. They start
--- on open stands only.
veafCampaignOps.LARGE_AIRCRAFT = {
  ["Tu-22M3"] = true,
  ["Tu-95MS"] = true,
  ["Tu-142"] = true,
  ["Tu-160"] = true,
  ["B-52H"] = true,
  ["B-1B"] = true,
  ["IL-76MD"] = true,
  ["IL-78M"] = true,
  ["A-50"] = true,
  ["KJ-2000"] = true,
  ["E-3A"] = true,
  ["KC-135"] = true,
  ["KC135MPRS"] = true,
  ["KC130"] = true,
  ["C-130"] = true,
  ["C-17A"] = true,
  ["An-26B"] = true,
  ["An-30M"] = true,
}

--- How far beyond the enemy zone's air defence a BARCAP holds, in metres, and the radius it guards.
veafCampaignOps.BARCAP_MARGIN = 15000
veafCampaignOps.BARCAP_RADIUS = 15000

--- The reach assumed for a zone's air defence when none of its missiles can be measured (a sleeping
--- zone), in metres: an estimation, not a measure — a long-range battery and the short-range rest.
veafCampaignOps.ASSUMED_LONG_RANGE = 75000
veafCampaignOps.ASSUMED_SHORT_RANGE = 20000

--- What each strike role engages.
veafCampaignOps.STRIKE_TARGETS = { cas = { "Ground Units" }, sead = { "Air Defence" } }

--- How high and fast a bomber flies, in metres above its field and m/s.
veafCampaignOps.BOMBER_ALTITUDE = 7000
veafCampaignOps.BOMBER_SPEED = 220

--- What DCS calls any bomb, for the `Bombing` task's `weaponType` (Moose's `ENUMS.WeaponFlag.AnyBomb`).
veafCampaignOps.ANY_BOMB = 2147485694

--- Where an escort starts from its bomber, in metres: beside, behind and above it.
veafCampaignOps.ESCORT_START_OFFSET = { x = -600, z = 600, alt = 300 }

--- Seconds after which a raid still out is over, landed or not.
veafCampaignOps.RAID_TIMEOUT = 7200

--- A raid's SEAD and bomber take off, then meet at a hold point before they push (David, 2026-11-16): how near it
--- a flight counts as holding, in metres; how long it holds at most, in seconds, before it goes on alone — a
--- partner lost on the way does not keep it circling for ever; how far beyond it the attack begins, in metres.
--- Not less than a circle's radius: at 200 m/s a flight orbits some 7 km from the point (v^2 / (g tan 30 deg), an
--- estimation), and at 5 km the Tu-22M3 and its SEAD circled 10 minutes over Kutaisi without ever counting as
--- holding (2026-11-16). That they had climbed is told by the altitude, not by this distance.
veafCampaignOps.HOLD_REACHED = 15000
veafCampaignOps.HOLD_SECONDS = 1200
veafCampaignOps.PUSH_DISTANCE = 2000

--- How far back along its axis of approach a bomber flies after the target before it turns home, in metres: going
--- straight home from the target, a Tu-22M3 went on over Kobuleti and was shot down (David, 2026-11-16). Back the
--- way it came, it flies where its SEAD cleared the defences.
veafCampaignOps.EGRESS_DISTANCE = 20000

--- How far below its cruise altitude a raid's flight may still be and hold, in metres: a flight still climbing
--- out of its field does not hold (2026-11-16: with the hold over the field, both pushed straight after take-off).
veafCampaignOps.HOLD_ALTITUDE_SLACK = 1000

--- The length of the bomber's carpet, in metres: at 1 km, 33 FAB-250 hit only the town around Ozurgeti's factory
--- (2026-11-16); David wants it tight on the target.
veafCampaignOps.CARPET_LENGTH = 100

--- Seconds during which a flight just spawned counts as up even when DCS does not answer it by name yet
--- (2026-11-16: a CAP spawned on its parking was taken for lost the next beat, and a second one sent and paid).
veafCampaignOps.FLIGHT_GRACE = 60

--- The step at which a line is walked to find where it leaves the enemy's air defence, in metres.
veafCampaignOps.REACH_STEP = 1000

--- Numbers the raids' hold flags; never reset, so that a flag raised for a raid is never another's.
veafCampaignOps.raidSerial = veafCampaignOps.raidSerial or 0

--- The supply helicopters sent, and the flights launched: records the self-check counts.
veafCampaignOps.helicopters = {}
veafCampaignOps.flights = {}

--- The bomber raids: `{ name, escort, sead, side, target, purchased, startedAt, hold, done, outcome }`.
veafCampaignOps.raids = {}

--- When each side sends its next raid.
veafCampaignOps.nextRaid = {}

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

--- The group names this module has given, so that it never gives one twice: DCS may not answer a group just
--- spawned by its name yet, and a second group of the same name replaces the first.
veafCampaignOps.usedNames = {}

--- A group name nobody uses yet.
local function uniqueGroupName(base)
  local name, index = base, 1
  while Group.getByName(name) or veafCampaignOps.usedNames[name] do
    index = index + 1
    name = string.format("%s %d", base, index)
  end
  veafCampaignOps.usedNames[name] = true
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

--- The enemy zone whose air defence covers a zone's centre, by the reach measured (or remembered from the
--- last time it was awake), cut to `takeoff_threat_range`; nil when none does. An assumed reach does not count:
--- it would ground a side on a guess. What takes off from a field under it is shot down while it climbs
--- (2026-11-16: the whole raid package of Senaki, 38 km from Kobuleti's Patriot, lost within 70 s of the
--- take-off). The cut: the reach DCS gives is the missile's against a high target, and grounded every red
--- field, Sukhumi 120 km away included; an aircraft climbing out is seen much closer (an estimation, to tune).
--- @param side string the zone's side
--- @param zone table
--- @return string|nil the enemy zone's name
function veafCampaignOps.coveringEnemy(side, zone)
  local enemy = veafCampaign.enemyOf(side)
  for _, other in ipairs(veafCampaign.zoneList) do
    if other.placed and other.entry.owner == enemy and other.entry.garrison then
      local reach, measured = veafCampaignOps.threatRange(other)
      reach = math.min(reach, veafCampaign.setting("takeoff_threat_range"))
      if measured and distance2d(zone:getCenter(), other:getCenter()) <= reach then
        return other.name
      end
    end
  end
  return nil
end

--- Whether a side's aircraft may take off from an airfield zone: it has an airbase and no enemy air defence
--- covers it. A SEAD flight takes off all the same: putting that defence out is its job, and what it destroys
--- frees the field for the strikes (David, 2026-11-16). A field refused is logged with the defence covering it.
--- @param side string
--- @param zone table
--- @param role string|nil the flight's role: "sead" ignores the defence
--- @return boolean
function veafCampaignOps.canTakeOffFrom(side, zone, role)
  if not zone.entry.airbase then
    return false
  end
  local covering = role ~= "sead" and veafCampaignOps.coveringEnemy(side, zone)
  local key = "takeoff " .. side .. " " .. zone.name
  if covering then
    veafCampaign.debugOnce(
      key,
      covering,
      "DECISION",
      "nothing of %s takes off from [%s]: it is under the air defence of [%s]",
      side,
      zone.name,
      covering
    )
    return false
  end
  veafCampaign.forgetTold(key)
  return true
end

--- The side's zone a helicopter leaves from: the nearest to the target, the target itself excepted. With
--- `airfieldsOnly`, the nearest airfield its aircraft may take off from (`canTakeOffFrom`, for `role`).
function veafCampaignOps.nearestOwnZone(side, target, airfieldsOnly, role)
  local best, bestDistance = nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if
      zone.placed
      and zone ~= target
      and zone.entry.owner == side
      and (not airfieldsOnly or veafCampaignOps.canTakeOffFrom(side, zone, role))
    then
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
        if veafCampaignOps.helicoptersOut(side) >= veafCampaign.setting("max_helicopters") then
          veafCampaign.debug("DECISION", "%s sends no supply helicopter: %d already out", side, veafCampaignOps.helicoptersOut(side))
        else
          local target, kind = veafCampaignOps.supplyTarget(side)
          if not target then
            veafCampaign.debug("DECISION", "%s sends no supply helicopter: no neutral zone bordered, no damaged zone", side)
          end
          if target then
            local typeName = veafCampaign.setting("helicopter")[side] or veafCampaign.DYNAMIC_DEFAULTS.helicopter[side]
            veafCampaignOps.paidSortie(side, veafCampaign.unitPrice(typeName), "a supply helicopter", function()
              return veafCampaignOps.sendHelicopter(side, target, kind)
            end)
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

--- What a flight of a side's aircraft for a role costs, in resource points (ticket 12).
function veafCampaignOps.flightPrice(side, role)
  local aircraft = veafCampaignOps.aircraft(side, role)
  return aircraft and aircraft.count * veafCampaign.unitPrice(aircraft.type) or 0
end

--- Fly a sortie of the AI if its side can pay it and keep its reserve (ticket 12): `launch` is called only
--- then, and what it sent is paid.
--- @param side string
--- @param price number points
--- @param what string for the log
--- @param launch function returning what was sent, or nil
--- @return any what `launch` returned, or nil
function veafCampaignOps.paidSortie(side, price, what, launch)
  local stock = veafCampaignLogistics and veafCampaignLogistics.active and veafCampaignLogistics.stock(side)
  local key = "unpaid " .. side .. " " .. what
  if not veafCampaign.canPay(side, price) then
    veafCampaignOps.counters.unpaid = veafCampaignOps.counters.unpaid + 1
    -- said once until it is paid: the refusal is re-examined at every beat (2026-11-16, 50 times in 9 min)
    if veafCampaign.toldOnce[key] == nil then
      logger():info("%s cannot pay %s (%d points): not sent", side, what, price)
    end
    veafCampaign.debugOnce(
      key,
      "unpaid",
      "DECISION",
      "%s does not send %s: costs %d, stock %s",
      side,
      what,
      price,
      tostring(stock and math.floor(stock))
    )
    return nil
  end
  veafCampaign.forgetTold(key)
  local sent = launch()
  if sent then
    veafCampaign.pay(side, price, "partial", what)
    veafCampaign.debug(
      "DECISION",
      "%s sends %s [%s] for %d points (stock was %s)",
      side,
      what,
      tostring(type(sent) == "table" and (sent.name or sent.groupName) or sent),
      price,
      tostring(stock and math.floor(stock))
    )
  else
    veafCampaign.debug("DECISION", "%s could not spawn %s: nothing paid", side, what)
  end
  return sent
end

--- How many of a side's flights fly now, by role or all of them.
function veafCampaignOps.flightsUp(side, role)
  local count = 0
  for _, flight in ipairs(veafCampaignOps.flights) do
    if not flight.done and flight.side == side and (role == nil or flight.role == role) then
      if liveUnit(flight.name) or timer.getTime() - (flight.spawnedAt or -math.huge) < veafCampaignOps.FLIGHT_GRACE then
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
  local following = veafOpposition and veafOpposition.follow and veafOpposition.follow ~= veafOpposition.FOLLOW_OFF
  if following and (level or 0) == 0 then
    -- following the players' fighters, and none is up: helicopters and attack airplanes fly unopposed
    return 0
  end
  local wanted = level and math.ceil(level / veafCampaign.setting("air", "cap_per_players")) or 1
  return math.max(1, math.min(wanted, veafCampaign.setting("air", "max_flights")))
end

--- The front zones a side's CAP may cover, the nearest to the other side's fighters first (helicopters and
--- attack airplanes do not count); in the order of `frontZones` when no fighter is up.
--- @param side string
--- @return table zones
function veafCampaignOps.capZones(side)
  local front = veafCampaignOps.frontZones(side)
  local fighters = {}
  for _, unit in ipairs(coalition.getPlayers(veafCampaign.SIDES[veafCampaign.enemyOf(side)]) or {}) do
    if veafCampaignOps.isFighter(unit) then
      table.insert(fighters, unit:getPoint())
    end
  end
  local distance = {}
  for index, zone in ipairs(front) do
    local best = math.huge
    for _, point in ipairs(fighters) do
      best = math.min(best, distance2d(zone:getCenter(), point))
    end
    distance[zone] = { best, index }
  end
  table.sort(front, function(a, b)
    if distance[a][1] ~= distance[b][1] then
      return distance[a][1] < distance[b][1]
    end
    return distance[a][2] < distance[b][2]
  end)
  return front
end

--- The zone a side's CAP covers: its front zone nearest the other side's fighters, else its first front zone.
function veafCampaignOps.capZone(side)
  return veafCampaignOps.capZones(side)[1]
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
--- The reach from which a CAS strike keeps out of an air defence, in metres: a medium or long-range SAM (a Hawk,
--- an SA-6), not the guns and short-range missiles a CAS strike is armoured against. On 2026-11-16 a red CAS sent at
--- Hatay, under a Hawk of 40 km, dropped its bombs 20 km short and was shot down: 60 points for nothing.
veafCampaignOps.CAS_AVOIDED_REACH = 15000

--- The zone of the target's side whose measured air defence covers the target with a reach a CAS strike avoids
--- (`CAS_AVOIDED_REACH`), the target's own included; nil when none does. An assumed reach does not count.
--- @param target table the zone
--- @return string|nil the defending zone's name
function veafCampaignOps.defendedBy(target)
  for _, other in ipairs(veafCampaign.zoneList) do
    if other.placed and other.entry.owner == target.entry.owner and other.entry.garrison then
      local reach, measured = veafCampaignOps.threatRange(other)
      if measured and reach >= veafCampaignOps.CAS_AVOIDED_REACH and distance2d(target:getCenter(), other:getCenter()) <= reach then
        return other.name
      end
    end
  end
  return nil
end

--- The enemy zone on the front a strike of that role goes for: the one with the most to hit. A CAS strike leaves out
--- a zone under a medium or long-range air defence (`defendedBy`): a SEAD's job first.
--- @param side string
--- @param role string "cas" or "sead"
--- @return table|nil the zone
--- @return string|nil when nothing was found for a CAS, the defence that kept it off the first zone left out
function veafCampaignOps.strikeTarget(side, role)
  local enemy = veafCampaign.enemyOf(side)
  local best, bestValue, avoided = nil, 0, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner == side then
          local value = strikeValue(zone, role)
          local defence = role == "cas" and value > bestValue and veafCampaignOps.defendedBy(zone)
          if defence then
            avoided = avoided or string.format("[%s] under the air defence of [%s]", zone.name, defence)
          elseif value > bestValue then
            best, bestValue = zone, value
          end
          break
        end
      end
    end
  end
  return best, not best and avoided or nil
end

--- An orbit at a raid's hold point, until its flag is raised or `HOLD_SECONDS` have passed.
--- @param hold table `{ x, z, flag }`
local function holdTask(hold, altitude, speed)
  return {
    id = "ControlledTask",
    params = {
      task = { id = "Orbit", params = { pattern = "Circle", altitude = altitude, speed = speed } },
      stopCondition = { userFlag = hold.flag, duration = veafCampaignOps.HOLD_SECONDS },
    },
  }
end

--- Where a raid's flight leaves its hold for its target: `PUSH_DISTANCE` beyond the hold, toward the target.
local function pushPoint(hold, target)
  local dx, dz = target.x - hold.x, target.z - hold.z
  local length = math.max(1, math.sqrt(dx * dx + dz * dz))
  local step = math.min(veafCampaignOps.PUSH_DISTANCE, length)
  return { x = hold.x + dx / length * step, z = hold.z + dz / length * step }
end

--- A strike: start over the home airfield, engage the role's targets in the zone's circle, orbit there
--- for `STRIKE_ORBIT_SECONDS`, then land at home. A raid's SEAD first holds at its hold point until its flag is
--- raised, and engages nothing before it leaves it.
---
--- `params`: `target` (vec3), `radius` (m), `targetTypes`, `airdromeId`, `home` (vec3), `hold` (`{ x, z, flag }`,
--- optional).
veafAircraftSpawn.roles.campaign_strike = {
  buildRoute = function(context)
    local params, spot = context.params, context.spot
    local speed, altitude = veafCampaignOps.STRIKE_SPEED, params.altitude or spot.y
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
    local route
    if params.hold then
      local push = pushPoint(params.hold, params.target)
      -- its targets from the start, weapons held until the push: given only at the push point, a SEAD flew over
      -- Kobuleti without a shot, where sent straight, with its targets from the start, it had fired (2026-11-16)
      local hold = { id = "WrappedAction", params = { action = { id = "Option", params = { name = 0, value = 4 } } } }
      route = {
        point(spot.x, spot.z, { hold, engage }),
        point(params.hold.x, params.hold.z, { holdTask(params.hold, altitude, speed) }),
        point(push.x, push.z, { roe }),
        point(params.target.x, params.target.z, { orbit }),
      }
    else
      route = {
        point(spot.x, spot.z, { roe, engage }),
        point(params.target.x, params.target.z, { orbit }),
      }
    end
    if context.takeoffPoint then
      -- started on the ground: the take-off point first, carrying the tasks the first point had
      local takeoff = veaf.deepCopy(context.takeoffPoint)
      takeoff.task = route[1].task
      route[1] = takeoff
    end
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
    local altitude = params.altitude or spot.y
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
        alt = altitude,
        alt_type = "BARO",
        type = "Turning Point",
        action = "Turning Point",
        speed = veafCampaignOps.INTERCEPT_SPEED,
        speed_locked = true,
        task = { id = "ComboTask", params = { tasks = pointTasks } },
      }
    end
    local route = { point(spot.x, spot.z, tasks), point(params.target.x, params.target.z, {}) }
    if context.takeoffPoint then
      local takeoff = veaf.deepCopy(context.takeoffPoint)
      takeoff.task = route[1].task
      route[1] = takeoff
    end
    return route, { task = "CAP" }
  end,
  afterSpawn = function() end,
}

--- Where a flight of `count` aircraft starts on an airfield: hot on free stands when there are enough,
--- else on the runway. The take-off waypoint and one position per aircraft.
---
--- Free stands are the ones `Airbase:getParking()` reports with no aircraft on them (`TO_AC`), runway and
--- helicopter pads left out. Seating an aircraft by its stand's `Term_Index` is what the scripting API
--- offers, and DCS honours it (measured 2026-11-16). Shelters come first, open stands after; a large
--- aircraft (`LARGE_AIRCRAFT`) takes open stands only.
--- @param airbase table the DCS airbase
--- @param count number
--- @param aircraftType string|nil the DCS type of the flight
--- @return table|nil the take-off waypoint (mission-table `x`, `y`)
--- @return table the positions: `{ x, z, parking }`
function veafCampaignOps.takeoffFrom(airbase, count, aircraftType)
  local center = airbase:getPoint()
  local large = veafCampaignOps.LARGE_AIRCRAFT[aircraftType or ""]
  local shelter = veafCampaignOps.SHELTER_STAND_TYPE
  local stands = {}
  for _, spot in pairs(airbase:getParking() or {}) do
    local usable = not spot.TO_AC and not veafCampaignOps.EXCLUDED_STAND_TYPES[spot.Term_Type] and spot.vTerminalPos
    if usable and not (large and spot.Term_Type == shelter) then
      table.insert(stands, spot)
    end
  end
  table.sort(stands, function(a, b)
    local aShelter, bShelter = a.Term_Type == shelter, b.Term_Type == shelter
    if aShelter ~= bShelter then
      return aShelter
    end
    return (a.Term_Index or 0) < (b.Term_Index or 0)
  end)
  local point = {
    x = center.x,
    y = center.z,
    alt = land.getHeight({ x = center.x, y = center.z }),
    alt_type = "BARO",
    speed = 0,
    airdromeId = airbase:getID(),
    task = { id = "ComboTask", params = { tasks = {} } },
  }
  local positions = {}
  if #stands >= count then
    point.type, point.action = "TakeOffParkingHot", "From Parking Area Hot"
    for index = 1, count do
      local stand = stands[index]
      table.insert(positions, { x = stand.vTerminalPos.x, z = stand.vTerminalPos.z, parking = stand.Term_Index })
    end
  else
    point.type, point.action = "TakeOff", "From Runway"
    for index = 1, count do
      table.insert(positions, { x = center.x - 50 * (index - 1), z = center.z })
    end
  end
  return point, positions
end

--- Spawn a flight of the side's aircraft for a role, taking off from an airfield zone, with a role of
--- veafAircraftSpawn. It starts hot on the field's free stands, or on its runway when they are taken:
--- an air start over the field is kept only for a zone whose airbase DCS does not know.
--- @param side string
--- @param aircraftRole string "cap", "cas" or "sead": which declared aircraft
--- @param origin table the airfield zone it leaves from
--- @param roleName string the veafAircraftSpawn role
--- @param params table the role's parameters
--- @param altitude number the altitude it flies its job at, metres above the field
--- @param airStart boolean|nil true to start in the air over the field, as a raid does
--- @return string|nil the group's name
function veafCampaignOps.spawnFlight(side, aircraftRole, origin, roleName, params, altitude, airStart)
  local aircraft = veafCampaignOps.aircraft(side, aircraftRole)
  if not aircraft then
    logger():warn("no %s aircraft declared for %s", aircraftRole, side)
    return nil
  end
  local center = origin:getCenter()
  local cruise = land.getHeight({ x = center.x, y = center.z }) + altitude
  params.altitude = params.altitude or cruise
  local airbase = origin.entry.airbase and Airbase.getByName(origin.entry.airbase)
  local takeoff, positions = nil, {}
  if airbase and airbase.getParking and not airStart then
    takeoff, positions = veafCampaignOps.takeoffFrom(airbase, aircraft.count, aircraft.type)
    params.takeoffPoint = takeoff
  end
  local name = uniqueGroupName(string.format("%s %s %s", side, aircraftRole, origin.name))
  local units = {}
  local offset = params.startOffset or { x = 0, z = 0, alt = 0 }
  for index = 1, aircraft.count do
    local position = positions[index] or { x = center.x - 150 * (index - 1) + offset.x, z = center.z - 150 * (index - 1) + offset.z }
    table.insert(units, {
      x = position.x,
      y = position.z,
      alt = takeoff and land.getHeight({ x = position.x, y = position.z }) or cruise + offset.alt,
      parking = position.parking,
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
    local aim = params.target or (params.zone and { x = params.zone.x, z = params.zone.y })
    table.insert(veafCampaignOps.flights, {
      name = spawned,
      side = side,
      role = aircraftRole,
      origin = origin.name,
      aim = aim,
      spawnedAt = timer.getTime(),
      typeName = aircraft.type,
    })
    veafCampaignOps.counters.flights = veafCampaignOps.counters.flights + 1
    logger():info("%s %s flight [%s] leaves [%s] (%s)", side, aircraftRole, spawned, origin.name, takeoff and takeoff.action or "air start")
  else
    logger():error("the %s %s flight from [%s] could not be spawned", side, aircraftRole, origin.name)
  end
  return spawned
end

--- How far a zone's air defence reaches, in metres: the longest maximum range of the missiles its live
--- units carry, read from DCS (`getAmmo`, `rangeMaxAltMax`), and remembered in the zone's entry (saved with
--- the campaign). A sleeping zone has no live unit to ask: its reach is then the one remembered, else assumed,
--- the long-range figure when its class has a long-range battery.
--- @param zone table
--- @return number metres
--- @return boolean true when measured, false when assumed
function veafCampaignOps.threatRange(zone)
  local reach, measured, present = 0, false, false
  for _, group in ipairs(zone.entry.garrison or {}) do
    for unitIndex, record in ipairs(group.units) do
      local unit = record.alive and Unit.getByName(veafCampaign.unitName(group, unitIndex))
      present = present or unit ~= nil
      if unit and unit.getAmmo then
        local ok, ammo = pcall(unit.getAmmo, unit)
        for _, item in ipairs(ok and type(ammo) == "table" and ammo or {}) do
          local desc = item.desc
          if desc and desc.category == Weapon.Category.MISSILE and desc.rangeMaxAltMax then
            measured = true
            reach = math.max(reach, desc.rangeMaxAltMax)
          end
        end
      end
    end
  end
  if measured then
    zone.entry.reach = reach
    return reach, true
  end
  if present then
    -- awake, and no missile left: its launchers are gone, what was remembered no longer holds
    zone.entry.reach = nil
  elseif zone.entry.reach then
    return zone.entry.reach, true
  end
  local size = zone.entry.size or {}
  return size.long_range_sam and veafCampaignOps.ASSUMED_LONG_RANGE or veafCampaignOps.ASSUMED_SHORT_RANGE, false
end

--- The point of a line, from an enemy zone toward a side's airfield, nearest the enemy zone that is out of every
--- enemy zone's air defence by `clearance` — not only the zone's own (2026-11-16: a BARCAP held out of its target's
--- reach was shot down by the Patriot of the zone next to it). The airfield's end when no point of the line is.
--- @param side string the side flying there
--- @param from table the enemy zone's centre (vec3)
--- @param to table the airfield's centre (vec3)
--- @param clearance number metres beyond the reach
--- @return table the point `{ x, z }`
--- @return number its distance from `from`, metres
function veafCampaignOps.edgeOfReach(side, from, to, clearance)
  local enemy = veafCampaign.enemyOf(side)
  local threats = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy and zone.entry.garrison then
      table.insert(threats, { center = zone:getCenter(), reach = veafCampaignOps.threatRange(zone) + clearance })
    end
  end
  local length = distance2d(from, to)
  local ux, uz = 0, 0
  if length > 0 then
    ux, uz = (to.x - from.x) / length, (to.z - from.z) / length
  end
  local d = 0
  while d < length do
    local point = { x = from.x + ux * d, z = from.z + uz * d }
    local clear = true
    for _, threat in ipairs(threats) do
      if distance2d(point, threat.center) < threat.reach then
        clear = false
        break
      end
    end
    if clear then
      return point, d
    end
    d = d + veafCampaignOps.REACH_STEP
  end
  return { x = to.x, z = to.z }, length
end

--- Where a BARCAP on an enemy zone holds: on the line from the zone to the side's nearest airfield zone, out of
--- every enemy air defence by `BARCAP_MARGIN`, its guarded circle included; over its own airfield when no point
--- of the line is.
--- @param side string the side flying it
--- @param zone table the enemy zone
--- @return table|nil the guarded zone `{ x, y = easting, radius }`
--- @return table|nil the airfield zone it leaves from
--- @return number the distance from the enemy zone's centre, metres
--- @return number the enemy zone's air defence reach, metres
--- @return boolean whether that reach was measured
function veafCampaignOps.barcapStation(side, zone)
  local origin = veafCampaignOps.nearestOwnZone(side, zone, true)
  if not origin then
    return nil
  end
  local reach, measured = veafCampaignOps.threatRange(zone)
  local point, distance =
    veafCampaignOps.edgeOfReach(side, zone:getCenter(), origin:getCenter(), veafCampaignOps.BARCAP_MARGIN + veafCampaignOps.BARCAP_RADIUS)
  local station = { x = point.x, y = point.z, radius = veafCampaignOps.BARCAP_RADIUS }
  return station, origin, distance, reach, measured
end

--- Keep the enemy's CAP up, over the front zone nearest the players.
function veafCampaignOps.maintainCaps(side)
  local missing = veafCampaignOps.wantedCaps() - veafCampaignOps.flightsUp(side, "cap")
  if missing <= 0 or veafCampaignOps.flightsUp(side) >= veafCampaign.setting("air", "max_flights") then
    return
  end
  -- the front zone nearest the fighters whose circle stays out of the enemy's SAMs: the nearest one alone
  -- grounded the CAP for a whole evening (2026-11-16, Syria: Idlib under Hatay's Hawk, Taftanaz never tried)
  local zone, origin, radius, limit, refused
  for _, candidate in ipairs(veafCampaignOps.capZones(side)) do
    local candidateOrigin = veafCampaignOps.nearestOwnZone(side, candidate, true)
    if candidate.entry.airbase and veafCampaignOps.canTakeOffFrom(side, candidate) then
      candidateOrigin = candidate
    end
    local candidateRadius, candidateLimit, squeezed = veafCampaignOps.capRadius(side, candidate)
    if candidateOrigin and not squeezed then
      zone, origin, radius, limit = candidate, candidateOrigin, candidateRadius, candidateLimit
      break
    end
    refused = refused or { candidate.name, candidateLimit }
  end
  if not zone then
    -- even its smallest circle is under the enemy's SAMs everywhere: it would only feed them (2026-11-16: a CAP
    -- over Senaki, in the Patriot's reach, shot down 35 s after take-off, sent again, shot down again)
    local reason = refused
        and string.format(
          "%s sends no CAP: even %d km over every front zone is under the enemy's air defence, or has no airfield (first: [%s], under [%s])",
          side,
          veafCampaignOps.CAP_MIN_RADIUS / 1000,
          refused[1],
          tostring(refused[2])
        )
      or string.format("%s sends no CAP: no front zone, or no airfield to leave from", side)
    -- said once, not every beat (2026-11-16: the same line every 10 s filled the log)
    if veafCampaignOps.lastCapRefusal[side] ~= reason then
      veafCampaignOps.lastCapRefusal[side] = reason
      veafCampaign.debug("DECISION", "%s", reason)
    end
    return
  end
  veafCampaignOps.lastCapRefusal[side] = nil
  local center = zone:getCenter()
  veafCampaign.debugOnce(
    "cap " .. side,
    zone.name .. " " .. origin.name .. " " .. math.floor(radius / 1000),
    "DECISION",
    "%s CAP over [%s] from [%s], radius %d km%s",
    side,
    zone.name,
    origin.name,
    math.floor(radius / 1000),
    limit and (", short of the air defence of [" .. limit .. "]") or ""
  )
  local sent = veafCampaignOps.paidSortie(side, veafCampaignOps.flightPrice(side, "cap"), "a CAP", function()
    local spawned = veafCampaignOps.spawnFlight(
      side,
      "cap",
      origin,
      "zone_defense",
      { zone = { x = center.x, y = center.z, radius = radius } },
      veafCampaignOps.CAP_ALTITUDE
    )
    if spawned and veafSpawn and veafSpawn.capTargetFilters then
      veafSpawn.capTargetFilters[spawned] = function(target)
        return veafCampaignOps.capEngages(spawned, target)
      end
    end
    return spawned
  end)
  if sent then
    veafCampaign.forgetTold("cap " .. side) -- the next CAP is news again
  end
end

--- How far a side's CAP over its zone may look: `CAP_RADIUS`, cut short of every enemy zone's air defence by
--- `BARCAP_MARGIN` so that it does not fly into the SAMs (David, 2026-11-16: two MiG-29 shot down that way),
--- `CAP_MIN_RADIUS` at least.
--- @param side string the side flying it
--- @param zone table the zone it covers
--- @return number metres
--- @return string|nil the enemy zone that cut it short
function veafCampaignOps.capRadius(side, zone)
  local radius, limit = veafCampaignOps.CAP_RADIUS, nil
  local enemy = veafCampaign.enemyOf(side)
  for _, other in ipairs(veafCampaign.zoneList) do
    if other.placed and other.entry.owner == enemy and other.entry.garrison then
      local room = distance2d(zone:getCenter(), other:getCenter()) - veafCampaignOps.threatRange(other) - veafCampaignOps.BARCAP_MARGIN
      if room < radius then
        radius, limit = room, other.name
      end
    end
  end
  return math.max(veafCampaignOps.CAP_MIN_RADIUS, radius), limit, radius < veafCampaignOps.CAP_MIN_RADIUS
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
    veafCampaign.debug("DECISION", "%s sends no strike: %d flights up, the most it flies", side, veafCampaignOps.flightsUp(side))
    return
  end
  veafCampaignOps.strikeCount = (veafCampaignOps.strikeCount or 0) + 1
  local role = (veafCampaignOps.strikeCount % 2 == 0) and "sead" or "cas"
  local target, avoided = veafCampaignOps.strikeTarget(side, role)
  if not target and role == "sead" then
    role = "cas"
    target, avoided = veafCampaignOps.strikeTarget(side, "cas")
  end
  local origin = target and veafCampaignOps.nearestOwnZone(side, target, true, role)
  local key = "strike " .. side
  if not (target and origin) then
    local reason = (target and "no airfield to leave from")
      or (avoided and ("no CAS into an air defence: " .. avoided))
      or "no enemy zone on the front with anything to hit"
    veafCampaign.debugOnce(key, reason, "DECISION", "%s sends no strike: %s", side, reason)
    return
  end
  veafCampaign.forgetTold(key)
  veafCampaign.debug("DECISION", "%s %s strike on [%s] from [%s]", side, role, target.name, origin.name)
  local airbase = Airbase.getByName(origin.entry.airbase)
  veafCampaignOps.paidSortie(side, veafCampaignOps.flightPrice(side, role), "a " .. role .. " strike", function()
    veafCampaign.keepAwake(target, veafCampaignOps.STRIKE_ORBIT_SECONDS * 3)
    return veafCampaignOps.spawnFlight(side, role, origin, "campaign_strike", {
      target = target:getCenter(),
      radius = target.entry.radius or 2000,
      targetTypes = veafCampaignOps.STRIKE_TARGETS[role],
      airdromeId = airbase and airbase:getID(),
      home = origin:getCenter(),
      task = role == "sead" and "SEAD" or "CAS",
    }, veafCampaignOps.STRIKE_ALTITUDE)
  end)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Strategic bombers (ticket 17)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function comboTask(tasks)
  for index, task in ipairs(tasks) do
    task.number, task.enabled, task.auto = index, true, false
  end
  return { id = "ComboTask", params = { tasks = tasks } }
end

local function weaponsFree()
  return { id = "WrappedAction", params = { action = { id = "Option", params = { name = 0, value = 0 } } } }
end

--- A bomber that does not break off: no reaction to a threat (`AI.Option.Air.id.REACTION_ON_THREAT`, 1, set to
--- `NO_REACTION`, 0) and no jettison (`PROHIBIT_JETT`, 15). On 2026-11-16 a Tu-22M3 locked by a SAM turned away and
--- jettisoned its bombs, which never armed; it was shot down on the way home.
local function pressOn()
  return {
    { id = "WrappedAction", params = { action = { id = "Option", params = { name = 1, value = 0 } } } },
    { id = "WrappedAction", params = { action = { id = "Option", params = { name = 15, value = true } } } },
  }
end

--- A bomber: takes off, holds at its hold point until its flag is raised when it has one, bombs the target point
--- with all it carries along its axis of approach, overflies it, lands at home.
---
--- `params`: `target` (vec3), `airdromeId`, `home` (vec3), `hold` (`{ x, z, flag }`, optional), `speed` (m/s,
--- optional: in a package, the SEAD's).
veafAircraftSpawn.roles.campaign_bomber = {
  buildRoute = function(context)
    local params, spot = context.params, context.spot
    local altitude = params.altitude or spot.y
    local function point(x, z, tasks, extra)
      local wp = {
        x = x,
        y = z,
        alt = altitude,
        alt_type = "BARO",
        type = "Turning Point",
        action = "Turning Point",
        speed = params.speed or veafCampaignOps.BOMBER_SPEED,
        speed_locked = true,
        task = comboTask(tasks),
      }
      for key, value in pairs(extra or {}) do
        wp[key] = value
      end
      return wp
    end
    -- a carpet: with the `Bombing` task, a Tu-22M3 dropped its 33 bombs one or two a pass (2026-11-16). The
    -- Mission Editor writes the point as `x`/`y`; `point` is given too, DCS reading one or the other.
    local from = params.hold and pushPoint(params.hold, params.target) or { x = spot.x, z = spot.z }
    local bombing = {
      id = "CarpetBombing",
      params = {
        attackType = "Carpet",
        x = params.target.x,
        y = params.target.z,
        point = { x = params.target.x, y = params.target.z },
        carpetLength = veafCampaignOps.CARPET_LENGTH,
        weaponType = veafCampaignOps.ANY_BOMB,
        expend = "All",
        attackQty = 1,
        attackQtyLimit = false,
        groupAttack = true,
        altitude = altitude,
        altitudeEnabled = true,
      },
    }
    local tasks = { weaponsFree() }
    for _, option in ipairs(pressOn()) do
      table.insert(tasks, option)
    end
    table.insert(tasks, bombing)
    local home = point(params.home.x, params.home.z, {}, { type = "Land", action = "Landing", airdromeId = params.airdromeId })
    -- the egress: back the way it came, `EGRESS_DISTANCE` from the target, before it turns home
    local inbound = params.hold and from or { x = spot.x, z = spot.z }
    local dx, dz = inbound.x - params.target.x, inbound.z - params.target.z
    local length = math.sqrt(dx * dx + dz * dz)
    local back = math.min(veafCampaignOps.EGRESS_DISTANCE, length)
    local egress = length > 0 and point(params.target.x + dx / length * back, params.target.z + dz / length * back, {}) or nil
    local route
    if params.hold then
      route = {
        -- no reaction and no jettison from the start: fired at before its push point, a Tu-22M3 jettisoned its
        -- 33 bombs 50 km short of the target (2026-11-16)
        point(spot.x, spot.z, pressOn()),
        point(params.hold.x, params.hold.z, { holdTask(params.hold, altitude, params.speed or veafCampaignOps.BOMBER_SPEED) }),
        point(from.x, from.z, tasks),
        point(params.target.x, params.target.z, {}),
      }
    else
      route = { point(spot.x, spot.z, tasks), point(params.target.x, params.target.z, {}) }
    end
    if egress then
      table.insert(route, egress)
    end
    table.insert(route, home)
    if context.takeoffPoint then
      -- started on the ground: the take-off point first, carrying the tasks the first point had
      local takeoff = veaf.deepCopy(context.takeoffPoint)
      takeoff.task = route[1].task
      route[1] = takeoff
    end
    return route, { task = "Ground Attack" }
  end,
  afterSpawn = function() end,
}

--- An escort: starts in the air beside its bomber, follows it and engages the fighters that come near; goes
--- home when the bomber is gone.
---
--- `params`: `groupId` (the bomber's), `airdromeId`, `home` (vec3).
veafAircraftSpawn.roles.campaign_escort = {
  buildRoute = function(context)
    local params, spot = context.params, context.spot
    local altitude = params.altitude or spot.y
    local escort = {
      id = "Escort",
      params = {
        groupId = params.groupId,
        pos = { x = -500, y = 300, z = 300 },
        lastWptIndexFlag = false,
        engagementDistMax = 60000,
        targetTypes = { "Planes" },
      },
    }
    local route = {
      {
        x = spot.x,
        y = spot.z,
        alt = altitude,
        alt_type = "BARO",
        type = "Turning Point",
        action = "Turning Point",
        speed = veafCampaignOps.INTERCEPT_SPEED,
        task = comboTask({ weaponsFree(), escort }),
      },
      {
        x = params.home.x,
        y = params.home.z,
        alt = altitude,
        alt_type = "BARO",
        type = "Land",
        action = "Landing",
        airdromeId = params.airdromeId,
        speed = veafCampaignOps.INTERCEPT_SPEED,
        task = comboTask({}),
      },
    }
    if context.takeoffPoint then
      local takeoff = veaf.deepCopy(context.takeoffPoint)
      takeoff.task = route[1].task
      route[1] = takeoff
    end
    return route, { task = "Escort" }
  end,
  afterSpawn = function() end,
}

--- What a raid on a side's zones would hit: its factories with a building standing first, by how many stand;
--- else its zone with the most garrison units alive. Only a zone some airfield of the side can reach counts
--- (`raidOrigin`): a target with no field far enough would send nothing, raid after raid.
--- @param side string the side that sends the raid
--- @return table|nil the target zone
function veafCampaignOps.raidTarget(side)
  local enemy = veafCampaign.enemyOf(side)
  local best, bestValue = nil, 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy and veafCampaignOps.raidOrigin(side, zone) then
      local standing = zone:structuresStanding()
      local value = standing > 0 and 1000 + standing or zone:countUnits()
      if value > bestValue then
        best, bestValue = zone, value
      end
    end
  end
  return best
end

--- Where a raid leaves from: the side's airfield zone nearest the target that is at least
--- `bombers.min_distance` from it, so that the defenders have the time to intercept, and that no enemy air
--- defence covers (`canTakeOffFrom`).
--- @return table|nil the zone
function veafCampaignOps.raidOrigin(side, target)
  local best, bestDistance = nil, nil
  local minimum = veafCampaign.setting("bombers", "min_distance")
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone.entry.airbase then
      local d = distance2d(zone:getCenter(), target:getCenter())
      if d >= minimum and (not bestDistance or d < bestDistance) and veafCampaignOps.canTakeOffFrom(side, zone) then
        best, bestDistance = zone, d
      end
    end
  end
  return best
end

--- The zone of the target's side whose air defence covers the target and has the most of it: what a raid's
--- SEAD flight goes for. Nil when nothing covers the target, and the raid flies without SEAD.
--- @param target table the raid's target
--- @return table|nil the zone
function veafCampaignOps.coveringAirDefence(target)
  local best, bestValue = nil, 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == target.entry.owner then
      local value = strikeValue(zone, "sead")
      if value > bestValue and distance2d(zone:getCenter(), target:getCenter()) <= veafCampaignOps.threatRange(zone) then
        best, bestValue = zone, value
      end
    end
  end
  return best
end

--- What a raid package costs a side: the bomber, its BARCAP, the SEAD flight when it has one, the escort when
--- `bombers.escort` is on.
function veafCampaignOps.raidPrice(side, withSead)
  local price = veafCampaignOps.flightPrice(side, "bomber") + veafCampaignOps.flightPrice(side, "cap")
  if withSead then
    price = price + veafCampaignOps.flightPrice(side, "sead")
  end
  if veafCampaign.setting("bombers", "escort") then
    price = price + veafCampaignOps.flightPrice(side, "cap")
  end
  return price
end

--- Send a raid package at a zone (David, 2026-11-16): a BARCAP holding the axis out of the defences' reach, a
--- SEAD flight against the air defence covering the target, and the bomber — with an escort only when
--- `bombers.escort` is on. All of it is paid or none: the AI's from its resources, the players' in credits
--- (`purchased`). Every flight takes off from the origin (David: from the ground, like every campaign flight);
--- with a SEAD, the SEAD and the bomber meet at a hold point out of the defences' reach, then the SEAD pushes and
--- the bomber `bombers.package_delay` after it, on the same axis (`followRaid`).
--- @param side string the side sending it
--- @param target table the zone
--- @param purchased boolean|nil
--- @return table|nil the raid's record
function veafCampaignOps.sendRaid(side, target, purchased)
  local origin = veafCampaignOps.raidOrigin(side, target)
  if not (origin and veafCampaignOps.aircraft(side, "bomber")) then
    veafCampaign.debug(
      "DECISION",
      "%s sends no raid on [%s]: no bomber declared, or no airfield %d km away",
      side,
      target.name,
      veafCampaign.setting("bombers", "min_distance") / 1000
    )
    logger():info(
      "%s has no bomber, or no airfield %d m from [%s]: no raid",
      side,
      veafCampaign.setting("bombers", "min_distance"),
      target.name
    )
    return nil
  end
  local defence = veafCampaignOps.aircraft(side, "sead") and veafCampaignOps.coveringAirDefence(target)
  local price = veafCampaignOps.raidPrice(side, defence ~= nil)
  if not purchased and not veafCampaign.canPay(side, price) then
    veafCampaignOps.counters.unpaid = veafCampaignOps.counters.unpaid + 1
    logger():info("%s cannot pay a raid on [%s] (%d points)", side, target.name, price)
    veafCampaign.debug("DECISION", "%s does not send a raid on [%s]: the package costs %d", side, target.name, price)
    return nil
  end
  local now = timer.getTime()
  local airbase = Airbase.getByName(origin.entry.airbase)
  local record = {
    side = side,
    target = target.name,
    from = origin.name,
    purchased = purchased or nil,
    startedAt = now,
    airdromeId = airbase and airbase:getID(),
  }
  local station = veafCampaignOps.barcapStation(side, target)
  if station and veafCampaignOps.aircraft(side, "cap") then
    record.barcap = veafCampaignOps.spawnFlight(side, "cap", origin, "zone_defense", { zone = station }, veafCampaignOps.CAP_ALTITUDE)
  end
  if defence then
    veafCampaignOps.raidSerial = veafCampaignOps.raidSerial + 1
    local hold = veafCampaignOps.edgeOfReach(side, target:getCenter(), origin:getCenter(), veafCampaignOps.BARCAP_MARGIN)
    record.hold = { x = hold.x, z = hold.z }
    record.seadFlag = string.format("campaign raid %d sead", veafCampaignOps.raidSerial)
    record.bomberFlag = string.format("campaign raid %d bomber", veafCampaignOps.raidSerial)
    local seadParams = {
      target = defence:getCenter(),
      radius = defence.entry.radius or 2000,
      targetTypes = veafCampaignOps.STRIKE_TARGETS.sead,
      airdromeId = record.airdromeId,
      home = origin:getCenter(),
      task = "SEAD",
      hold = { x = hold.x, z = hold.z, flag = record.seadFlag },
    }
    record.sead = veafCampaignOps.spawnFlight(side, "sead", origin, "campaign_strike", seadParams, veafCampaignOps.STRIKE_ALTITUDE)
    record.seadAltitude = seadParams.altitude
    record.seadOn = defence.name
  end
  if not veafCampaignOps.spawnRaidBomber(record) then
    return nil
  end
  if not purchased then
    veafCampaign.pay(side, price, "partial", "a raid package")
  end
  table.insert(veafCampaignOps.raids, record)
  veafCampaignOps.counters.raids = veafCampaignOps.counters.raids + 1
  veafCampaign.keepAwake(target, veafCampaignOps.RAID_TIMEOUT)
  if defence then
    -- the SEAD's zone too, or its defence is not there when the SEAD comes (measured 2026-11-16)
    veafCampaign.keepAwake(defence, veafCampaignOps.RAID_TIMEOUT)
  end
  logger():info(
    "%s raid package on [%s] from [%s]: BARCAP [%s], SEAD [%s] on [%s], bomber [%s]",
    side,
    target.name,
    origin.name,
    tostring(record.barcap),
    tostring(record.sead),
    tostring(record.seadOn),
    tostring(record.name)
  )
  veafCampaign.debug(
    "DECISION",
    "%s raid on [%s] from [%s] (%d km), package %d points: BARCAP %s, SEAD %s on [%s], hold %s, escort %s",
    side,
    target.name,
    origin.name,
    math.floor(distance2d(origin:getCenter(), target:getCenter()) / 1000),
    price,
    tostring(record.barcap),
    tostring(record.sead),
    tostring(record.seadOn),
    record.hold and string.format("%d km out of the target", math.floor(distance2d(record.hold, target:getCenter()) / 1000)) or "none",
    tostring(veafCampaign.setting("bombers", "escort"))
  )
  local defender = veafCampaign.SIDES[target.entry.owner]
  if defender then
    trigger.action.outTextForCoalition(defender, veaf.t("campaign.raid.inbound", target.name, origin.name), 30)
  end
  trigger.action.outTextForCoalition(veafCampaign.SIDES[side], veaf.t("campaign.raid.sent", origin.name, target.name), 20)
  veafCampaign.notify("raid", record)
  return record
end

--- Put a raid's bomber in the air, and its escort when `bombers.escort` is on.
--- @return boolean whether the bomber flies
function veafCampaignOps.spawnRaidBomber(record)
  local origin, target = veafCampaign.zones[record.from], veafCampaign.zones[record.target]
  if not (origin and target) then
    return false
  end
  local aim = target:isFactory() and target:structuresCenter() or target:getCenter()
  local params = { target = aim, airdromeId = record.airdromeId, home = origin:getCenter() }
  if record.hold then
    -- in a package it flies at the SEAD's speed, so that it stays behind it
    params.hold = { x = record.hold.x, z = record.hold.z, flag = record.bomberFlag }
    params.speed = veafCampaignOps.STRIKE_SPEED
  end
  record.name = veafCampaignOps.spawnFlight(record.side, "bomber", origin, "campaign_bomber", params, veafCampaignOps.BOMBER_ALTITUDE)
  record.bomberAltitude = params.altitude
  if not record.name then
    return false
  end
  local group = Group.getByName(record.name)
  if veafCampaign.setting("bombers", "escort") and group and veafCampaignOps.aircraft(record.side, "cap") then
    record.escort = veafCampaignOps.spawnFlight(record.side, "cap", origin, "campaign_escort", {
      groupId = group:getID(),
      airdromeId = record.airdromeId,
      home = params.home,
      -- beside and above its bomber, not inside it, when a field DCS does not know starts both in the air
      startOffset = veafCampaignOps.ESCORT_START_OFFSET,
    }, veafCampaignOps.BOMBER_ALTITUDE)
  end
  veafCampaign.debug(
    "FLIGHT",
    "%s bomber [%s] takes off from [%s] for [%s] (aim x=%d z=%d), escort %s",
    record.side,
    record.name,
    record.from,
    record.target,
    aim.x,
    aim.z,
    tostring(record.escort)
  )
  return true
end

--- The raid of a side still out, if any.
function veafCampaignOps.raidUnderway(side)
  for _, raid in ipairs(veafCampaignOps.raids) do
    if raid.side == side and not raid.done then
      return raid
    end
  end
  return nil
end

--- Whether a raid's flight holds: in the air within `HOLD_REACHED` of the hold point, climbed to its cruise
--- altitude but `HOLD_ALTITUDE_SLACK`.
local function holding(unit, hold, altitude)
  if not (unit and unit:inAir()) then
    return false
  end
  local point = unit:getPoint()
  return distance2d(point, hold) <= veafCampaignOps.HOLD_REACHED and point.y >= (altitude or 0) - veafCampaignOps.HOLD_ALTITUDE_SLACK
end

--- A raid's push from its hold: once the bomber holds and its SEAD too — or the SEAD is lost —, the SEAD's flag
--- is raised, then the bomber's `bombers.package_delay` after it, so that the bomber comes in right behind.
--- Seconds between two log lines of a raid still waiting at its hold.
veafCampaignOps.HOLD_REPORT_SECONDS = 60

--- Where a raid's flight stands from its hold: "<what> <d> km away at <alt> m", "(holds)" when it holds.
local function holdState(what, unit, hold, altitude)
  if not unit then
    return what .. " lost"
  end
  local point = unit:getPoint()
  return string.format(
    "%s %d km away at %d m%s",
    what,
    math.floor(distance2d(point, hold) / 1000),
    math.floor(point.y),
    holding(unit, hold, altitude) and " (holds)" or ""
  )
end

local function pushFromHold(raid, bomber, now)
  if not raid.pushedAt and now >= (raid.holdReportAt or 0) then
    raid.holdReportAt = now + veafCampaignOps.HOLD_REPORT_SECONDS
    veafCampaign.debug(
      "FLIGHT",
      "raid on [%s] waits at its hold: %s, %s",
      raid.target,
      holdState("bomber", bomber, raid.hold, raid.bomberAltitude),
      holdState("SEAD", raid.sead and liveUnit(raid.sead), raid.hold, raid.seadAltitude)
    )
  end
  if not raid.pushedAt and holding(bomber, raid.hold, raid.bomberAltitude) then
    local sead = raid.sead and liveUnit(raid.sead)
    if not sead then
      raid.pushedAt, raid.bomberPushAt = now, now
      veafCampaign.debug("FLIGHT", "raid on [%s]: no SEAD left, the bomber pushes alone", raid.target)
    elseif holding(sead, raid.hold, raid.seadAltitude) then
      trigger.action.setUserFlag(raid.seadFlag, 1)
      raid.pushedAt = now
      raid.bomberPushAt = now + veafCampaign.setting("bombers", "package_delay")
      veafCampaign.debug(
        "FLIGHT",
        "raid on [%s]: the SEAD pushes on [%s], the bomber %d s behind",
        raid.target,
        tostring(raid.seadOn),
        raid.bomberPushAt - now
      )
    end
  end
  if raid.bomberPushAt and not raid.bomberPushed and now >= raid.bomberPushAt then
    trigger.action.setUserFlag(raid.bomberFlag, 1)
    raid.bomberPushed = true
    veafCampaign.debug("FLIGHT", "raid on [%s]: the bomber pushes", raid.target)
  end
end

--- Follow one raid: its SEAD and bomber push from their hold together; the bomber gone, it is a raid shot down;
--- landed once it has flown, or out too long, it is over.
function veafCampaignOps.followRaid(raid, now)
  if raid.done then
    return
  end
  local unit = liveUnit(raid.name)
  local flying = unit and unit:inAir()
  if flying then
    raid.airborne = true
  end
  if unit and raid.hold then
    pushFromHold(raid, unit, now)
  end
  if not unit then
    raid.done, raid.outcome = true, "destroyed"
    veafCampaignOps.counters.raidsDestroyed = veafCampaignOps.counters.raidsDestroyed + 1
    logger():info("bomber raid [%s] on [%s] destroyed", raid.name, raid.target)
  elseif (raid.airborne and not flying) or now - raid.startedAt > veafCampaignOps.RAID_TIMEOUT then
    raid.done, raid.outcome = true, "home"
    destroyGroup(raid.name)
    logger():info("bomber raid [%s] on [%s] is over", raid.name, raid.target)
  end
  if raid.outcome == "home" and raid.escort then
    -- a raid back home takes its escort with it; a bomber shot down leaves its escort fighting, then
    -- flying home on its own route
    destroyGroup(raid.escort)
  end
  if raid.done then
    veafCampaign.debug("FLIGHT", "raid on [%s] ends: %s", raid.target, raid.outcome)
  end
end

--- The enemy's raids, on their cadence: every `bombers.seconds`, one raid out at a time.
function veafCampaignOps.launchRaids(side, now)
  if not veafCampaign.setting("bombers", "enabled") then
    return
  end
  local due = veafCampaignOps.nextRaid[side]
  if due == nil then
    veafCampaignOps.nextRaid[side] = now + veafCampaign.setting("bombers", "seconds")
    return
  end
  if now < due then
    return
  end
  veafCampaignOps.nextRaid[side] = now + veafCampaign.setting("bombers", "seconds")
  if veafCampaignOps.raidUnderway(side) then
    veafCampaign.debug("DECISION", "%s sends no raid: one is still out", side)
    return
  end
  local target = veafCampaignOps.raidTarget(side)
  if target then
    veafCampaignOps.sendRaid(side, target)
  else
    veafCampaign.debug("DECISION", "%s sends no raid: no enemy zone any of its airfields can reach", side)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The fate of every campaign aircraft, while `dynamic.debug` is on
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The campaign flight a DCS unit belongs to: a flight, a raid's part, a supply helicopter. Their units are
--- named `<group> #<n>`.
--- @param unitName string|nil
--- @return table|nil the record
--- @return string|nil its group's name
function veafCampaignOps.flightOf(unitName)
  if type(unitName) ~= "string" then
    return nil
  end
  local groupName = unitName:match("^(.-) #%d+$") or unitName
  for _, flight in ipairs(veafCampaignOps.flights) do
    if flight.name == groupName then
      return flight, groupName
    end
  end
  for _, helicopter in ipairs(veafCampaignOps.helicopters) do
    if helicopter.name == groupName then
      return helicopter, groupName
    end
  end
  return nil
end

local function eventUnitName(object)
  if type(object) ~= "table" then
    return nil
  end
  if object.unitName then
    return object.unitName
  end
  if object.getName then
    local ok, name = pcall(object.getName, object)
    return ok and name or nil
  end
  return nil
end

--- "name (type)" for the log. A unit already destroyed answers no type: its flight's type is told instead, or the
--- type is left out ("red cas Aleppo #1 (nil) is lost", 2026-11-16).
local function describe(object, flight)
  local name = eventUnitName(object)
  local typeName = type(object) == "table" and (object.unitType or (object.getTypeName and select(2, pcall(object.getTypeName, object))))
  if type(typeName) ~= "string" then
    typeName = flight and flight.typeName
  end
  if type(typeName) ~= "string" then
    return tostring(name)
  end
  return string.format("%s (%s)", tostring(name), typeName)
end

--- Whether an event's target is part of the scenery: a wreck crushing buildings "kills" them, ten lines of
--- `509796368 (nil)` for one crash (2026-11-16).
local function isScenery(object)
  if type(object) ~= "table" then
    return false
  end
  if object.getCategory then
    local ok, category = pcall(object.getCategory, object)
    if ok and category == Object.Category.SCENERY then
      return true
    end
  end
  return object.unitName ~= nil and object.unitType == nil and tonumber(object.unitName) ~= nil
end

--- A weapon released, a kill, a landing, a crash: told when a campaign aircraft is in it.
function veafCampaignOps.onFlightEvent(event)
  if not veafCampaign.debugging() or type(event) ~= "table" then
    return
  end
  local shooter = event.dcsInitiator or event.initiator
  local flight = veafCampaignOps.flightOf(eventUnitName(event.initiator) or eventUnitName(shooter))
  local victim = veafCampaignOps.flightOf(eventUnitName(event.target))
  -- veafEventHandler hands a data table: its type under `type`, the DCS objects under `dcs…`
  local id = event.type and event.type.id or event.id
  if flight and id == world.event.S_EVENT_SHOT then
    local weapon = event.weaponName
      or (event.weapon and event.weapon.getTypeName and select(2, pcall(event.weapon.getTypeName, event.weapon)))
    local point = shooter and shooter.getPoint and select(2, pcall(shooter.getPoint, shooter))
    local away = (type(point) == "table" and flight.aim) and math.floor(distance2d(point, flight.aim)) or nil
    -- what it has left: the true count, and two releases never write the same line, which DCS would fold into one
    local left = nil
    local ok, ammo = false, nil
    if shooter and shooter.getAmmo then
      ok, ammo = pcall(shooter.getAmmo, shooter)
    end
    if ok then
      left = 0
      for _, item in ipairs(type(ammo) == "table" and ammo or {}) do
        if not (item.desc and item.desc.category == Weapon.Category.SHELL) then
          left = left + (item.count or 0)
        end
      end
    end
    -- and where it fires from: 33 releases logged 50 km from the aim where David saw them on the target (2026-11-16)
    local near, nearDistance = nil, nil
    if type(point) == "table" then
      for _, zone in ipairs(veafCampaign.zoneList) do
        local d = zone.placed and distance2d(point, zone:getCenter())
        if d and (not nearDistance or d < nearDistance) then
          near, nearDistance = zone.name, d
        end
      end
    end
    veafCampaign.debug(
      "FLIGHT",
      "%s releases %s%s%s%s",
      describe(event.initiator),
      tostring(weapon),
      away and string.format(", %d m from its aim", away) or "",
      near and string.format(", near [%s] %d km", near, math.floor(nearDistance / 1000)) or "",
      left and string.format(", %d left", left) or ""
    )
  elseif id == world.event.S_EVENT_KILL and (flight or victim) and not isScenery(event.dcsTarget or event.target) then
    veafCampaign.debug("FLIGHT", "%s kills %s", describe(event.initiator, flight), describe(event.target, victim))
  elseif flight and id == world.event.S_EVENT_LAND then
    -- a landing off any airfield has no place: "lands at nil" (2026-11-16)
    local place = eventUnitName(event.place)
    local point = shooter and shooter.getPoint and select(2, pcall(shooter.getPoint, shooter))
    local where = place and ("at " .. tostring(place)) or "in the open"
    if not place and type(point) == "table" then
      local near, nearDistance = nil, nil
      for _, zone in ipairs(veafCampaign.zoneList) do
        local d = zone.placed and distance2d(point, zone:getCenter())
        if d and (not nearDistance or d < nearDistance) then
          near, nearDistance = zone.name, d
        end
      end
      if near then
        where = string.format("in the open, %d km from [%s]", math.floor(nearDistance / 1000), near)
      end
    end
    veafCampaign.debug("FLIGHT", "%s lands %s", describe(event.initiator, flight), where)
  elseif flight and (id == world.event.S_EVENT_CRASH or id == world.event.S_EVENT_DEAD) then
    veafCampaign.debug("FLIGHT", "%s is lost", describe(event.initiator, flight))
  end
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
  if veafCampaignOps.isSpared(killer) then
    -- as Foothold: no Hunter on a helicopter or an attack airplane, which could not fight it off
    return
  end
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
      if (not best or d < best) and veafCampaignOps.canTakeOffFrom(enemy, zone) then
        origin, best = zone, d
      end
    end
  end
  local group = unit:getGroup()
  if not (origin and group) then
    return nil
  end
  local spawned = veafCampaignOps.paidSortie(enemy, veafCampaignOps.flightPrice(enemy, "cap"), "the Hunter", function()
    return veafCampaignOps.spawnFlight(
      enemy,
      "cap",
      origin,
      "campaign_intercept",
      { groupId = group:getID(), target = point },
      veafCampaignOps.CAP_ALTITUDE
    )
  end)
  if spawned then
    veafCampaignOps.counters.hunters = veafCampaignOps.counters.hunters + 1
    trigger.action.outTextForCoalition(veafCampaign.SIDES[veafCampaign.playerSide()], veaf.t("campaign.hunter", player, origin.name), 20)
  end
  return spawned
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Loop, self-check, initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Each zone's air defence and the missiles it has left, in the testing period's log: a SAM that stops firing
--- may be empty (2026-11-16) — an empty launcher is still listed, since that is what the line is for.
function veafCampaignOps.reportAirDefences()
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.garrison then
      local total, units, order, byType = 0, 0, {}, {}
      for _, group in ipairs(zone.entry.garrison) do
        for unitIndex, record in ipairs(group.units) do
          local unit = record.alive and Unit.getByName(veafCampaign.unitName(group, unitIndex))
          if unit and unit.hasAttribute and unit:hasAttribute("Air Defence") then
            local missiles = 0
            local ok, ammo = pcall(unit.getAmmo, unit)
            for _, item in ipairs(ok and type(ammo) == "table" and ammo or {}) do
              if item.desc and item.desc.category == Weapon.Category.MISSILE then
                missiles = missiles + (item.count or 0)
              end
            end
            if not byType[record.type] then
              byType[record.type] = { units = 0, missiles = 0 }
              table.insert(order, record.type)
            end
            byType[record.type].units = byType[record.type].units + 1
            byType[record.type].missiles = byType[record.type].missiles + missiles
            total, units = total + missiles, units + 1
          end
        end
      end
      if units > 0 then
        local reach, measured = veafCampaignOps.threatRange(zone)
        local parts = {}
        for _, typeName in ipairs(order) do
          local entry = byType[typeName]
          table.insert(parts, string.format("%s%s %d", typeName, entry.units > 1 and (" x" .. entry.units) or "", entry.missiles))
        end
        veafCampaign.debug(
          "AIRDEF",
          "[%s] %s: %d missiles left on %d air defence units (%s), reach %d km%s",
          zone.name,
          tostring(zone.entry.owner),
          total,
          units,
          table.concat(parts, ", "),
          math.floor(reach / 1000),
          measured and "" or " (assumed)"
        )
      end
    end
  end
end

--- One beat, inside veafCampaign's loop.
function veafCampaignOps.beat(now)
  if veafCampaign.debugging() and now >= (veafCampaignOps.nextAirDefenceReport or 0) then
    veafCampaignOps.nextAirDefenceReport = now + veafCampaign.setting("debug_status_seconds")
    veafCampaignOps.reportAirDefences()
  end
  for _, record in ipairs(veafCampaignOps.helicopters) do
    veafCampaignOps.followHelicopter(record, now)
  end
  for _, raid in ipairs(veafCampaignOps.raids) do
    veafCampaignOps.followRaid(raid, now)
  end
  if veafCampaign.over then
    return
  end
  veafCampaignOps.dispatchHelicopters(now)
  local enemy = veafCampaign.enemyOf(veafCampaign.playerSide())
  veafCampaignOps.maintainCaps(enemy)
  veafCampaignOps.launchStrike(enemy, now)
  veafCampaignOps.launchRaids(enemy, now)
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
    verdict(true, "campaign.check.raids", c.raids, c.raidsDestroyed, c.unpaid),
  }
end

--- Start the sorties of a persistent campaign. Called by veafCampaign.initialize.
function veafCampaignOps.initialize()
  logger():info("Initializing module")
  veafCampaignOps.helicopters, veafCampaignOps.flights, veafCampaignOps.hunted = {}, {}, {}
  veafCampaignOps.nextSupply, veafCampaignOps.nextStrike, veafCampaignOps.strikeCount = {}, {}, 0
  veafCampaignOps.raids, veafCampaignOps.nextRaid = {}, {}
  veafCampaignOps.usedNames, veafCampaignOps.nextAirDefenceReport = {}, nil
  veafCampaignOps.capDraws, veafCampaignOps.lastCapRefusal = {}, {}
  veafCampaignOps.counters = {
    helicoptersSent = 0,
    helicoptersLanded = 0,
    helicoptersFailed = 0,
    flights = 0,
    hunters = 0,
    raids = 0,
    raidsDestroyed = 0,
    unpaid = 0,
  }
  table.insert(veafCampaign.beatHooks, veafCampaignOps.beat)
  table.insert(veafCampaign.selfChecks, veafCampaignOps.selfCheck)
  veafCampaignOps.followFighters()
  veafEventHandler.addCallback("veafCampaignOps.onKill", { "S_EVENT_KILL" }, veafCampaignOps.onKill)
  veafEventHandler.addCallback("veafCampaignOps.onBirth", { "S_EVENT_BIRTH" }, veafCampaignOps.onBirth)
  veafEventHandler.addCallback(
    "veafCampaignOps.onFlightEvent",
    { "S_EVENT_SHOT", "S_EVENT_KILL", "S_EVENT_LAND", "S_EVENT_CRASH", "S_EVENT_DEAD" },
    veafCampaignOps.onFlightEvent
  )
  return true
end

--- Size the enemy CAP on the players' fighters in the air, unless the mission already follows a count: a
--- persistent campaign's opposition fixed at a level sent a CAP at helicopters and A-10s alike, and never
--- none (David, 2026-11-16, after Foothold).
function veafCampaignOps.followFighters()
  if not (veafOpposition and veafOpposition.setFollow) or veafOpposition.isNoAircraft() then
    return
  end
  if veafOpposition.follow ~= veafOpposition.FOLLOW_OFF then
    return
  end
  veafOpposition.playersCoalition = veafCampaign.SIDES[veafCampaign.playerSide()]
  veafOpposition.setFollow(veafOpposition.FOLLOW_AIR_TO_AIR)
  logger():info("the enemy CAP follows the players' fighters in the air")
end

veaf.loggers.get(veafCampaignOps.Id):info(veaf.loggers.get(veafCampaignOps.Id):getVersionInfo())
