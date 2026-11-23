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

--- The VEAF spawn commands that put units into play, and are paid for the units they made (ticket 14). Every
--- other one — smoke, flares, drawings, destroy, teleport, mission master — is free.
veafCampaignLogistics.SPAWN_COMMANDS = {
  unit = true,
  group = true,
  infantryGroup = true,
  armoredPlatoon = true,
  airDefenseBattery = true,
  transportCompany = true,
  fullCombatGroup = true,
  convoy = true,
  cap = true,
  afac = true,
  awacs = true,
  escort = true,
  farp = true,
  fob = true,
  cargo = true,
  logistic = true,
}

--- The markers a persistent campaign reserves to admins: what would be cheating there — explosions, destroying,
--- teleporting, broadcasting, activating designed content, free illumination the shop sells (David,
--- 2026-11-16). Aliases by name, commands by their first words.
veafCampaignLogistics.ADMIN_MARKERS = {
  ["-shell"] = true,
  ["-cesar"] = true,
  ["-flak"] = true,
  ["-destroy"] = true,
  ["-tanker"] = true,
  ["-tankerhere"] = true,
  ["-zonestart"] = true,
  ["-zonestop"] = true,
  ["-airstart"] = true,
  ["-airstop"] = true,
  ["-send"] = true,
  ["-play"] = true,
  ["-light"] = true,
  ["_spawn bomb"] = true,
  ["_spawn flare"] = true,
  ["_destroy"] = true,
  ["_teleport"] = true,
  ["_radio"] = true,
}

