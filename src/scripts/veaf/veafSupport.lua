------------------------------------------------------------------
-- VEAF support assets: the AWACS and the tankers held out of the enemy's air defence
-- By zip (2026)
--
-- Features:
-- ---------
-- * Each asset named in the SUPPORT module's `assets` holds on the line from its Mission Editor orbit to the
--   nearest enemy air defence, at the first point out of the reach of every one of them plus `margin`.
-- * An AWACS also holds `awacs_standoff` from every threat's centre, whatever its reach: its radar sees far, it has
--   no need to be near the front. The tankers hold as near as the reach allows.
-- * It retreats at once, with `retreat_margin`, when a threat reaches its orbit; it moves closer only when the
--   way has been clear for `advance_seconds` and the new orbit is `min_advance` closer: a SAM that wakes and
--   sleeps every few minutes does not make it shuttle.
-- * Each move redraws its F10 marks (its leg and its label, for its side only) and is announced to its side, by
--   bearing and range from the bullseye, frequency unchanged.
-- * In a mission alone, the threats are the enemy's ground units carrying a surface-to-air missile of
--   `sam_reach_floor` or more; a persistent campaign gives the reach measured on its zones instead
--   (`veafSupport.threatSource`), the front it must not cross (`veafSupport.frontLimit`) and its voice
--   (`veafSupport.tell`).
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSupport = {}

veafSupport.Id = "SUPPORT"

veafSupport.Version = "1.0.0"

veafSupport.LogLevel = "info"

veaf.loggers.new(veafSupport.Id, veafSupport.LogLevel)

--- What the module does when `mission.yaml` does not say.
veafSupport.DEFAULTS = {
  assets = {}, -- the AWACS and tankers held, by group name; each needs an Orbit in its Mission Editor route
  margin = 30000, -- metres beyond every enemy reach the orbit holds
  retreat_margin = 50000, -- metres beyond the reach that came over the orbit, when it retreats
  seconds = 60, -- how often the threats are weighed
  advance_seconds = 1800, -- how long the way must be clear before the orbit moves closer, and between two advances
  min_advance = 30000, -- metres closer the new orbit must be for an advance to be worth it
  leg = 30, -- nautical miles of the racetrack, laid across the axis
  sam_reach_floor = 15000, -- metres: in a mission alone, a missile reaching less is no threat to an AWACS
  awacs_standoff = 100000, -- metres an AWACS holds from every threat's centre, whatever its reach (not the tankers)
}

veafSupport.settings = {}

--- By asset name: `{ station, groupId, lastMove, calmSince, marks }`.
veafSupport.state = {}

--- The campaign's hooks, nil in a mission alone.
veafSupport.threatSource = nil -- function(side) -> { { center = { x, z }, reach = metres, name = string } }
veafSupport.frontLimit = nil -- function(side, anchor, threat) -> metres from the threat the orbit never comes nearer
veafSupport.tell = nil -- function(side, text): who speaks

veafSupport.LINE_COLOR = { 0, 0.35, 1, 1 }
veafSupport.TEXT_FILL = { 0, 0, 0, 0 }
veafSupport.STEP = 1000
veafSupport.SEARCH = 400000

local function logger()
  return veaf.loggers.get(veafSupport.Id)
end

local function distance2d(a, b)
  local dx, dz = a.x - b.x, a.z - b.z
  return math.sqrt(dx * dx + dz * dz)
end

--- Set the module's settings, over its defaults.
--- @param settings table|nil the SUPPORT block of `mission.yaml`
function veafSupport.configure(settings)
  veafSupport.settings = settings or {}
end

--- A setting, or its default.
function veafSupport.setting(key)
  local value = veafSupport.settings[key]
  if value == nil then
    return veafSupport.DEFAULTS[key]
  end
  return value
end

--- The orbit an asset was given in the Mission Editor, `{ x, z }`, with the end of its leg when it has one.
function veafSupport.anchor(name)
  local data = veafMove and veafMove._getTankerRouteData and veafMove._getTankerRouteData(name)
  local point = data and data.point2
  if not point then
    return nil
  end
  local leg = data.point3 and { x = data.point3.x, z = data.point3.y } or nil
  return { x = point.x, z = point.y }, leg
