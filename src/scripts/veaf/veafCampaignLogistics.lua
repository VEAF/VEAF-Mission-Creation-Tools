------------------------------------------------------------------
-- VEAF persistent campaign: resources, supply network, paid spawns, sappers, warehouses
-- By Zip (2026)
--
-- Features (FEAT-DYNAMIC-CAMPAIGN V1.5, tickets 12 to 16):
-- ---------
-- * Resources for the AI: one stock of points per side, made by a background production and by the
--   side's factories; everything the AI puts into play is paid from it.
-- * The supply network: factories feed the side's zones hop by hop along the connections, a segment
--   touching a depot at half time; a damaged zone is reinforced after its delay, paid from the stock.
-- * VEAF spawn commands paid: in credits for the players' side, from the resources for the other.
-- * Demolition teams: CTLD 2 sappers who blow up an enemy factory's buildings.
-- * Weapon stocks per warehouse: restored after a restart, moved by players from one airfield to another.
--
-- Runs inside veafCampaign's single loop, and only in a persistent campaign.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafCampaignLogistics = {}

--- Identifier. All output in DCS.log will start with this.
veafCampaignLogistics.Id = "CAMPAIGNLOG"

-- trace level, specific to this module
--veafCampaignLogistics.LogLevel = "trace"
veaf.loggers.new(veafCampaignLogistics.Id, veafCampaignLogistics.LogLevel)

--- Whether the resources are counted: a persistent campaign with `resources.enabled`.
veafCampaignLogistics.active = false

--- What each VEAF spawn command costs, in credits or points, when `economy.spawn_prices` does not say
--- (ticket 14). A command not listed puts no unit into play, and is free.
veafCampaignLogistics.SPAWN_PRICES = {
  unit = 100,
  group = 150,
  infantryGroup = 50,
  armoredPlatoon = 150,
  airDefenseBattery = 250,
  transportCompany = 100,
  fullCombatGroup = 400,
  convoy = 300,
  cap = 400,
  afac = 300,
  awacs = 500,
  escort = 400,
  farp = 200,
  fob = 300,
  cargo = 50,
  logistic = 100,
}

--- How near the buildings' row the sappers plant their charges, in metres.
veafCampaignLogistics.PLANT_DISTANCE = 200

--- The least power of a sapper's charge; a building with more life gets as much as its life.
veafCampaignLogistics.CHARGE_POWER = 200

--- A credit for a building destroyed is the sappers' when it falls this long after their charges blew.
veafCampaignLogistics.BLAST_CREDIT_SECONDS = 30

--- A warehouse count this high is DCS's unlimited, never moved nor restored.
veafCampaignLogistics.UNLIMITED = 1000000

--- Each side's stock of resource points.
veafCampaignLogistics.stocks = {}

--- The supply network's deliveries on their way: `{ side, zone, at, cost, source }`.
veafCampaignLogistics.deliveries = {}

--- A depot's store, by zone name: how many deliveries it can still start once cut from its factories.
veafCampaignLogistics.depotStores = {}

--- The groups spawned by a paid command: `{ name, side }`.
veafCampaignLogistics.paidSpawns = {}

--- The demolition teams, by group name: `{ zone, dropPoint, plantedAt, charges, blownAt }`.
veafCampaignLogistics.sappers = {}

--- The weapons aboard a player's aircraft, by unit name: `{ from, items = { [name] = count } }`.
veafCampaignLogistics.cargo = {}

--- The airfields each player's aircraft has delivered weapons to in this life, by unit name: a second
--- delivery to one of them pays nothing.
veafCampaignLogistics.delivered = {}

veafCampaignLogistics.counters = {}

local function logger()
  return veaf.loggers.get(veafCampaignLogistics.Id)
end

local SIDE_NAMES = { "blue", "red" }

local function playerCoalition()
  return veafCampaign.SIDES[veafCampaign.playerSide()]
end

local function tell(key, ...)
  trigger.action.outTextForCoalition(playerCoalition(), veaf.t(key, ...), 15)
end

--- Answer the person who asked for a spawn: their coalition when it is known, everybody otherwise.
local function answerRequester(requester, text)
  if requester then
    trigger.action.outTextForCoalition(requester, text, 15)
  else
    trigger.action.outText(text, 15)
  end
end