--- The markers a persistent campaign turns off: a dynamic CAS training zone makes no sense in it (David,
--- 2026-11-16).
veafCampaignLogistics.DISABLED_MARKERS = {
  ["-cas"] = true,
  ["_cas"] = true,
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
--- goes down to zero, a "partial" one pays whatever is there, and a "debt" — a person's spawn, charged after
--- the fact (ticket 14) — the whole of it, below zero if need be. A side in debt pays nothing else.
--- @param side string
--- @param cost number
--- @param mode string|nil nil, "essential", "partial" or "debt"
function veafCampaignLogistics.canPay(side, cost, mode)
  if mode == "partial" or mode == "debt" then
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
--- @param kind string|nil what for, for the session's books (`veafCampaignEconomy.book`), `other` when nil
--- @return boolean whether it was paid
function veafCampaignLogistics.pay(side, cost, mode, what, kind)
  if not veafCampaignLogistics.canPay(side, cost, mode) then
    veafCampaignLogistics.counters.refused[side] = (veafCampaignLogistics.counters.refused[side] or 0) + 1
    logger():info("%s cannot pay %s (%d points, %d in stock)", side, tostring(what or "a sortie"), cost, veafCampaignLogistics.stock(side))
    return false
  end
  local paid = cost
  if mode ~= "debt" then
    paid = math.max(0, math.min(cost, veafCampaignLogistics.stock(side)))
  end
  veafCampaignLogistics.stocks[side] = veafCampaignLogistics.stock(side) - paid
  veafCampaignLogistics.counters.spent[side] = (veafCampaignLogistics.counters.spent[side] or 0) + paid
  if veafCampaignEconomy and veafCampaignEconomy.book then
    veafCampaignEconomy.book(side, "spent", kind or "other", paid)
  end
  logger():debug("%s pays %d for %s, %d left", side, paid, tostring(what or "a sortie"), veafCampaignLogistics.stock(side))
  return true
end

--- Add points to a side's stock: production, or what comes home.
--- @param kind string|nil what it is, for the session's books (`veafCampaignEconomy.book`): `refund`; nil books nothing
function veafCampaignLogistics.credit(side, points, kind)
  veafCampaignLogistics.stocks[side] = veafCampaignLogistics.stock(side) + points
  if kind and veafCampaignEconomy and veafCampaignEconomy.book then
    veafCampaignEconomy.book(side, "earned", kind, points)
  end
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
    if veafCampaignEconomy and veafCampaignEconomy.book then
      veafCampaignEconomy.book(side, "earned", "production", made, true)
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The supply network (ticket 13)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Seconds one hop between two zones takes: `network.hop_seconds`, half of it when either is a depot.
function veafCampaignLogistics.hopSeconds(a, b)
  local hop = veafCampaign.setting("network", "hop_seconds")
  if a:isWorkingDepot() or b:isWorkingDepot() then
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
    if zone.placed and zone.entry.owner == side and zone:isWorkingDepot() then
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
        if veafCampaignLogistics.pay(side, cost, "essential", "the supply of " .. zone.name, "reinforcement") then
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
          veafCampaign.debug(
            "SUPPLY",
            "%s orders the supply of [%s]: %d points, from [%s], there in %d s",
            side,
            zone.name,
            cost,
            tostring(route and route.source or "cut off"),
            delay
          )
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

--- The distance from a zone's centre to the nearest living vehicle of an enemy convoy within `network.threat_radius`,
--- or nil when none stands that near. The campaign's own convoys only, no world search: on 2026-11-22 Menagh was
--- repaired in a lull of its losses while the red assault convoy stood 1.1 to 4.3 km out, and destroyed again at once
--- (FIX-CAMPAIGN-SIXTH-SERVER-FLIGHT ticket 02).
--- @param zone table the zone
--- @param side string the zone's side
--- @return number|nil metres
function veafCampaignLogistics.enemyAtTheGates(zone, side)
  local radius = veafCampaign.setting("network", "threat_radius")
  local center = zone:getCenter()
  local nearest = nil
  for _, record in ipairs(veafCampaign.convoys) do
    if not record.ended and record.side ~= side then
      for _, unit in ipairs(veafCampaign.convoyUnits(record)) do
        local point = unit:getPoint()
        local distance = math.sqrt((point.x - center.x) ^ 2 + (point.z - center.z) ^ 2)
        if distance <= radius and (not nearest or distance < nearest) then
          nearest = distance
        end
      end
    end
  end
  return nearest
end

--- Bring the deliveries that are due. A zone no longer the side's loses them; a zone that lost a unit less than
--- `network.under_fire_seconds` ago waits for them (ticket 03), and so does a zone with an enemy convoy within
--- `network.threat_radius` (`enemyAtTheGates`); otherwise the zone gets back what the delivery
--- pays for, and the points it does not spend — all of them when nothing is missing any more — go back to the
--- side's stock (ticket 09: "lost: the zone is no longer theirs" was also said of a zone with nothing to repair).
--- @param now number the mission time
function veafCampaignLogistics.arriveDeliveries(now)
  local underway = {}
  local underFire = veafCampaign.setting("network", "under_fire_seconds")
  for _, delivery in ipairs(veafCampaignLogistics.deliveries) do
    local zone = veafCampaign.zones[delivery.zone]
    if delivery.at > now then
      table.insert(underway, delivery)
    elseif not zone or zone.entry.owner ~= delivery.side then
      veafCampaignLogistics.counters.lost = veafCampaignLogistics.counters.lost + 1
      veafCampaign.debug("SUPPLY", "the %s supply for [%s] is lost", delivery.side, delivery.zone)
      logger():info("the %s supply for [%s] is lost: the zone is no longer theirs", delivery.side, delivery.zone)
    elseif zone.lastLossAt and now - zone.lastLossAt < underFire then
      if not delivery.held then
        delivery.held = true
        logger():info(
          "the %s supply for [%s] waits: the zone lost a unit %d s ago, under fire",
          delivery.side,
          delivery.zone,
          math.floor(now - zone.lastLossAt)
        )
      end
      table.insert(underway, delivery)
    elseif veafCampaignLogistics.enemyAtTheGates(zone, delivery.side) then
      if not delivery.heldByEnemy then
        delivery.heldByEnemy = true
        logger():info(
          "the %s supply for [%s] waits: an enemy convoy %.1f km away",
          delivery.side,
          delivery.zone,
          veafCampaignLogistics.enemyAtTheGates(zone, delivery.side) / 1000
        )
      end
      table.insert(underway, delivery)
    else
      local cost = delivery.cost or 0
      local reinforced, spent = zone:reinforce(cost)
      local unspent = math.max(0, cost - (spent or 0))
      if unspent > 0 then
        veafCampaignLogistics.credit(delivery.side, unspent, "refund")
      end
      if reinforced then
        veafCampaignLogistics.counters.arrived = veafCampaignLogistics.counters.arrived + 1
        veafCampaign.debug("SUPPLY", "the %s supply reaches [%s]", delivery.side, delivery.zone)
        if delivery.side == veafCampaign.playerSide() then
          veafCampaign.announce(delivery.side, delivery.side, veaf.t("campaign.network.arrived", veafCampaign.zoneTitle(zone.name)))
        end
      else
        veafCampaignLogistics.counters.unneeded = veafCampaignLogistics.counters.unneeded + 1
        logger():info(
          "the %s supply for [%s] has nothing to repair there: its %d point(s) go back to the stock",
          delivery.side,
          delivery.zone,
          unspent
        )
      end
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
      local title = veafCampaign.zoneTitle(zone.name)
      local line = route and veaf.t("campaign.network.zone", title, math.floor(route.delay / 60), veafCampaign.zoneTitle(route.source))
        or veaf.t("campaign.network.cut", title)
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

--- Whether a VEAF spawn command puts units into play, and so is paid.
function veafCampaignLogistics.isPaidSpawn(key)
  return veafCampaignLogistics.SPAWN_COMMANDS[key] == true
end

--- What a paid spawn costs its side: the points of the units it made, in credits for the players' side
--- (`economy.credits_per_point` credits a point), in resource points for the other.
--- @param side string
--- @param points number
--- @return number the cost
--- @return number what the side has
--- @return string "credits" or "resources"
local function spawnBill(side, points)
  if side == veafCampaign.playerSide() then
    local credits = veafCampaignEconomy and veafCampaignEconomy.credits or 0
    return points * veafCampaign.setting("economy", "credits_per_point"), credits, "credits"
  end
  return points, veafCampaignLogistics.stock(side), "resources"
end

--- Whether the side a spawn is for pays for it: a paid command, a side of the campaign, the campaign not over,
--- and for the other side, its resources counted.
local function payingSide(key, options)
  local side = sideName(options.side)
  if not veafCampaignLogistics.isPaidSpawn(key) or not side or veafCampaign.over then
    return nil
  end
  if side ~= veafCampaign.playerSide() and not veafCampaignLogistics.active then
    return nil
  end
  return side
end

--- Asked by veafSpawn before a person's spawn command runs, once for all its copies. What it will cost is only
--- known once its units exist — a random group draws them —, so the rule is the balance: a side with nothing,
--- or in debt, spawns nothing more until it is above zero again; anything else may run (David, 2026-11-16).
--- @param key string the command, as veafSpawn registers its handler
--- @param options table the parsed command: `side` the coalition it spawns for
--- @param requester number|nil the coalition to answer
--- @return boolean whether it may run
function veafCampaignLogistics.spawnGate(key, options, requester)
  local side = payingSide(key, options)
  if not side then
    return true
  end
  local _, balance, currency = spawnBill(side, 0)
  if balance <= 0 then
    veafCampaignLogistics.counters.spawnsRefused = veafCampaignLogistics.counters.spawnsRefused + 1
    answerRequester(requester, veaf.t("campaign.spawn.refused_" .. currency, key, veaf.t("campaign.side." .. side), math.floor(balance)))
    return false
  end
  return true
end

--- The DCS type of every unit a spawn made: a group's units, or the static itself. The pathfinding vehicle a
--- convoy carries for its first seconds is not one of them.
local function spawnedTypes(name)
  local types = {}
  local group = Group.getByName(name)
  if group and group:isExist() then
    for _, unit in ipairs(group:getUnits() or {}) do
      local typeName = unit and unit:isExist() and unit:getTypeName()
      if typeName and not (veafUnits and typeName == veafUnits.DefaultPathfindingUnitType) then
        table.insert(types, typeName)
      end
    end
    return types
  end
  local static = StaticObject.getByName(name)
  if static then
    table.insert(types, static:getTypeName())
  end
  return types
end

--- Told by veafSpawn once a paid command spawned a group: the price of its units, unit by unit
--- (`veafCampaign.unitPrice`, David 2026-11-16), is charged in full — into debt when the balance is short, so
--- that a spawn is never cut in part; the side spawns nothing more while it is in debt. A group paid is
--- remembered: its survivors come home at the next load.
function veafCampaignLogistics.spawnPaid(key, options, groupName, requester)
  local side = payingSide(key, options)
  if not side then
    return
  end
  local types = spawnedTypes(groupName)
  local cost, _, currency = spawnBill(side, veafCampaign.unitsPrice(types))
  local balance
  if currency == "credits" then
    veafCampaignEconomy.credits = veafCampaignEconomy.credits - cost
    veafCampaignEconomy.book("credits", "spent", "spawn", cost)
    balance = veafCampaignEconomy.credits
    answerRequester(requester, veaf.t("campaign.spawn.paid_credits", key, #types, cost, balance))
  else
    veafCampaignLogistics.pay(side, cost, "debt", "spawn " .. key, "spawn")
    balance = veafCampaignLogistics.stock(side)
  end
  if balance < 0 then
    answerRequester(requester, veaf.t("campaign.spawn.in_debt_" .. currency, veaf.t("campaign.side." .. side), math.floor(balance)))
  end
  veafCampaignLogistics.counters.spawnsCharged = veafCampaignLogistics.counters.spawnsCharged + 1
  table.insert(veafCampaignLogistics.paidSpawns, { name = groupName, side = side })
  logger():info("spawn [%s] for %s paid %d for %d unit(s), balance %d: group [%s]", key, side, cost, #types, balance, tostring(groupName))
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

--- The policy a persistent campaign sets on the players' markers (`veafCommands.markerPolicy`): "disabled",
--- "ADMIN", or nil for the module's own level. An alias is its first word (veafShortcuts reads one only
--- there); a command is found anywhere in the text, as its module finds it — `_x _spawn bomb` is a bomb.
--- `_spawn` counts with its kind, `_move` only when it teleports.
--- @param text string the marker's text
--- @return string|nil
function veafCampaignLogistics.markerPolicy(text)
  local lower = type(text) == "string" and text:lower() or ""
  local alias = lower:match("^%s*(%-[%w_]+)")
  local commands = {}
  for word in lower:gmatch("(_[%w_]+)") do
    commands[word] = true
  end
  for kind in lower:gmatch("_spawn%s+([%w]+)") do
    commands["_spawn " .. kind] = true
  end
  local function listed(list)
    if alias and list[alias] then
      return true
    end
    for command in pairs(commands) do
      if list[command] then
        return true
      end
    end
    return false
  end
  if listed(veafCampaignLogistics.DISABLED_MARKERS) then
    return "disabled"
  end
  if listed(veafCampaignLogistics.ADMIN_MARKERS) or (commands["_move"] and lower:find("teleport", 1, true)) then
    return "ADMIN"
  end
  return nil
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
  if paid and veafCampaignEconomy and veafCampaignEconomy.earnBy then
    local unit = Unit.getByName(unitName)
    local ok, pilot = false, nil
    if unit and unit.getPlayerName then
      ok, pilot = pcall(unit.getPlayerName, unit)
    end
    veafCampaignEconomy.earnBy(
      ok and pilot or nil,
      veafCampaign.setting("economy", "warehouse_delivery"),
      "campaign.credits.warehouse",
      zone.name
    )
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

--- The campaign's state in one line, for the testing period's log: each side's stock, production, zones,
--- deliveries on their way, flights up and raid out, and the players' credits.
function veafCampaignLogistics.statusText()
  local parts = {}
  for _, side in ipairs(SIDE_NAMES) do
    local zones = 0
    for _, zone in ipairs(veafCampaign.zoneList) do
      if zone.placed and zone.entry.owner == side then
        zones = zones + 1
      end
    end
    local flights = veafCampaignOps and veafCampaignOps.flightsUp and veafCampaignOps.flightsUp(side) or 0
    local raid = veafCampaignOps and veafCampaignOps.raidUnderway and veafCampaignOps.raidUnderway(side)
    table.insert(
      parts,
      string.format(
        "%s: %d zones, stock %d (+%d/h), %d deliveries, %d flights up, raid %s",
        side,
        zones,
        math.floor(veafCampaignLogistics.stock(side)),
        math.floor(veafCampaignLogistics.productionPerHour(side)),
        veafCampaignLogistics.deliveriesUnderway(side),
        flights,
        raid and ("on " .. raid.target) or "none"
      )
    )
  end
  local credits = veafCampaignEconomy and veafCampaignEconomy.credits or 0
  return table.concat(parts, " | ") .. string.format(" | players' credits %d", math.floor(credits))
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
  if veafCampaign.debugging() and now >= (veafCampaignLogistics.nextStatus or 0) then
    veafCampaignLogistics.nextStatus = now + veafCampaign.setting("debug_status_seconds")
    veafCampaign.debug("STATUS", "%s", veafCampaignLogistics.statusText())
  end
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
  veafCampaignLogistics.lastBeat, veafCampaignLogistics.nextStatus = nil, nil
  veafCampaignLogistics.counters = {
    refused = {},
    spent = {},
    produced = {},
    ordered = 0,
    arrived = 0,
    lost = 0,
    unneeded = 0,
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
  if veafCommands then
    veafCommands.markerPolicy = veafCampaignLogistics.markerPolicy
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
