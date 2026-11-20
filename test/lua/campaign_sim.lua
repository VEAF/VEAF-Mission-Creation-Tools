--- The campaign economy simulator (FIX-CAMPAIGN-ECONOMY-BALANCE 04), after Iron Gall's pacing report.
---
--- It runs the **real** campaign Lua — `veafCampaign`, `veafCampaignLogistics`, `veafCampaignOps`,
--- `veafCampaignEconomy` — headless on the DCS mocks of `test/lua/`, on a real campaign's data, and advances time
--- beat by beat through the campaign's own scheduler. Combat is not simulated: what a team of virtual players does
--- is drawn from rates (`RATES`, each with its source) and handed to the campaign through the entry points the game
--- uses — a DCS kill event, an ejection, a landing, a CSAR delivery, a unit lost by a garrison, troops holding a
--- neutral zone, a purchase from the shop. The red AI plays with its real decision code: production, CAP and
--- strikes, supply helicopters, assault convoys, reinforcements at spawn price.
---
--- What the mocks cannot run is modelled in a small world (`World`): the groups the campaign spawns — flights,
--- helicopters, convoys — are mock groups that fly or drive in a straight line to where they were sent, and live
--- `AIR_LIFETIME` seconds for a flight. Nothing shoots at the players' zones: red's flights and convoys do no damage.
---
--- Not a test: `test_campaignEconomySim.lua` keeps its bounds, `campaign_sim_report.lua` prints its report.
---
---   local sim = dofile("test/lua/campaign_sim.lua")
---   local run = sim.run({ player = "average", strategy = "cheapest", seed = 1, hours = 9 })

local _base = debug.getinfo(1, "S").source:match("^@(.+)[\\/]") or "."
local sim = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- What the virtual players do
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- An average pilot's rates, per hour of play, and their sources. The server logs of 2026-11-17 and 2026-11-19 give:
--- about 10 pilots for about 3 hours an evening, 51 red units destroyed on 11-17, 2 captures an evening, about
--- 2,000 credits earned an evening with the rewards of then (`OLD_REWARDS`). What they do not give is an estimate,
--- said so, and set so that the old rewards make those 2,000 credits (`campaign_sim_report.lua calibrate`).
sim.RATES = {
  -- 51 red units destroyed on 2026-11-17 by about 10 pilots in about 3 hours, the captures' assaults included: they
  -- empty a zone of about 15 units twice an evening, which leaves 1.2 an hour each outside them
  ground_kills = 1.2,
  air_kills = 0.1, -- estimate: 3 red aircraft an evening, among the flights red has up
  building_kills = 0.03, -- estimate: about one building of a red factory or depot an evening
  deliveries = 0.1, -- estimate: 3 supply crates an evening
  deaths = 0.15, -- estimate: 4 to 5 ejections or deaths an evening
  rescue_share = 0.25, -- estimate: one downed pilot in four brought back to a MASH
  captures_per_evening = 2, -- 2026-11-17 and 2026-11-19: 2 zones taken an evening, troops landed once one is empty
  sortie_minutes = 60, -- estimate: a sortie lands, and banks its held credits, after an hour
}

--- The rewards of before FIX-CAMPAIGN-ECONOMY-BALANCE, which the 2,000 credits an evening were earned with.
sim.OLD_REWARDS = { kill_sam = 10, kill_air = 30, kill_building = 0, rescue = 0, demolition = 50 }

--- The virtual players: a team of `pilots`, its rates multiplied by `skill`, its deaths divided by it.
sim.PLAYERS = {
  occasional = { pilots = 6, skill = 0.6 },
  average = { pilots = 10, skill = 1.0 },
  expert = { pilots = 10, skill = 1.6 },
}

--- The shop strategies: `never` buys nothing; `cheapest` buys, as soon as it can, the cheapest item it has not bought
--- yet, until it has bought each once; `hawk` and `patriot` save for that upgrade, then buy as `cheapest`.
sim.STRATEGIES = { "never", "cheapest", "hawk", "patriot" }

--- An evening, in hours of play: what `captures_per_evening` counts over.
sim.EVENING_HOURS = 3