end

--- In a mission alone: the enemy's ground units carrying a surface-to-air missile of `sam_reach_floor` or more.
--- @param side number the asset's coalition
--- @return table `{ { center, reach, name } }`
function veafSupport.missionThreats(side)
  local enemy = side == coalition.side.RED and coalition.side.BLUE or coalition.side.RED
  local floor = veafSupport.setting("sam_reach_floor")
  local threats = {}
  local ok, groups = pcall(coalition.getGroups, enemy, Group.Category.GROUND)
  for _, group in ipairs(ok and groups or {}) do
    for _, unit in ipairs(group.getUnits and group:getUnits() or {}) do
      local alive = unit and unit.isExist and unit:isExist() and (not unit.isActive or unit:isActive())
      local okAmmo, ammo = false, nil
      if alive and unit.getAmmo then
        okAmmo, ammo = pcall(unit.getAmmo, unit)
      end
      local reach = 0
      for _, item in ipairs(okAmmo and type(ammo) == "table" and ammo or {}) do
        local desc = item.desc
        if desc and desc.category == Weapon.Category.MISSILE and desc.rangeMaxAltMax then
          reach = math.max(reach, desc.rangeMaxAltMax)
        end
      end
      if reach >= floor then
        local point = unit:getPoint()
        table.insert(threats, { center = { x = point.x, z = point.z }, reach = reach, name = group:getName() })
      end
    end
  end
  return threats
end

--- The threats an asset of a side weighs: the campaign's when it gives them, else the mission's.
function veafSupport.threats(side)
  if veafSupport.threatSource then
    return veafSupport.threatSource(side)
  end
  return veafSupport.missionThreats(side)
end

--- The threat whose reach comes over a point, with a margin, or whose centre is nearer than `standoff`; nil when none.
--- @param standoff number|nil metres from every threat's centre, whatever its reach (an AWACS); nil or 0 for none
function veafSupport.threatOver(point, threats, margin, standoff)
  for _, threat in ipairs(threats) do
    local d = distance2d(point, threat.center)
    if d < threat.reach + margin or d < (standoff or 0) then
      return threat
    end
  end
  return nil
end