local function distance2d(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

--- The side's name of a DCS coalition number, or nil for the neutral one.
local function sideName(coalitionId)
  for name, id in pairs(veafCampaign.SIDES) do
    if id == coalitionId then
      return name
    end
  end
  return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Resources (ticket 12)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- A side's stock, in points.
function veafCampaignLogistics.stock(side)
  return veafCampaignLogistics.stocks[side] or 0
end

--- Whether a side can pay `cost`: a sortie keeps `resources.reserve` after paying, an "essential" spending
--- goes down to zero, a "partial" one pays whatever is there.
--- @param side string
--- @param cost number
--- @param mode string|nil nil, "essential" or "partial"
function veafCampaignLogistics.canPay(side, cost, mode)
  if mode == "partial" then
    return true
  end
  local after = veafCampaignLogistics.stock(side) - cost
  if mode == "essential" then
    return after >= 0
  end
  return after >= veafCampaign.setting("resources", "reserve")
end

--- Pay `cost` from a side's stock, if it can (see `canPay`).
--- @param what string|nil what for, for the log
--- @return boolean whether it was paid
function veafCampaignLogistics.pay(side, cost, mode, what)
  if not veafCampaignLogistics.canPay(side, cost, mode) then
    veafCampaignLogistics.counters.refused[side] = (veafCampaignLogistics.counters.refused[side] or 0) + 1
    logger():info("%s cannot pay %s (%d points, %d in stock)", side, tostring(what or "a sortie"), cost, veafCampaignLogistics.stock(side))
    return false
  end
  local paid = math.min(cost, veafCampaignLogistics.stock(side))
  veafCampaignLogistics.stocks[side] = veafCampaignLogistics.stock(side) - paid
  veafCampaignLogistics.counters.spent[side] = (veafCampaignLogistics.counters.spent[side] or 0) + paid
  logger():debug("%s pays %d for %s, %d left", side, paid, tostring(what or "a sortie"), veafCampaignLogistics.stock(side))
  return true
end

--- Add points to a side's stock: production, or what comes home.
function veafCampaignLogistics.credit(side, points)
  veafCampaignLogistics.stocks[side] = veafCampaignLogistics.stock(side) + points
end

--- What a side makes in an hour: the background production, and each of its factories by the share of its
--- buildings standing.
--- @param side string
--- @return number points per hour
function veafCampaignLogistics.productionPerHour(side)
  local total = veafCampaign.setting("resources", "background_per_hour")
  local perFactory = veafCampaign.setting("factory", "per_hour")
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone:isFactory() then
      local standing, buildings = zone:structuresStanding()
      if buildings > 0 then
        total = total + perFactory * standing / buildings
      end
    end
  end
  return total
end

--- Run the production for `seconds`.
function veafCampaignLogistics.produce(seconds)
  for _, side in ipairs(SIDE_NAMES) do
    local made = veafCampaignLogistics.productionPerHour(side) * seconds / 3600
    veafCampaignLogistics.credit(side, made)
    veafCampaignLogistics.counters.produced[side] = (veafCampaignLogistics.counters.produced[side] or 0) + made
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The supply network (ticket 13)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Seconds one hop between two zones takes: `network.hop_seconds`, half of it when either is a depot.
function veafCampaignLogistics.hopSeconds(a, b)
  local hop = veafCampaign.setting("network", "hop_seconds")
  if a:isDepot() or b:isDepot() then
    return hop / 2
  end
  return hop
end

--- The shortest delay from a set of sources to every zone of a side, through the side's zones only.
--- @param side string
--- @param sources table `{ { zone, kind } }`
--- @return table by zone name, `{ delay, source = zone name, kind }`
function veafCampaignLogistics.shortestDelays(side, sources)
  local best, done = {}, {}
  for _, source in ipairs(sources) do
    best[source.zone.name] = { delay = 0, source = source.zone.name, kind = source.kind }
  end
  while true do
    local current, currentName = nil, nil
    for _, zone in ipairs(veafCampaign.zoneList) do
      local route = best[zone.name]
      if route and not done[zone.name] and (not current or route.delay < best[currentName].delay) then
        current, currentName = zone, zone.name
      end
    end
    if not current then
      return best
    end
    done[currentName] = true
    for _, neighbour in ipairs(veafCampaign.neighbours(currentName)) do
      if neighbour.entry.owner == side and not done[neighbour.name] then
        local delay = best[currentName].delay + veafCampaignLogistics.hopSeconds(current, neighbour)
        if not best[neighbour.name] or delay < best[neighbour.name].delay then
          best[neighbour.name] = { delay = delay, source = best[currentName].source, kind = best[currentName].kind }
        end
      end
    end
  end
end

--- The side's factories that make something: a building standing.
local function workingFactories(side)
  local sources = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone:isFactory() and zone:structuresStanding() > 0 then
      table.insert(sources, { zone = zone, kind = "factory" })
    end
  end
  return sources
end

--- Every zone's supply delay for a side: from its working factories, and from its depots that still have
--- something in store. A depot a factory reaches is full again first.
--- @param side string
--- @return table by zone name, `{ delay, source, kind }`; a zone absent is cut off
function veafCampaignLogistics.supplyDelays(side)
  local factories = workingFactories(side)
  local fromFactories = veafCampaignLogistics.shortestDelays(side, factories)
  local sources = factories
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone:isDepot() then
      if fromFactories[zone.name] then
        veafCampaignLogistics.depotStores[zone.name] = veafCampaign.setting("network", "depot_store")
      end
      if (veafCampaignLogistics.depotStores[zone.name] or 0) > 0 then
        table.insert(sources, { zone = zone, kind = "depot" })
      end
    end
  end
  return veafCampaignLogistics.shortestDelays(side, sources)
end

--- The dead units of a zone's first damaged group, which a delivery brings back.
local function missingUnits(zone)
  for _, group in ipairs(zone.entry.garrison or {}) do
    local dead = {}
    for _, unit in ipairs(group.units) do
      if not unit.alive then
        table.insert(dead, unit.type)
      end
    end
    if #dead > 0 then
      return dead
    end
  end
  return {}
end

--- Whether a delivery is already on its way to that zone.
local function deliveryUnderway(zoneName)
  for _, delivery in ipairs(veafCampaignLogistics.deliveries) do
    if delivery.zone == zoneName then
      return true
    end
  end
  return false
end

--- How many of a side's deliveries are on their way.
function veafCampaignLogistics.deliveriesUnderway(side)
  local count = 0
  for _, delivery in ipairs(veafCampaignLogistics.deliveries) do
    if delivery.side == side then
      count = count + 1
    end
  end
  return count
end

--- Order the deliveries the side's damaged zones need, paid at the order, on their way for the zone's delay
--- (`network.isolated_seconds` for a zone no source reaches), `network.max_deliveries` at once. Both sides,
--- the players' too: many players never fly logistics, and the network keeps their zones alive; those who do
--- bring crates, troops and helicopters on top of it, which reinforce at once (David, 2026-11-16).
--- @param now number the mission time
function veafCampaignLogistics.dispatchDeliveries(now)
  for _, side in ipairs(SIDE_NAMES) do
    local delays = veafCampaignLogistics.supplyDelays(side)
    for _, zone in ipairs(veafCampaign.zoneList) do
      if veafCampaignLogistics.deliveriesUnderway(side) >= veafCampaign.setting("network", "max_deliveries") then
        break
      end
      if zone.placed and zone.entry.owner == side and zone:garrisonDamaged() and not deliveryUnderway(zone.name) then
        local cost = veafCampaign.unitsPrice(missingUnits(zone))
        local route = delays[zone.name]
        if veafCampaignLogistics.pay(side, cost, "essential", "the supply of " .. zone.name) then
          local delay = route and route.delay or veafCampaign.setting("network", "isolated_seconds")
          table.insert(veafCampaignLogistics.deliveries, {
            side = side,
            zone = zone.name,
            at = now + delay,
            cost = cost,
            source = route and route.source,
          })
          if route and route.kind == "depot" and route.source ~= zone.name then
            local store = veafCampaignLogistics.depotStores[route.source] or 0
            veafCampaignLogistics.depotStores[route.source] = math.max(0, store - 1)
          end
          veafCampaignLogistics.counters.ordered = veafCampaignLogistics.counters.ordered + 1
          logger():info(
            "%s supply for [%s] from [%s]: %d points, there in %d s",
            side,
            zone.name,
            tostring(route and route.source or "cut off"),
            cost,
            delay
          )
        end
      end
    end
  end
end

--- Bring the deliveries that are due: a zone still the side's is reinforced, any other loses them.
--- @param now number the mission time
function veafCampaignLogistics.arriveDeliveries(now)
  local underway = {}
  for _, delivery in ipairs(veafCampaignLogistics.deliveries) do
    if delivery.at <= now then
      local zone = veafCampaign.zones[delivery.zone]
      if zone and zone.entry.owner == delivery.side and zone:reinforce() then
        veafCampaignLogistics.counters.arrived = veafCampaignLogistics.counters.arrived + 1
        if delivery.side == veafCampaign.playerSide() then
          tell("campaign.network.arrived", zone.name)
        end
      else
        veafCampaignLogistics.counters.lost = veafCampaignLogistics.counters.lost + 1
        logger():info("the %s supply for [%s] is lost: the zone is no longer theirs", delivery.side, delivery.zone)
      end
    else
      table.insert(underway, delivery)
    end
  end
  veafCampaignLogistics.deliveries = underway
end

--- The supply network, as the players' side reads it: its stock, what it makes, each of its zones' delay.
function veafCampaignLogistics.networkText(side)
  local lines = {
    veaf.t(
      "campaign.network.header",
      math.floor(veafCampaignLogistics.stock(side)),
      math.floor(veafCampaignLogistics.productionPerHour(side))
    ),
  }
  local delays = veafCampaignLogistics.supplyDelays(side)
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side then
      local route = delays[zone.name]
      local line = route and veaf.t("campaign.network.zone", zone.name, math.floor(route.delay / 60), route.source)
        or veaf.t("campaign.network.cut", zone.name)
      if deliveryUnderway(zone.name) then
        line = line .. veaf.t("campaign.network.underway")
      end
      table.insert(lines, line)
    end
  end
  return table.concat(lines, "\n")
end

--- Radio command: the players' side's supply network.
function veafCampaignLogistics.reportNetwork()
  trigger.action.outTextForCoalition(playerCoalition(), veafCampaignLogistics.networkText(veafCampaign.playerSide()), 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Paid spawns (ticket 14)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What a VEAF spawn command costs, or nil when it is free.
function veafCampaignLogistics.spawnPrice(key)
  local overrides = veafCampaign.setting("economy", "spawn_prices") or {}
  local price = overrides[key] or veafCampaignLogistics.SPAWN_PRICES[key]
  if price and price > 0 then
    return price
  end
  return nil
end

--- Asked by veafSpawn before a person's spawn command runs: whether the side it spawns for can pay it. A
--- refusal tells the requester what it costs and what is left; nothing is charged.
--- @param key string the command, as veafSpawn registers its handler
--- @param options table the parsed command: `side` the coalition it spawns for
--- @param requester number the coalition to answer
--- @return boolean whether it may run
function veafCampaignLogistics.spawnGate(key, options, requester)
  local price = veafCampaignLogistics.spawnPrice(key)
  local side = sideName(options.side)
  if not price or not side or veafCampaign.over then
    return true
  end
  if side == veafCampaign.playerSide() then
    local credits = veafCampaignEconomy and veafCampaignEconomy.credits or 0
    if credits < price then
      veafCampaignLogistics.counters.spawnsRefused = veafCampaignLogistics.counters.spawnsRefused + 1
      answerRequester(requester, veaf.t("campaign.spawn.refused_credits", key, price, credits))
      return false
    end
  elseif veafCampaignLogistics.active and not veafCampaignLogistics.canPay(side, price, "essential") then
    veafCampaignLogistics.counters.spawnsRefused = veafCampaignLogistics.counters.spawnsRefused + 1
    answerRequester(
      requester,
      veaf.t(
        "campaign.spawn.refused_resources",
        key,
        veaf.t("campaign.side." .. side),
        price,
        math.floor(veafCampaignLogistics.stock(side))
      )
    )
    return false
  end
  return true
end

--- Told by veafSpawn once a paid command spawned a group: charge it, and remember the group, whose
--- survivors come home at the next load.
function veafCampaignLogistics.spawnPaid(key, options, groupName, requester)
  local price = veafCampaignLogistics.spawnPrice(key)
  local side = sideName(options.side)
  if not price or not side or veafCampaign.over then
    return
  end
  if side == veafCampaign.playerSide() then
    if veafCampaignEconomy then
      veafCampaignEconomy.credits = math.max(0, veafCampaignEconomy.credits - price)
      answerRequester(requester, veaf.t("campaign.spawn.paid_credits", key, price, veafCampaignEconomy.credits))
    end
  elseif veafCampaignLogistics.active then
    veafCampaignLogistics.pay(side, price, "partial", "spawn " .. key)
  end
  veafCampaignLogistics.counters.spawnsCharged = veafCampaignLogistics.counters.spawnsCharged + 1
  table.insert(veafCampaignLogistics.paidSpawns, { name = groupName, side = side })
  logger():info("spawn [%s] for %s paid %d: group [%s]", key, side, price, tostring(groupName))
end

--- What the paid spawns still in the world are worth, by side.
function veafCampaignLogistics.paidSurvivors()
  local worth = {}
  for _, spawn in ipairs(veafCampaignLogistics.paidSpawns) do
    local group = Group.getByName(spawn.name)
    if group and group:isExist() then
      local types = {}
      for _, unit in ipairs(group:getUnits() or {}) do
        if unit and unit:isExist() and unit:getLife() >= 1 then
          table.insert(types, unit:getTypeName())
        end
      end
      worth[spawn.side] = (worth[spawn.side] or 0) + veafCampaign.unitsPrice(types)
    end
  end
  return worth
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Demolition teams (ticket 15)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The nearest enemy factory with a building standing whose buildings are within `demolition.range`.
local function sapperTarget(point)
  local enemy, best, bestDistance = veafCampaign.enemyOf(veafCampaign.playerSide()), nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == enemy and zone:isFactory() and zone:structuresStanding() > 0 then
      local d = distance2d(zone:structuresCenter(), point)
      if d <= veafCampaign.setting("demolition", "range") and (not bestDistance or d < bestDistance) then
        best, bestDistance = zone, d
      end
    end
  end
  return best
end

local function walk(group, from, to)
  local route = {
    { x = from.x, y = from.z, type = "Turning Point", action = "Off Road", speed = 5 },
    { x = to.x, y = to.z, type = "Turning Point", action = "Off Road", speed = 5 },
  }
  group:getController():setTask({ id = "Mission", params = { route = { points = route } } })
end

--- Follow one demolition team: sent to its factory the first time it is seen, plants its charges on every
--- standing building when it reaches their row, and walks back to where it was dropped.
--- @param groupName string
--- @param now number the mission time
function veafCampaignLogistics.followSapper(groupName, now)
  local group = Group.getByName(groupName)
  local unit = group and group:isExist() and group:getUnits()[1]
  if not unit then
    return
  end
  local point = unit:getPoint()
  local team = veafCampaignLogistics.sappers[groupName]
  if not team then
    local target = sapperTarget(point)
    team = { zone = target and target.name, dropPoint = { x = point.x, z = point.z } }
    veafCampaignLogistics.sappers[groupName] = team
    if not target then
      tell("campaign.demolition.no_target", veafCampaign.setting("demolition", "range") / 1000)
      return
    end
    veafCampaignLogistics.counters.teams = veafCampaignLogistics.counters.teams + 1
    walk(group, point, target:structuresCenter())
    tell("campaign.demolition.sent", target.name)
    return
  end
  local zone = team.zone and veafCampaign.zones[team.zone]
  if not zone or team.plantedAt then
    return
  end
  if distance2d(point, zone:structuresCenter()) <= veafCampaignLogistics.PLANT_DISTANCE then
    team.plantedAt = now
    team.charges = {}
    for index, structure in ipairs(zone.entry.structures or {}) do
      if structure.alive then
        table.insert(team.charges, index)
      end
    end
    walk(group, point, team.dropPoint)
    tell("campaign.demolition.planted", zone.name, #team.charges, veafCampaign.setting("demolition", "fuse"))
  end
end

--- Blow the charges whose fuse has burnt, whether their team is still alive or not.
--- @param now number the mission time
function veafCampaignLogistics.blowCharges(now)
  for _, team in pairs(veafCampaignLogistics.sappers) do
    if team.plantedAt and not team.blownAt and now >= team.plantedAt + veafCampaign.setting("demolition", "fuse") then
      team.blownAt = now
      local zone = veafCampaign.zones[team.zone]
      for _, index in ipairs(team.charges or {}) do
        local structure = zone and zone.entry.structures[index]
        if structure and structure.alive then
          local static = StaticObject.getByName(veafCampaign.structureName(zone, index))
          local life = static and static.getLife and static:getLife() or 0
          local position = { x = structure.x, y = land.getHeight({ x = structure.x, y = structure.z }), z = structure.z }
          trigger.action.explosion(position, math.max(veafCampaignLogistics.CHARGE_POWER, life))
          veafCampaignLogistics.counters.charges = veafCampaignLogistics.counters.charges + 1
        end
      end
      logger():info("the sappers' charges blow in [%s]", tostring(team.zone))
    end
  end
end

--- A building fell: if sappers' charges blew in its zone just before, it is theirs, and the side is paid.
function veafCampaignLogistics.onStructureLost(zone)
  for _, team in pairs(veafCampaignLogistics.sappers) do
    if team.zone == zone.name and team.blownAt and timer.getTime() - team.blownAt <= veafCampaignLogistics.BLAST_CREDIT_SECONDS then
      veafCampaignLogistics.counters.demolished = veafCampaignLogistics.counters.demolished + 1
      if veafCampaignEconomy and veafCampaignEconomy.earn then
        veafCampaignEconomy.earn(veafCampaign.setting("economy", "demolition"), "campaign.credits.demolition", zone.name)
      end
      return
    end
  end
end

--- The demolition teams the players' side has dropped, followed each beat.
function veafCampaignLogistics.followSappers(now)
  if CTLDTroopManager and CTLDTroopManager.getInstance then
    local ok, manager = pcall(CTLDTroopManager.getInstance)
    local dropped = ok and manager and manager._droppedGroups and manager._droppedGroups[playerCoalition()]
    local template = veafCampaign.setting("demolition", "troops")
    for _, groupName in ipairs(dropped or {}) do
      if veafCampaign.ctldTroopTemplate(groupName) == template then
        veafCampaignLogistics.followSapper(groupName, now)
      end
    end
  end
  veafCampaignLogistics.blowCharges(now)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Warehouse stocks (ticket 16)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The DCS warehouse of an airfield zone, or nil.
local function warehouseOf(zone)
  local airbase = zone.entry.airbase and Airbase.getByName(zone.entry.airbase)
  if not (airbase and airbase.getWarehouse) then
    return nil
  end
  local ok, warehouse = pcall(airbase.getWarehouse, airbase)
  return ok and warehouse or nil
end

--- Set each airfield zone's weapon counts back to what the save read: a count of DCS's unlimited is left.
--- @return number the warehouses restored
function veafCampaignLogistics.restoreWarehouses()
  local restored = 0
  for _, zone in ipairs(veafCampaign.zoneList) do
    local saved = zone.entry.saved_warehouse
    local warehouse = type(saved) == "table" and type(saved.weapon) == "table" and warehouseOf(zone)
    if warehouse then
      for name, count in pairs(saved.weapon) do
        if type(count) == "number" and count < veafCampaignLogistics.UNLIMITED then
          pcall(warehouse.setItem, warehouse, name, count)
        end
      end
      restored = restored + 1
    end
    zone.entry.saved_warehouse = nil
  end
  veafCampaignLogistics.counters.warehousesRestored = restored
  return restored
end

--- The players' airfield zone a unit is on the ground at, or nil.
local function airfieldUnder(unit)
  if unit:inAir() then
    return nil
  end
  local point = unit:getPoint()
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.airbase and zone.entry.owner == veafCampaign.playerSide() then
      if distance2d(point, zone:getCenter()) <= (zone.entry.radius or 2000) then
        return zone
      end
    end
  end
  return nil
end

--- Whether a unit can carry weapons from one warehouse to another: a helicopter, or a transport aircraft.
local function isTransport(unit)
  local desc = unit:getDesc() or {}
  return desc.category == Unit.Category.HELICOPTER or (desc.attributes and desc.attributes["Transports"]) == true
end

--- The player's unit a radio command of the group menu comes from, and how to answer it. veafRadio hands
--- a command registered without parameters the unit name alone, and `{ parameters, unitName }` otherwise.
local function caller(parameters)
  local unitName = parameters
  if type(parameters) == "table" then
    unitName = parameters[2]
  end
  local unit = unitName and Unit.getByName(unitName)
  if not unit then
    return nil
  end
  local group = unit:getGroup()
  local groupId = group and group:getID()
  return unit, unitName, function(key, ...)
    trigger.action.outTextForGroup(groupId, veaf.t(key, ...), 15)
  end
end

--- Radio command: take `warehouse.load` of each weapon the airfield holds into the aircraft.
function veafCampaignLogistics.loadWeapons(parameters)
  local unit, unitName, answer = caller(parameters)
  if not unit then
    return
  end
  local zone = airfieldUnder(unit)
  local warehouse = zone and warehouseOf(zone)
  if not isTransport(unit) then
    return answer("campaign.warehouse.not_transport")
  elseif not warehouse then
    return answer("campaign.warehouse.not_here")
  elseif veafCampaignLogistics.cargo[unitName] then
    return answer("campaign.warehouse.already_loaded")
  end
  local ok, inventory = pcall(warehouse.getInventory, warehouse)
  local wanted, items, total = veafCampaign.setting("warehouse", "load"), {}, 0
  for name, count in pairs(ok and type(inventory) == "table" and inventory.weapon or {}) do
    if type(count) == "number" and count > 0 and count < veafCampaignLogistics.UNLIMITED then
      local take = math.min(count, wanted)
      pcall(warehouse.removeItem, warehouse, name, take)
      items[name], total = take, total + take
    end
  end
  if total == 0 then
    return answer("campaign.warehouse.empty", zone.name)
  end
  veafCampaignLogistics.cargo[unitName] = { from = zone.name, items = items, total = total }
  veafCampaignLogistics.counters.loads = veafCampaignLogistics.counters.loads + 1
  answer("campaign.warehouse.loaded", total, zone.name)
end

--- Radio command: unload the aircraft's weapons into the warehouse of another airfield of the side.
function veafCampaignLogistics.unloadWeapons(parameters)
  local unit, unitName, answer = caller(parameters)
  if not unit then
    return
  end
  local cargo = veafCampaignLogistics.cargo[unitName]
  local zone = airfieldUnder(unit)
  local warehouse = zone and warehouseOf(zone)
  if not cargo then
    return answer("campaign.warehouse.nothing_aboard")
  elseif not warehouse or zone.name == cargo.from then
    return answer("campaign.warehouse.not_there")
  end
  for name, count in pairs(cargo.items) do
    pcall(warehouse.addItem, warehouse, name, count)
  end
  veafCampaignLogistics.cargo[unitName] = nil
  veafCampaignLogistics.counters.unloads = veafCampaignLogistics.counters.unloads + 1
  answer("campaign.warehouse.unloaded", cargo.total, zone.name)
  -- paid once per airfield and per life of the aircraft: weapons carried back and forth earn nothing more
  local delivered = veafCampaignLogistics.delivered[unitName] or {}
  veafCampaignLogistics.delivered[unitName] = delivered
  local paid = not delivered[zone.name]
  delivered[zone.name] = true
  if paid and veafCampaignEconomy and veafCampaignEconomy.earn then
    veafCampaignEconomy.earn(veafCampaign.setting("economy", "warehouse_delivery"), "campaign.credits.warehouse", zone.name)
  end
end

--- Radio command: what the aircraft carries.
function veafCampaignLogistics.reportCargo(parameters)
  local unit, unitName, answer = caller(parameters)
  if not unit then
    return
  end
  local cargo = veafCampaignLogistics.cargo[unitName]
  if not cargo then
    return answer("campaign.warehouse.nothing_aboard")
  end
  answer("campaign.warehouse.cargo", cargo.total, cargo.from)
end

--- A player's aircraft is lost, or a new one is born under its name: its cargo is gone.
function veafCampaignLogistics.onAircraftGone(event)
  local name = veafEventHandler.unitNameFromEvent(event)
  if name then
    veafCampaignLogistics.delivered[name] = nil
  end
  if name and veafCampaignLogistics.cargo[name] then
    veafCampaignLogistics.cargo[name] = nil
    logger():info("the weapons aboard [%s] are lost", name)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu, loop, save, self-check, initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The players' menus under Campaign: the supply network, and the warehouse commands of each aircraft.
function veafCampaignLogistics.buildRadioMenu()
  if not (veafRadio and veafCampaign.rootPath) then
    return
  end
  if veafCampaignLogistics.active then
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.network"),
      veafCampaign.rootPath,
      veafCampaignLogistics.reportNetwork,
      nil,
      veafRadio.USAGE_ForAll
    )
  end
  if veafCampaign.setting("warehouse", "enabled") then
    local path = veafRadio.addSubMenu(veaf.t("menu.campaign.warehouse"), veafCampaign.rootPath, playerCoalition())
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.warehouse_load"),
      path,
      veafCampaignLogistics.loadWeapons,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.warehouse_unload"),
      path,
      veafCampaignLogistics.unloadWeapons,
      nil,
      veafRadio.USAGE_ForGroup
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.warehouse_cargo"),
      path,
      veafCampaignLogistics.reportCargo,
      nil,
      veafRadio.USAGE_ForGroup
    )
  end
  veafRadio.refreshRadioMenu()
end

--- One beat, inside veafCampaign's loop.
function veafCampaignLogistics.beat(now)
  local elapsed = now - (veafCampaignLogistics.lastBeat or now)
  veafCampaignLogistics.lastBeat = now
  if veafCampaign.over then
    return
  end
  if veafCampaignLogistics.active then
    veafCampaignLogistics.produce(elapsed)
    veafCampaignLogistics.arriveDeliveries(now)
    veafCampaignLogistics.dispatchDeliveries(now)
  end
  veafCampaignLogistics.followSappers(now)
end

--- What the save keeps: the stocks and the depots' stores, and what is on its way or was bought and still
--- stands — paid back at the next load, since none of it is restored.
function veafCampaignLogistics.save()
  local away = veafCampaignLogistics.paidSurvivors()
  for _, delivery in ipairs(veafCampaignLogistics.deliveries) do
    away[delivery.side] = (away[delivery.side] or 0) + delivery.cost
  end
  local stocks = {}
  for _, side in ipairs(SIDE_NAMES) do
    stocks[side] = math.floor(veafCampaignLogistics.stock(side))
  end
  return { stocks = stocks, depots = veafCampaignLogistics.depotStores, away = away }
end

--- Take back what the save kept, and add what comes home.
function veafCampaignLogistics.load(saved)
  if type(saved) == "table" then
    for _, side in ipairs(SIDE_NAMES) do
      local stock = type(saved.stocks) == "table" and tonumber(saved.stocks[side])
      if stock then
        veafCampaignLogistics.stocks[side] = stock
      end
      local away = type(saved.away) == "table" and tonumber(saved.away[side])
      if away then
        veafCampaignLogistics.credit(side, away)
      end
    end
    for name, store in pairs(type(saved.depots) == "table" and saved.depots or {}) do
      veafCampaignLogistics.depotStores[name] = tonumber(store)
    end
  end
  for side, worth in pairs(veafCampaign.homecoming or {}) do
    veafCampaignLogistics.credit(side, worth)
  end
end

--- The self-check's lines.
function veafCampaignLogistics.selfCheck(verdict)
  local c, lines = veafCampaignLogistics.counters, {}
  if veafCampaignLogistics.active then
    table.insert(
      lines,
      verdict(
        true,
        "campaign.check.resources",
        math.floor(veafCampaignLogistics.stock("blue")),
        math.floor(veafCampaignLogistics.productionPerHour("blue")),
        math.floor(veafCampaignLogistics.stock("red")),
        math.floor(veafCampaignLogistics.productionPerHour("red")),
        math.floor(c.spent.blue or 0),
        math.floor(c.spent.red or 0)
      )
    )
    local cut = {}
    for _, side in ipairs(SIDE_NAMES) do
      local delays = veafCampaignLogistics.supplyDelays(side)
      for _, zone in ipairs(veafCampaign.zoneList) do
        if zone.placed and zone.entry.owner == side and not delays[zone.name] then
          table.insert(cut, zone.name)
        end
      end
    end
    table.insert(
      lines,
      verdict(true, "campaign.check.network", #veafCampaignLogistics.deliveries, c.ordered, c.arrived, c.lost, table.concat(cut, ", "))
    )
  else
    table.insert(lines, verdict(true, "campaign.check.resources_off"))
  end
  table.insert(lines, verdict(true, "campaign.check.spawns", c.spawnsCharged, c.spawnsRefused))
  table.insert(lines, verdict(true, "campaign.check.demolition", c.teams, c.charges, c.demolished))
  if veafCampaign.setting("warehouse", "enabled") then
    table.insert(lines, verdict(true, "campaign.check.warehouse", c.warehousesRestored, c.loads, c.unloads))
  end
  return lines
end

--- Start the logistics of a persistent campaign. Called by veafCampaign.initialize, before the sorties and
--- the economy, which pay from it.
function veafCampaignLogistics.initialize()
  logger():info("Initializing module")
  veafCampaignLogistics.active = veafCampaign.setting("resources", "enabled") == true
  veafCampaignLogistics.stocks, veafCampaignLogistics.deliveries, veafCampaignLogistics.depotStores = {}, {}, {}
  veafCampaignLogistics.paidSpawns, veafCampaignLogistics.sappers, veafCampaignLogistics.cargo = {}, {}, {}
  veafCampaignLogistics.delivered = {}
  veafCampaignLogistics.lastBeat = nil
  veafCampaignLogistics.counters = {
    refused = {},
    spent = {},
    produced = {},
    ordered = 0,
    arrived = 0,
    lost = 0,
    spawnsCharged = 0,
    spawnsRefused = 0,
    teams = 0,
    charges = 0,
    demolished = 0,
    warehousesRestored = 0,
    loads = 0,
    unloads = 0,
  }
  for _, side in ipairs(SIDE_NAMES) do
    veafCampaignLogistics.stocks[side] = veafCampaign.setting("resources", "start")
  end
  veafCampaignLogistics.load(veafCampaign.savedPart("logistics"))
  veafCampaign.saveParts.logistics = { save = veafCampaignLogistics.save }
  if veafCampaign.setting("warehouse", "enabled") then
    veafCampaignLogistics.restoreWarehouses()
  end
  if veafSpawn then
    veafSpawn.spawnGate = veafCampaignLogistics.spawnGate
    veafSpawn.spawnPaid = veafCampaignLogistics.spawnPaid
  end
  table.insert(veafCampaign.beatHooks, veafCampaignLogistics.beat)
  table.insert(veafCampaign.selfChecks, veafCampaignLogistics.selfCheck)
  veafCampaign.listen("structure_lost", veafCampaignLogistics.onStructureLost)
  veafEventHandler.addCallback(
    "veafCampaignLogistics.onAircraftGone",
    { "S_EVENT_DEAD", "S_EVENT_CRASH", "S_EVENT_PILOT_DEAD", "S_EVENT_EJECTION", "S_EVENT_BIRTH" },
    veafCampaignLogistics.onAircraftGone
  )
  veafCampaignLogistics.buildRadioMenu()
  return true
end

veaf.loggers.get(veafCampaignLogistics.Id):info(veaf.loggers.get(veafCampaignLogistics.Id):getVersionInfo())