--- How long a flight the campaign spawns stays in the air, in seconds, before it lands and leaves the world.
sim.AIR_LIFETIME = 3600

--- How fast a helicopter flies, in metres a second.
sim.HELICOPTER_SPEED = 55

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Loading the real modules on the mocks
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local loaded = false

--- Load the mocks and the campaign modules once, the way the campaign tests do.
function sim.loadModules()
  if loaded then
    return
  end
  luaunit = luaunit or dofile(_base .. "/luaunit.lua")
  dofile(_base .. "/dcs_mocks.lua")
  local src = _base .. "/../../src/scripts/veaf"
  for _, name in ipairs({
    "veaf",
    "veafI18n",
    "veafScheduler",
    "veafMath",
    "veafGeo",
    "veafMissionDb",
    "veafDcsSpawner",
    "dcsUnits",
    "veafUnits",
    "veafCasMission",
    "veafEventHandler",
    "veafRadio",
    "veafNamedPoints",
  }) do
    dofile(src .. "/" .. name .. ".lua")
  end
  -- the groups a garrison or an upgrade names, as the build writes them for a mission (`campaign-sim fixtures`)
  dofile(_base .. "/fixtures/veaf-spawn-data.lua")
  veafAircraftSpawn = veafAircraftSpawn or { roles = {} }
  for _, name in ipairs({ "veafCampaign", "veafCampaignOps", "veafCampaignEconomy", "veafCampaignLogistics" }) do
    dofile(src .. "/" .. name .. ".lua")
  end
  loaded = true
end

--- The campaign data of a fixture: `{ data, airbases = { [name] = { lat, lon } } }`, written by
--- `veaf_build/campaign_sim.py` from a campaign's `campaign-data.yaml`.
function sim.fixture(name)
  return dofile(_base .. "/fixtures/" .. (name or "oronte-campaign-data") .. ".lua")
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- A seeded random draw of the simulator's own, apart from the campaign's
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function newRandom(seed)
  local state = (seed * 7919 + 1) % 2147483647
  return function()
    state = (state * 16807) % 2147483647
    return state / 2147483647
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The world: the groups the campaign spawns, flying or driving where they were sent
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local World = {}
World.__index = World