--- Where an asset holds: on the line from the threat nearest its Mission Editor orbit through that orbit, the first
--- point out of every threat plus `margin` (and, for an AWACS, `standoff` from every threat's centre), walking away
--- from the threat. It never comes nearer the threat than its orbit — in a campaign, than its side's front
--- (`frontLimit`) — and goes back beyond its orbit as far as needed.
--- @param side number the coalition
--- @param anchor table `{ x, z }` the Mission Editor orbit
--- @param threats table
--- @param margin number metres
--- @param standoff number|nil metres from every threat's centre (an AWACS); nil or 0 for none
--- @return table `{ x, z }`
--- @return table|nil the threat the axis points at
function veafSupport.station(side, anchor, threats, margin, standoff)
  local target, nearest = nil, nil
  for _, threat in ipairs(threats) do
    local d = distance2d(anchor, threat.center)
    if not nearest or d < nearest then
      target, nearest = threat, d
    end
  end
  if not target then
    return { x = anchor.x, z = anchor.z }, nil
  end
  local length = distance2d(target.center, anchor)
  if length == 0 then
    return { x = anchor.x, z = anchor.z }, target
  end
  local ux, uz = (anchor.x - target.center.x) / length, (anchor.z - target.center.z) / length
  local start = length
  if veafSupport.frontLimit then
    start = math.min(length, veafSupport.frontLimit(side, anchor, target) or length)
  end
  local d = math.max(0, start)
  while d <= length + veafSupport.SEARCH do
    local point = { x = target.center.x + ux * d, z = target.center.z + uz * d }
    if not veafSupport.threatOver(point, threats, margin, standoff) then
      return point, target
    end
    d = d + veafSupport.STEP
  end
  return { x = target.center.x + ux * d, z = target.center.z + uz * d }, target
end

--- Bearing (degrees, true) and range (nautical miles) of a point from a side's bullseye.
function veafSupport.fromBullseye(side, point)
  local ok, bullseye = pcall(coalition.getMainRefPoint, side)
  if not ok or type(bullseye) ~= "table" then
    return nil
  end
  local dx, dz = point.x - bullseye.x, point.z - bullseye.z
  local bearing = math.floor(math.deg(math.atan2(dz, dx)) + 360.5) % 360
  return bearing, math.floor(math.sqrt(dx * dx + dz * dz) / 1852 + 0.5)
end

--- Whether an asset is an AWACS (the DCS attribute of its first unit): it then holds `awacs_standoff` from every threat.
--- @param group table the asset's group
--- @return boolean
function veafSupport.isAwacs(group)
  local units = group.getUnits and group:getUnits() or {}
  local unit = units[1]
  if not (unit and unit.hasAttribute) then
    return false
  end
  local ok, value = pcall(unit.hasAttribute, unit, "AWACS")
  return ok and value == true
end

--- The frequency an asset is called on, MHz, from its group's data; nil when unknown.
local function frequencyOf(name)
  local data = veaf.getGroupData and veaf.getGroupData(name)
  local frequency = data and data.frequency
  return type(frequency) == "number" and frequency or nil
end

local function removeMarks(state)
  for _, id in ipairs(state.marks or {}) do
    trigger.action.removeMark(id)
  end
  state.marks = {}
end

--- Draw an asset's marks, for its side only: its leg and a label with its name and frequency.
--- @param state table the asset's state
--- @param name string
--- @param side number
--- @param from table `{ x, z }` the start of the leg
--- @param to table `{ x, z }` its end
function veafSupport.drawMarks(state, name, side, from, to)
  removeMarks(state)
  local frequency = frequencyOf(name)
  local label = frequency and string.format("%s %.2f", name, frequency) or name
  local lineId, textId = veaf.getUniqueIdentifier(), veaf.getUniqueIdentifier()
  trigger.action.lineToAll(side, lineId, { x = from.x, y = 0, z = from.z }, { x = to.x, y = 0, z = to.z }, veafSupport.LINE_COLOR, 1, true)
  trigger.action.textToAll(side, textId, { x = from.x, y = 0, z = from.z }, veafSupport.LINE_COLOR, veafSupport.TEXT_FILL, 14, true, label)
  state.marks = { lineId, textId }
end

--- The end of a leg `leg` nautical miles long from a point, on a heading in degrees.
local function legEnd(point, heading)
  local length = veafSupport.setting("leg") * 1852
  local radians = math.rad(heading)
  return { x = point.x + length * math.cos(radians), z = point.z + length * math.sin(radians) }
end

local function say(side, text)
  if veafSupport.tell then
    veafSupport.tell(side, text)
  else
    trigger.action.outTextForCoalition(side, text, 20)
  end
end

--- Move an asset's orbit, redraw its marks and tell its side.
--- @return boolean whether it moved
local function move(name, state, side, point, target, why, now)
  local heading = 90
  if target then
    heading = (math.deg(math.atan2(target.center.z - point.z, target.center.x - point.x)) + 90) % 360
  end
  local moved = veafMove.moveTanker({ x = point.x, y = 0, z = point.z }, name, nil, nil, heading, veafSupport.setting("leg"), false, true)
  if not moved then
    return false
  end
  local from = state.station or point
  state.station, state.lastMove, state.calmSince = point, now, nil
  veafSupport.drawMarks(state, name, side, point, legEnd(point, heading))
  local bearing, range = veafSupport.fromBullseye(side, point)
  -- where it holds now, so a check reads it rather than guesses it (2026-11-22: "the AWACS is on the red side")
  logger():info(
    "[%s] %s: orbit moved %d km (%s), orbit now %s, %s",
    name,
    why,
    math.floor(distance2d(from, point) / 1000),
    target and target.name or "no threat",
    bearing and string.format("%03d/%d NM from the bullseye", bearing, range) or "bullseye unknown",
    target and string.format("%d km from [%s]", math.floor(distance2d(point, target.center) / 1000 + 0.5), target.name) or "no threat"
  )
  if bearing then
    say(side, veaf.t("support." .. why, name, bearing, range))
  end
  return true
end

--- Weigh one asset: retreat at once when a threat reaches its orbit, advance only after a long calm and a big step.
--- @param name string
--- @param now number the mission time
function veafSupport.follow(name, now)
  local group = Group.getByName(name)
  if not (group and group.isExist and group:isExist()) then
    return
  end
  local anchor, anchorLeg = veafSupport.anchor(name)
  if not anchor then
    return
  end
  local side = group:getCoalition()
  local state = veafSupport.state[name] or {}
  veafSupport.state[name] = state
  -- first seen, or respawned (the assets menu, the shop: back on its Mission Editor orbit, its id unchanged):
  -- weighed again from that orbit
  if not state.seen or state.respawned then
    veafSupport.state[name] = { seen = true, marks = state.marks }
    state = veafSupport.state[name]
    veafSupport.drawMarks(state, name, side, anchor, anchorLeg or legEnd(anchor, 90))
  end
  local current = state.station or anchor
  local threats = veafSupport.threats(side)
  local standoff = veafSupport.isAwacs(group) and veafSupport.setting("awacs_standoff") or 0
  if veafSupport.threatOver(current, threats, veafSupport.setting("margin"), standoff) then
    -- in danger: out at once, and well out
    local point, target = veafSupport.station(side, anchor, threats, veafSupport.setting("retreat_margin"), standoff)
    if distance2d(point, current) > veafSupport.STEP then
      move(name, state, side, point, target, "retreat", now)
    end
    return
  end
  local candidate, target = veafSupport.station(side, anchor, threats, veafSupport.setting("margin"), standoff)
  local gain
  if target then
    gain = distance2d(current, target.center) - distance2d(candidate, target.center)
  else
    gain = distance2d(current, candidate)
  end
  if gain < veafSupport.setting("min_advance") then
    state.calmSince = nil
    return
  end
  state.calmSince = state.calmSince or now
  local waited = now - state.calmSince >= veafSupport.setting("advance_seconds")
  local rested = not state.lastMove or now - state.lastMove >= veafSupport.setting("advance_seconds")
  if waited and rested then
    move(name, state, side, candidate, target, "advance", now)
  end
end

--- The birth of a unit: an asset's group born again is a respawn. DCS keeps the Mission Editor's group id on a
--- respawn (`VeafGroupSpawn:respawn`, measured in game), so the id cannot tell it; the birth of its units does.
--- @param event table the event as `veafEventHandler` hands it
function veafSupport.onBirth(event)
  local unit = event and event.dcsInitiator
  local group = unit and unit.getGroup and unit:getGroup()
  local name = group and group.getName and group:getName()
  local state = name and veafSupport.state[name]
  if state then
    state.respawned = true
  end
end

--- One pass over every asset.
function veafSupport.beat()
  local now = timer.getTime()
  for _, name in ipairs(veafSupport.setting("assets") or {}) do
    local ok, problem = pcall(veafSupport.follow, name, now)
    if not ok then
      logger():error("[%s] could not be weighed: %s", tostring(name), tostring(problem))
    end
  end
end

function veafSupport.initialize()
  logger():info("Initializing module")
  veafSupport.state = {}
  if not (veafMove and veafMove.moveTanker) then
    logger():error("veafMove is needed to move an orbit: the SUPPORT module does nothing")
    return false
  end
  if veafEventHandler and veafEventHandler.addCallback then
    veafEventHandler.addCallback("veafSupport.onBirth", { "S_EVENT_BIRTH" }, veafSupport.onBirth)
  end
  veafSupport.beat()
  veafSupport.loopId =
    veafScheduler.scheduleFunction(veafSupport.beat, nil, timer.getTime() + veafSupport.setting("seconds"), veafSupport.setting("seconds"))
  return true
end

veaf.loggers.get(veafSupport.Id):info(veaf.loggers.get(veafSupport.Id):getVersionInfo())

veaf.registerModule(veafSupport.Id, veafSupport.initialize, { enable = true }, 165)