local function distance2d(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

function World.new()
  return setmetatable({ groups = {}, units = {}, serial = 0 }, World)
end

--- Put a group in the world. `spec`: `{ name, side, category, types, from, to, speed, airborneAfter, lifetime }`; a
--- group with `to` moves there in a straight line at `speed`, in the air while it moves when it is an aircraft.
function World:addGroup(spec)
  local world, now = self, timer.getTime()
  local group = { name = spec.name, spec = spec, units = {}, bornAt = now }
  local function position()
    local from, to = spec.from, spec.to or spec.from
    local length = distance2d(from, to)
    local travelled = math.max(0, timer.getTime() - now - (spec.airborneAfter or 0)) * (spec.speed or 0)
    if length == 0 or travelled >= length then
      return { x = to.x, y = 0, z = to.z }, true
    end
    local share = travelled / length
    return { x = from.x + (to.x - from.x) * share, y = 0, z = from.z + (to.z - from.z) * share }, false
  end
  for index, typeName in ipairs(spec.types) do
    local unitName = spec.name .. " #" .. index
    local unit = {
      _attributes = spec.attributes and spec.attributes(typeName) or {},
      _categoryEx = spec.category,
      alive = true,
    }
    unit.isExist = function()
      return unit.alive and world.groups[spec.name] == group
    end
    unit.getLife = function()
      return unit.alive and 1 or 0
    end
    unit.getLife0 = function()
      return 1
    end
    unit.getPoint = function()
      return (position())
    end
    unit.inAir = function()
      if spec.category ~= Unit.Category.AIRPLANE and spec.category ~= Unit.Category.HELICOPTER then
        return false
      end
      if spec.category == Unit.Category.AIRPLANE then
        return true
      end
      local _, arrived = position()
      return timer.getTime() - now >= (spec.airborneAfter or 0) and not arrived
    end
    unit.getTypeName = function()
      return typeName
    end
    unit.getCoalition = function()
      return spec.side
    end
    unit.getDesc = function()
      return { category = spec.category, typeName = typeName, attributes = unit._attributes }
    end
    unit.getCategory = function()
      return Object.Category.UNIT
    end
    unit.getPlayerName = function()
      return nil
    end
    unit.getGroup = function()
      return group.dcs
    end
    unit.getVelocity = function()
      return { x = 0, y = 0, z = 0 }
    end
    dcs_mocks.addUnit(unitName, unit)
    world.units[unitName] = unit
    table.insert(group.units, unit)
  end
  local dcs = {
    isExist = function()
      return world.groups[spec.name] == group
    end,
    getUnits = function()
      local live = {}
      for _, unit in ipairs(group.units) do
        if unit.alive then
          table.insert(live, unit)
        end
      end
      return live
    end,
    getSize = function()
      local count = 0
      for _, unit in ipairs(group.units) do
        count = count + (unit.alive and 1 or 0)
      end
      return count
    end,
    getUnit = function(_, index)
      return group.units[index]
    end,
    getCoalition = function()
      return spec.side
    end,
    getCategory = function()
      return spec.category == Unit.Category.AIRPLANE and Group.Category.AIRPLANE
        or spec.category == Unit.Category.HELICOPTER and Group.Category.HELICOPTER
        or Group.Category.GROUND
    end,
    destroy = function()
      world:removeGroup(spec.name)
    end,
  }
  dcs_mocks.addGroup(spec.name, dcs)
  group.dcs = Group.getByName(spec.name)
  self.groups[spec.name] = group
  return spec.name
end

function World:removeGroup(name)
  local group = self.groups[name]
  if not group then
    return
  end
  self.groups[name] = nil
  for index, unit in ipairs(group.units) do
    unit.alive = false
    self.units[name .. " #" .. index] = nil
    dcs_mocks.removeUnit(name .. " #" .. index)
  end
  dcs_mocks.removeGroup(name)
end

--- Flights whose time is up land and leave the world.
function World:land()
  local now = timer.getTime()
  for name, group in pairs(self.groups) do
    if group.spec.lifetime and now - group.bornAt >= group.spec.lifetime then
      self:removeGroup(name)
    end
  end
end

--- `world.searchObjects` over the world's units: the units of a sphere.
function World:search(category, volume, handler)
  if category ~= Object.Category.UNIT then
    return
  end
  local center, radius = volume.params.point, volume.params.radius
  for _, group in pairs(self.groups) do
    for _, unit in ipairs(group.units) do
      if unit.alive and distance2d(unit.getPoint(), center) <= radius then
        if handler(unit) == false then
          return
        end
      end
    end
  end
end

--- The live aircraft of a side in the world.
function World:aircraftOf(side)
  local found, names = {}, {}
  for name in pairs(self.groups) do
    table.insert(names, name)
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local group = self.groups[name]
    local category = group.spec.category
    if group.spec.side == side and (category == Unit.Category.AIRPLANE or category == Unit.Category.HELICOPTER) then
      for _, unit in ipairs(group.units) do
        if unit.alive then
          table.insert(found, { group = group, unit = unit })
        end
      end
    end
  end
  return found
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Setting up a run
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A projection of lat/lon to the map's metres around the theatre's middle: what the distances need, no more.
local function projection(lat0, lon0)
  local radius = 6371000
  return function(lat, lon)
    return {
      x = math.rad(lat - lat0) * radius,
      y = 0,
      z = math.rad(lon - lon0) * radius * math.cos(math.rad(lat0)),
    }
  end
end

local function deepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, item in pairs(value) do
    copy[key] = deepCopy(item)
  end
  return copy
end

local function attributesOf(typeName)
  local attributes = {}
  if veafCampaign.reserveCategory(typeName) == "air_defense" then
    attributes["SAM related"] = true
  end
  return attributes
end

--- Install the mocks a run needs over the bare DCS mocks.
local function installWorld(run, fixture)
  dcs_mocks.reset()
  -- the campaign's own draws: the mocks' generator, fed a sequence of the run's seed (Lua's own would raise on
  -- the empty intervals `veafUnits.placeGroup` asks for on a small cell, which the mocks' tolerate)
  local campaignRandom, sequence = newRandom(run.seed + 1000), {}
  for index = 1, 997 do
    sequence[index] = campaignRandom()
  end
  dcs_mocks.setRandomSequence(sequence)
  veaf.config.language = "en"
  veafEventHandler.callbacks = {}
  veafCampaign.listeners = {}
  veafCampaign.saveParts = {}
  veafRemote = veafRemote or {}
  veafRemote.getRemoteUserFromUnit = veafRemote.getRemoteUserFromUnit or function()
    return nil
  end
  local lat0, lon0 = 36.0, 36.5
  coord.LLtoLO = projection(lat0, lon0)
  land.getSurfaceType = function()
    return land.SurfaceType.LAND
  end
  land.getHeight = function()
    return 0
  end
  veafCampaign.fileSystem = function()
    return nil, nil, nil
  end
  local airbases = {}
  for name, position in pairs(fixture.airbases) do
    local base = { side = coalition.side.NEUTRAL }
    base.object = {
      getID = function()
        return 1
      end,
      getName = function()
        return name
      end,
      getPoint = function()
        return coord.LLtoLO(position.lat, position.lon)
      end,
      getCoalition = function()
        return base.side
      end,
      setCoalition = function(_, side)
        base.side = side
      end,
      autoCapture = function() end,
      getDesc = function()
        return { category = Airbase.Category.AIRDROME }
      end,
      getWarehouse = function()
        return nil
      end,
    }
    airbases[name] = base
  end
  Airbase.getByName = function(name)
    return airbases[name] and airbases[name].object or nil
  end
  local world = World.new()
  run.world = world
  _G.world.searchObjects = function(category, volume, handler)
    world:search(category, volume, handler)
  end
  -- the flights: in the air at once, for `AIR_LIFETIME`
  local function spawnAircraft(category)
    return function(groupData)
      local types, first = {}, groupData.units[1] or {}
      for _, unit in ipairs(groupData.units or {}) do
        table.insert(types, unit.type)
      end
      local side = veaf.getCoalitionForCountry and veaf.getCoalitionForCountry(groupData.country)
      side = side or (groupData.country == veaf.getCountryForCoalition(coalition.side.BLUE) and coalition.side.BLUE or coalition.side.RED)
      return world:addGroup({
        name = groupData.name,
        side = side,
        category = category,
        types = types,
        from = { x = first.x or 0, z = first.y or 0 },
        lifetime = sim.AIR_LIFETIME,
      })
    end
  end
  veafAircraftSpawn.spawnAirplaneGroup = spawnAircraft(Unit.Category.AIRPLANE)
  -- a helicopter flies to its destination and lands there; it leaves the world when the campaign destroys it
  veafAircraftSpawn.spawnHelicopterGroup = function(groupData, job)
    local first = groupData.units[1] or {}
    local types = {}
    for _, unit in ipairs(groupData.units or {}) do
      table.insert(types, unit.type)
    end
    local destination = job and job.destination and veafNamedPoints.getPoint(job.destination)
    local from = { x = first.x or 0, z = first.y or 0 }
    local side = groupData.country == veaf.getCountryForCoalition(coalition.side.BLUE) and coalition.side.BLUE or coalition.side.RED
    return world:addGroup({
      name = groupData.name,
      side = side,
      category = Unit.Category.HELICOPTER,
      types = types,
      from = from,
      to = destination and { x = destination.x, z = destination.z } or from,
      speed = sim.HELICOPTER_SPEED,
      airborneAfter = 60,
    })
  end
  -- veafSpawn: an assault convoy drives to its destination; every other spawn is accepted and does nothing
  local accepted = function()
    return "sim spawn"
  end
  veafSpawn = {
    spawnedConvoys = {},
    capTargetFilters = {},
    spawnAFAC = accepted,
    spawnIlluminationFlare = accepted,
    spawnSmoke = accepted,
    convertLaserToFreq = function()
      return 30
    end,
  }
  veafSpawn.spawnConvoy = function(spot, name, _, _, _, side, _, _, speed, _, _, destination, _, trucks, _, _, _, _, armor)
    local types = {}
    for _, typeName in ipairs(armor or {}) do
      table.insert(types, type(typeName) == "table" and (typeName.type or typeName[1]) or typeName)
    end
    for _ = 1, trucks or 0 do
      table.insert(types, "Ural-375")
    end
    local target = destination and veafNamedPoints.getPoint(destination)
    return world:addGroup({
      name = name,
      side = side,
      category = Unit.Category.GROUND_UNIT,
      types = types,
      attributes = attributesOf,
      from = { x = spot.x, z = spot.z },
      to = target and { x = target.x, z = target.z } or { x = spot.x, z = spot.z },
      speed = (speed or 40) / 3.6,
    })
  end
  -- a CSAR module whose deliveries the economy watches (`watchRescues`); the simulator fills its registry
  csar = {
    inTransitGroups = {},
    rescuePilots = function(heli)
      csar.inTransitGroups[heli:getName()] = nil
    end,
  }
  -- the virtual pilots sit high over the players' rear airfield: in a slot, far from waking any zone
  coalition.getPlayers = function(side)
    if side ~= coalition.side.BLUE then
      return {}
    end
    return run.pilotUnits
  end
end

--- A virtual pilot's aircraft, as DCS hands it to an event.
local function pilotUnit(name, point)
  local unit = {}
  unit.getName = function()
    return name
  end
  unit.getPlayerName = function()
    return name
  end
  unit.getCoalition = function()
    return coalition.side.BLUE
  end
  unit.getPoint = function()
    return { x = point.x, y = 8000, z = point.z }
  end
  unit.isExist = function()
    return true
  end
  unit.inAir = function()
    return true
  end
  unit.getLife = function()
    return 1
  end
  unit.getTypeName = function()
    return "F-16C_50"
  end
  unit.getDesc = function()
    return { category = Unit.Category.AIRPLANE }
  end
  unit.getCategoryEx = function()
    return Unit.Category.AIRPLANE
  end
  unit.hasAttribute = function()
    return false
  end
  unit.getGroup = function()
    return {
      getID = function()
        return 1
      end,
      getName = function()
        return name
      end,
    }
  end
  return unit
end

--- Hand a DCS event to the campaign, through the event handler every module listens to.
local function dispatch(id, initiator, target, place)
  veafEventHandler.eventHandler:onEvent({ id = id, time = timer.getTime(), initiator = initiator, target = target, place = place })
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The players' war, drawn from the rates
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function zonesOf(side)
  local zones = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side then
      table.insert(zones, zone)
    end
  end
  return zones
end

--- The zones of `side` next to a zone of the players.
local function frontZones(side)
  local front = {}
  for _, zone in ipairs(zonesOf(side)) do
    for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
      if neighbour.entry.owner == "blue" then
        table.insert(front, zone)
        break
      end
    end
  end
  return front
end

local function liveUnits(zone)
  local live = {}
  for groupIndex, group in ipairs(zone.entry.garrison or {}) do
    for unitIndex, unit in ipairs(group.units) do
      if unit.alive then
        table.insert(live, { group = groupIndex, unit = unit, index = unitIndex })
      end
    end
  end
  return live
end

--- The red zone the team attacks: the front zone with the fewest units left, a neutral zone first once one is
--- empty and waits for its troops.
local function objective(run)
  local best, bestCount = nil, nil
  for _, zone in ipairs(frontZones("red")) do
    local count = #liveUnits(zone)
    if not bestCount or count < bestCount then
      best, bestCount = zone, count
    end
  end
  run.objective = best
  return best
end

--- Draw how many times something with this hourly rate happens in one beat.
local function draws(run, perHour)
  local expected = perHour * veafCampaign.BEAT_SECONDS / 3600
  local count = 0
  while expected > 0 do
    if run.random() < math.min(1, expected) then
      count = count + 1
    end
    expected = expected - 1
  end
  return count
end

local function anyPilot(run)
  return run.pilots[math.floor(run.random() * #run.pilots) + 1]
end

--- Destroy one unit of a zone's garrison: the kill event a pilot's weapon makes, then the loss the garrison records.
local function killUnit(run, zone, victim)
  run.serial = run.serial + 1
  local name = "sim target " .. run.serial
  dcs_mocks.addUnit(name, {
    _attributes = attributesOf(victim.unit.type),
    _categoryEx = Unit.Category.GROUND_UNIT,
    getTypeName = function()
      return victim.unit.type
    end,
    getCoalition = function()
      return coalition.side.RED
    end,
    getLife = function()
      return 0
    end,
  })
  dispatch(world.event.S_EVENT_KILL, anyPilot(run).unit, Unit.getByName(name))
  dcs_mocks.removeUnit(name)
  zone:onUnitLost(victim.group, victim.index)
  run.counts.groundKills = run.counts.groundKills + 1
  if zone.entry.owner ~= "red" then
    run.objective = nil
  end
end

local function groundKill(run)
  local zone = run.objective or objective(run)
  local live = zone and liveUnits(zone) or {}
  if #live > 0 then
    killUnit(run, zone, live[math.floor(run.random() * #live) + 1])
  end
end

local function airKill(run)
  local aircraft = run.world:aircraftOf(coalition.side.RED)
  if #aircraft == 0 then
    return
  end
  local victim = aircraft[math.floor(run.random() * #aircraft) + 1]
  dispatch(world.event.S_EVENT_KILL, anyPilot(run).unit, victim.unit)
  victim.unit.alive = false
  dispatch(world.event.S_EVENT_DEAD, victim.unit)
  run.counts.airKills = run.counts.airKills + 1
end

local function buildingKill(run)
  for _, zone in ipairs(zonesOf("red")) do
    for index, structure in ipairs(zone.entry.structures or {}) do
      if structure.alive then
        local name = veafCampaign.structureName(zone, index)
        local static = {
          getName = function()
            return name
          end,
        }
        dispatch(world.event.S_EVENT_KILL, anyPilot(run).unit, static)
        veafCampaign.onUnitDead({ initiator = { unitName = name } })
        run.counts.buildingKills = run.counts.buildingKills + 1
        return
      end
    end
  end
end

--- A pilot's sortie: it lands at the players' airfield and banks what it holds.
local function land(run, pilot)
  dispatch(world.event.S_EVENT_LAND, pilot.unit, nil, Airbase.getByName(run.home))
  pilot.sortieEnds = timer.getTime() + sim.RATES.sortie_minutes * 60
end

local function death(run)
  local pilot = anyPilot(run)
  dispatch(world.event.S_EVENT_EJECTION, pilot.unit)
  run.counts.deaths = run.counts.deaths + 1
  pilot.sortieEnds = timer.getTime() + sim.RATES.sortie_minutes * 60
  if run.random() < sim.RATES.rescue_share then
    local rescuer = anyPilot(run)
    csar.inTransitGroups[rescuer.name] = { ["Downed " .. run.counts.deaths] = {} }
    csar.rescuePilots(rescuer.unit)
    run.counts.rescues = run.counts.rescues + 1
  end
end

--- A neutral zone next to the players' zones that their troops do not hold yet.
local function neutralToTake(run)
  for _, zone in ipairs(zonesOf("neutral")) do
    local held = false
    for _, zoneName in pairs(run.troops) do
      held = held or zoneName == zone.name
    end
    for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
      if neighbour.entry.owner == "blue" and not held then
        return zone
      end
    end
  end
  return nil
end

--- A capture, `captures_per_evening` times an evening: the team empties the zone it attacks (each unit a kill) unless
--- a neutral zone waits, and lands troops there; the campaign's own clock takes the zone. The troops leave once it
--- is taken.
local function captures(run)
  for name, zoneName in pairs(run.troops) do
    if veafCampaign.zones[zoneName].entry.owner ~= "neutral" then
      run.world:removeGroup(name)
      run.troops[name] = nil
      run.counts.captures = run.counts.captures + 1
    end
  end
  for _ = 1, draws(run, sim.RATES.captures_per_evening / sim.EVENING_HOURS) do
    local zone = neutralToTake(run)
    if not zone then
      local target = run.objective or objective(run)
      for _, victim in ipairs(target and liveUnits(target) or {}) do
        killUnit(run, target, victim)
      end
      zone = neutralToTake(run)
    end
    if zone then
      run.serial = run.serial + 1
      local name = "sim troops " .. run.serial
      local center = zone:getCenter()
      run.world:addGroup({
        name = name,
        side = coalition.side.BLUE,
        category = Unit.Category.GROUND_UNIT,
        types = { "Soldier M4", "Soldier M4", "Soldier M4", "Soldier M4" },
        from = { x = center.x, z = center.z },
      })
      run.troops[name] = zone.name
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The shop strategies
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What the shop offers the simulator: its items but the escort (it needs a player's group) and the tanker (an
--- asset of the mission), and the upgrades of the campaign's era. `{ id, price, buy }`.
local function offers(run)
  local list = {}
  local enemy = run.objective or objective(run)
  -- the players' zone an upgrade goes on: the one with the fewest bought, the front first
  local own, ownScore = nil, nil
  for _, zone in ipairs(zonesOf("blue")) do
    if zone.entry.garrison then
      local front = false
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        front = front or neighbour.entry.owner ~= "blue"
      end
      local score = #zone:upgrades() * 2 + (front and 0 or 1)
      if not ownScore or score < ownScore then
        own, ownScore = zone, score
      end
    end
  end
  local neutral = zonesOf("neutral")[1]
  local targets = { enemy = enemy, own = own, neutral = neutral, any = enemy }
  for _, item in ipairs(veafCampaignEconomy.ITEMS) do
    if item.id ~= "escort" and item.id ~= "tanker" then
      local zone = item.zones and targets[item.zones]
      if not item.zones or zone then
        table.insert(list, {
          id = item.id,
          price = veafCampaignEconomy.price(item.id),
          buy = function()
            return veafCampaignEconomy.buy({ item.id, zone and zone.name })
          end,
        })
      end
    end
  end
  for _, upgrade in ipairs(veafCampaignEconomy.availableUpgrades()) do
    local price = own and veafCampaignEconomy.upgradePrice(upgrade.id)
    if price then
      table.insert(list, {
        id = "upgrade " .. upgrade.id,
        price = price,
        buy = function()
          return veafCampaignEconomy.buyUpgrade({ upgrade.id, own.name })
        end,
      })
    end
  end
  table.sort(list, function(a, b)
    if a.price ~= b.price then
      return a.price < b.price
    end
    return a.id < b.id
  end)
  return list
end

local function hours()
  return timer.getTime() / 3600
end

local function tryBuy(run, offer)
  if veafCampaignEconomy.credits < offer.price then
    return false
  end
  if offer.buy() then
    run.firstPurchase[offer.id] = run.firstPurchase[offer.id] or hours()
    run.purchases[offer.id] = (run.purchases[offer.id] or 0) + 1
    return true
  end
  run.refused[offer.id] = (run.refused[offer.id] or 0) + 1
  return false
end

local function shop(run)
  if run.strategy == "never" then
    return
  end
  local list = offers(run)
  local target = (run.strategy == "hawk" or run.strategy == "patriot") and ("upgrade " .. run.strategy) or nil
  if target and not run.firstPurchase[target] then
    for _, offer in ipairs(list) do
      if offer.id == target then
        tryBuy(run, offer)
      end
    end
    return
  end
  for _, offer in ipairs(list) do
    if not run.firstPurchase[offer.id] and (run.refused[offer.id] or 0) < 3 then
      tryBuy(run, offer)
      return -- the cheapest not bought yet, or wait for it
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- A run
-------------------------------------------------------------------------------------------------------------------------------------------------------------

local function ledgerTotals(account)
  local ledger = veafCampaignEconomy.ledger
  local books = ledger and ledger[account]
  local earned, spent = 0, 0
  for _, entry in pairs(books and books.earned or {}) do
    earned = earned + entry.amount
  end
  for _, entry in pairs(books and books.spent or {}) do
    spent = spent + entry.amount
  end
  return earned, spent
end

--- Play one team, one strategy, one seed, for `hours` of play.
--- @param options table `{ player, strategy, seed, hours, rewards, fixture }`; `rewards` overrides `economy` settings
--- @return table `{ rows = { hourly }, firstPurchase, purchases, refused, counts, redDry = { sead, raid } }`
function sim.run(options)
  sim.loadModules()
  local player = sim.PLAYERS[options.player or "average"]
  local run = {
    seed = options.seed or 1,
    strategy = options.strategy or "cheapest",
    random = newRandom(options.seed or 1),
    firstPurchase = {},
    purchases = {},
    refused = {},
    rows = {},
    troops = {},
    serial = 0,
    counts = { groundKills = 0, airKills = 0, buildingKills = 0, deaths = 0, rescues = 0, captures = 0 },
    redDry = {},
  }
  local fixture = sim.fixture(options.fixture)
  installWorld(run, fixture)
  local data = deepCopy(fixture.data)
  data.dynamic = data.dynamic or {}
  data.dynamic.economy = data.dynamic.economy or {}
  for key, value in pairs(options.rewards or {}) do
    data.dynamic.economy[key] = value
  end
  veafCampaign.data = data
  veafCampaign.initialize()
  -- the players' rear airfield, where the pilots sit and land
  local home
  for _, zone in ipairs(zonesOf("blue")) do
    if zone.entry.airbase and not home then
      home = zone
    end
  end
  run.home = home.entry.airbase
  run.pilots, run.pilotUnits = {}, {}
  for index = 1, player.pilots do
    local name = "Pilot " .. index
    local pilot = { name = name, unit = pilotUnit(name, home:getCenter()), sortieEnds = index * 300 }
    table.insert(run.pilots, pilot)
    table.insert(run.pilotUnits, pilot.unit)
  end
  local perPilots = player.pilots * player.skill
  local total = (options.hours or 9) * 3600
  local before = { credits = 0, creditsSpent = 0, red = 0, redSpent = 0 }
  local lastHour = 0
  for now = veafCampaign.BEAT_SECONDS, total, veafCampaign.BEAT_SECONDS do
    dcs_mocks.currentTime = now
    run.world:land()
    dcs_mocks.runScheduled(now)
    if veafCampaignEconomy.ledger and not veafCampaign.over then
      for _ = 1, draws(run, sim.RATES.ground_kills * perPilots) do
        groundKill(run)
      end
      for _ = 1, draws(run, sim.RATES.air_kills * perPilots) do
        airKill(run)
      end
      for _ = 1, draws(run, sim.RATES.building_kills * perPilots) do
        buildingKill(run)
      end
      for _ = 1, draws(run, sim.RATES.deliveries * perPilots) do
        local zone = zonesOf("blue")[1]
        veafCampaign.notify("delivered", zone, "blue", "crate")
      end
      for _ = 1, draws(run, sim.RATES.deaths * player.pilots / player.skill) do
        death(run)
      end
      for _, pilot in ipairs(run.pilots) do
        if now >= pilot.sortieEnds then
          land(run, pilot)
        end
      end
      captures(run)
      shop(run)
    end
    for _, kind in ipairs({ "sead", "raid" }) do
      local price = kind == "sead" and veafCampaignOps.flightPrice("red", "sead") or veafCampaignOps.raidPrice("red", true)
      if not run.redDry[kind] and price > 0 and not veafCampaign.canPay("red", price) then
        run.redDry[kind] = now / 3600
      end
    end
    local hour = math.floor(now / 3600)
    if hour > lastHour then
      lastHour = hour
      local earned, spent = ledgerTotals("credits")
      local redEarned, redSpent = ledgerTotals("red")
      table.insert(run.rows, {
        hour = hour,
        credits = veafCampaignEconomy.credits,
        earned = earned - before.credits,
        spent = spent - before.creditsSpent,
        red = veafCampaignLogistics.stock("red"),
        redEarned = redEarned - before.red,
        redSpent = redSpent - before.redSpent,
        blue = veafCampaignLogistics.stock("blue"),
        captures = run.counts.captures,
        groundKills = run.counts.groundKills,
      })
      before = { credits = earned, creditsSpent = spent, red = redEarned, redSpent = redSpent }
    end
  end
  run.ledger = veafCampaignEconomy.ledger
  run.world = nil
  return run
end

return sim
