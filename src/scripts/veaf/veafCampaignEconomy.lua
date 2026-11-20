------------------------------------------------------------------
-- VEAF persistent campaign: credits, shop, task board, intelligence
-- By Zip (2026)
--
-- Features (FEAT-DYNAMIC-CAMPAIGN tickets 06 to 08):
-- ---------
-- * Coalition credits for the players' side, earned by kills, captures, deliveries and tasks.
-- * A small shop of effects VEAF already has: JTAC drone, illumination, smoke, friendly CAP, tanker,
--   intel, a capture helicopter, a resupply helicopter.
-- * A task board of a few tasks drawn from the situation, each with a map mark and a reward.
-- * Intelligence: the players do not see an enemy garrison's strength until they reveal it — an
--   overflight, a JTAC drone, bought intel, or a CTLD 2 spy team walking into the zone.
-- * In the V1.5: a bomber raid in the shop, and an intercept task when the enemy's bombers are out
--   (ticket 17).
--
-- Runs inside veafCampaign's single loop, and only in a persistent campaign.
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------
veafCampaignEconomy = {}

--- Identifier. All output in DCS.log will start with this.
veafCampaignEconomy.Id = "CAMPAIGNECO"

-- trace level, specific to this module
--veafCampaignEconomy.LogLevel = "trace"
veaf.loggers.new(veafCampaignEconomy.Id, veafCampaignEconomy.LogLevel)

--- What each shop item costs when `economy.prices` does not say.
veafCampaignEconomy.PRICES = {
  jtac = 300,
  illumination = 50,
  smoke = 50,
  cap = 400,
  barcap = 400,
  tanker = 300,
  intel = 150,
  capture = 250,
  resupply = 200,
  bomber = 1300, -- the raid package without escort, 220 points at 6 credits a point (David, 2026-11-16)
  assault = 300, -- the players' assault order (Campaign > Assault), a purchase in a persistent campaign
  escort = 300, -- two fighters covering the buyer's own group, helicopter or airplane (David, 2026-11-16)
  -- an AI attack flight against an enemy zone, next to the CAP's 400 (FEAT-CAMPAIGN-SHOP-UPGRADES 02); estimates
  cas = 500,
  sead = 600,
}

--- The zone upgrades (FEAT-CAMPAIGN-SHOP-UPGRADES 01, after Foothold's): a group bought on one of the players' zones,
--- which joins its garrison. Each is a group of veaf-units.yaml (`group`), or drawn as the garrison draws its own
--- (`draw`), or a list of DCS types (`units`); `eras` the eras it is offered in, all of them when absent; `once` at
--- most one per zone. Service dates as `veafCasMission.LONG_RANGE_AIR_DEFENSE_GROUPS` takes them, the 1980 reference
--- for the cold war: no Patriot (1984), NASAMS or Avenger then. Its price is its units' spawn price, in credits: one
--- rule (FIX-CAMPAIGN-ECONOMY-BALANCE 05), which `veafCampaign.TYPE_PRICES` sets near Foothold's prices.
veafCampaignEconomy.UPGRADES = {
  { id = "hawk", group = "hawk", eras = { veaf.ERA.COLD_WAR, veaf.ERA.MODERN } },
  { id = "nasams", group = "nasams", eras = { veaf.ERA.MODERN } },
  { id = "patriot", group = "patriot", eras = { veaf.ERA.MODERN }, once = true },
  { id = "avenger", group = "avenger_squad", eras = { veaf.ERA.MODERN } },
  -- veaf-units.yaml has no group of its own for the Gepard: the platoon the blue air defence groups carry
  { id = "gepard", units = { "Gepard", "Gepard", "Gepard", "M 818" }, eras = { veaf.ERA.COLD_WAR, veaf.ERA.MODERN } },
  { id = "infantry", draw = "infantry" },
  { id = "armor", draw = "armor" },
}

--- The size and armour levels of `veafCasMission`'s generators an infantry section and an armour platoon are
--- drawn at: a garrison's middle class, with no air defence of its own (the air defence is bought apart).
veafCampaignEconomy.UPGRADE_DRAW = { defense = 0, armor = 3 }

--- How often an escort covering a helicopter moves its circle over it, in seconds, and how far the
--- helicopter must have gone for the circle to move, in metres.
veafCampaignEconomy.ESCORT_FOLLOW_SECONDS = 60
veafCampaignEconomy.ESCORT_FOLLOW_DISTANCE = 8000

--- The shop's items, in the menu's order, with the zones each applies to: "enemy", "own", "neutral",
--- "any", or none for an item that needs no zone.
veafCampaignEconomy.ITEMS = {
  { id = "jtac", zones = "enemy" },
  { id = "illumination", zones = "any" },
  { id = "smoke", zones = "enemy" },
  { id = "intel", zones = "enemy" },
  { id = "cap", zones = "own" },
  { id = "barcap", zones = "enemy" },
  { id = "capture", zones = "neutral" },
  { id = "resupply", zones = "own" },
  { id = "bomber", zones = "enemy" },
  { id = "cas", zones = "enemy" },
  { id = "sead", zones = "enemy" },
  { id = "escort" },
  { id = "tanker" },
}

--- What a task is worth when `tasks.rewards` does not say.
veafCampaignEconomy.REWARDS = { attack = 300, capture = 300, resupply = 200, air = 200, intercept = 400 }

--- The laser code and frequency of a JTAC drone bought in the shop.
veafCampaignEconomy.JTAC_CODE = 1688

--- The players' side's credits.
veafCampaignEconomy.credits = 0

--- The task board: `{ kind, zone, reward, markId, kills }`.
veafCampaignEconomy.tasks = {}

--- The spy teams under way, by group name: `{ zone, revealed }`.
veafCampaignEconomy.spies = {}

veafCampaignEconomy.counters = {}

local function logger()
  return veaf.loggers.get(veafCampaignEconomy.Id)
end

local function playerCoalition()
  return veafCampaign.SIDES[veafCampaign.playerSide()]
end

local function tell(key, ...)
  trigger.action.outTextForCoalition(playerCoalition(), veaf.t(key, ...), 15)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Credits (ticket 06)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What each pilot has earned, by player name: `{ total, reasons = { [reason] = credits } }`, kept in the save for
--- the debrief (FIX-CAMPAIGN-SECOND-SERVER-FLIGHT 10: 400 credits earned around 21:35 on 2026-11-17 could not
--- be told to anyone). The gains nobody flew for (a capture, a task, a delivery by the network) go to `TEAM`.
veafCampaignEconomy.pilots = {}

--- The gains since the last summary of the session, by pilot; nil when there are none.
veafCampaignEconomy.sessionGains = nil

--- Who a gain nobody flew for is written against.
veafCampaignEconomy.TEAM = "team"

--- The ranking figure a gain of that reason counts one more of, by Foothold's name (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 03).
veafCampaignEconomy.STAT_OF_REASON = { warehouse = "Warehouse delivery" }

--- A pilot's books, made when it has none: `{ total, reasons, stats }`, `stats` the ranking's figures by Foothold's
--- names (`Air`, `Deaths`…). A save written before them has none.
local function booksOf(who)
  local books = veafCampaignEconomy.pilots[who] or { total = 0, reasons = {} }
  books.stats = books.stats or {}
  veafCampaignEconomy.pilots[who] = books
  return books
end

--- Count one more of a ranking figure for a pilot.
--- @param pilot string|nil the player's name; nothing is counted without one
--- @param stat string the figure, by Foothold's name
function veafCampaignEconomy.count(pilot, stat)
  if not pilot then
    return
  end
  local stats = booksOf(pilot).stats
  stats[stat] = (stats[stat] or 0) + 1
end

--- Add credits (or take them, with a negative amount; never below zero), and tell the side. A gain pays a debt
--- off before it adds anything: a balance of -50 earning 10 is -40 (ticket 14).
--- @param amount number
--- @param reasonKey string|nil the i18n key of why, nil to say nothing
function veafCampaignEconomy.earn(amount, reasonKey, ...)
  veafCampaignEconomy.earnBy(nil, amount, reasonKey, ...)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- An evening's balance (FIX-CAMPAIGN-ECONOMY-BALANCE 03)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The session's books, to tune the prices from the log: what each account earned and spent, by kind, from the first
--- beat a player sits in a slot to the session's summary; nil while closed. By account — `credits`, the players' side's,
--- and each side's resources when they are counted (by the side's name) —: `{ start, earned = { [kind] = { amount,
--- count } }, spent = { … } }`; `order` the accounts, `openedAt` the mission time it opened. Not saved.
veafCampaignEconomy.ledger = nil

--- Whether the sides' resources are counted (a persistent campaign's logistics).
local function resourcesCounted()
  return veafCampaignLogistics ~= nil and veafCampaignLogistics.active == true
end

local function balanceOf(account)
  if account == "credits" then
    return veafCampaignEconomy.credits
  end
  return veafCampaignLogistics.stock(account)
end

--- Open the session's books at the balances of now: the players' credits, then the enemy's resources and the players'
--- side's own, when they are counted.
function veafCampaignEconomy.openLedger()
  local accounts = { "credits" }
  if resourcesCounted() then
    local own = veafCampaign.playerSide()
    table.insert(accounts, veafCampaign.enemyOf(own))
    table.insert(accounts, own)
  end
  local ledger = { order = accounts, openedAt = timer.getTime() }
  for _, account in ipairs(accounts) do
    ledger[account] = { start = balanceOf(account), earned = {}, spent = {} }
  end
  veafCampaignEconomy.ledger = ledger
end

--- Write a flow in the session's books, when they are open.
--- @param account string "credits", or a side's name for its resources
--- @param direction string "earned" or "spent"
--- @param kind string what for: `capture`, `kill_air`, `shop cap`, `upgrade hawk`, `spawn`, `production`, `flight`…
--- @param amount number
--- @param uncounted boolean|nil true for a flow that is not one event: the production, a kill's held share
function veafCampaignEconomy.book(account, direction, kind, amount, uncounted)
  local books = veafCampaignEconomy.ledger and veafCampaignEconomy.ledger[account]
  if not books or not amount or amount <= 0 then
    return
  end
  local entry = books[direction][kind] or { amount = 0, count = 0 }
  entry.amount = entry.amount + amount
  if not uncounted then
    entry.count = entry.count + 1
  end
  books[direction][kind] = entry
end

--- One direction of an account, for its summary line: the total, and each kind, the largest first.
local function flowText(entries)
  local kinds, total = {}, 0
  for kind, entry in pairs(entries) do
    table.insert(kinds, kind)
    total = total + entry.amount
  end
  table.sort(kinds, function(a, b)
    if entries[a].amount ~= entries[b].amount then
      return entries[a].amount > entries[b].amount
    end
    return a < b
  end)
  local parts = {}
  for _, kind in ipairs(kinds) do
    local entry = entries[kind]
    local count = entry.count > 0 and string.format(" (x%d)", entry.count) or ""
    table.insert(parts, string.format("%s %d%s", kind, math.floor(entry.amount + 0.5), count))
  end
  return math.floor(total + 0.5), #parts > 0 and table.concat(parts, ", ") or "nothing"
end

--- Write the session's books as one block of `ECONOMY SUMMARY` lines, and close them.
local function summarizeLedger(why)
  local ledger = veafCampaignEconomy.ledger
  veafCampaignEconomy.ledger = nil
  local minutes = math.floor((timer.getTime() - ledger.openedAt) / 60 + 0.5)
  logger():info("ECONOMY SUMMARY (%s): %d min of play", why, minutes)
  for _, account in ipairs(ledger.order) do
    local books = ledger[account]
    local label = account == "credits" and (veafCampaign.playerSide() .. " credits") or (account .. " resources")
    local start, finish = math.floor(books.start + 0.5), math.floor(balanceOf(account) + 0.5)
    logger():info("ECONOMY SUMMARY %s: %d at the start, %d at the end", label, start, finish)
    logger():info("ECONOMY SUMMARY %s earned %d: %s", label, flowText(books.earned))
    logger():info("ECONOMY SUMMARY %s spent %d: %s", label, flowText(books.spent))
  end
end

--- `earn`, written against a pilot: one `CREDITS` line in dcs.log per gain, and the pilot's totals.
--- @param pilot string|nil the player's name; nil for a gain of the whole side
--- @param amount number
--- @param reasonKey string|nil the i18n key of why
function veafCampaignEconomy.earnBy(pilot, amount, reasonKey, ...)
  veafCampaignEconomy.earnAs(nil, pilot, amount, reasonKey, ...)
end

--- `earnBy`, with the kind the session's books write it under when it is not its reason: a kill's reward
--- (`kill_air`…), or the kinds a landing banks, `{ [kind] = credits }`.
--- @param kind string|table|nil
--- @param pilot string|nil
--- @param amount number
--- @param reasonKey string|nil
function veafCampaignEconomy.earnAs(kind, pilot, amount, reasonKey, ...)
  if amount < 0 then
    veafCampaignEconomy.credits = math.max(0, veafCampaignEconomy.credits + amount)
  else
    veafCampaignEconomy.credits = veafCampaignEconomy.credits + amount
  end
  if amount > 0 then
    local who = pilot or veafCampaignEconomy.TEAM
    local reason = reasonKey and (reasonKey:gsub("^campaign%.credits%.", "")) or "other"
    local books = booksOf(who)
    books.total = books.total + amount
    books.reasons[reason] = (books.reasons[reason] or 0) + amount
    if pilot and veafCampaignEconomy.STAT_OF_REASON[reason] then
      veafCampaignEconomy.count(pilot, veafCampaignEconomy.STAT_OF_REASON[reason])
    end
    veafCampaignEconomy.sessionGains = veafCampaignEconomy.sessionGains or {}
    veafCampaignEconomy.sessionGains[who] = (veafCampaignEconomy.sessionGains[who] or 0) + amount
    logger():info("CREDITS %s +%d (%s): %d for the side", who, amount, reason, veafCampaignEconomy.credits)
    if type(kind) == "table" then
      for each, credits in pairs(kind) do
        veafCampaignEconomy.book("credits", "earned", each, credits, true)
      end
    else
      veafCampaignEconomy.book("credits", "earned", kind or reason, amount)
    end
  end
  if reasonKey and amount ~= 0 then
    tell("campaign.credits.earned", amount, veaf.t(reasonKey, ...), veafCampaignEconomy.credits)
  end
end

--- Write who earned what since the last summary: one `CREDITS SUMMARY` line per pilot, best first, and the side's
--- total; then the session's books, earned and spent by kind for both sides (`ECONOMY SUMMARY`), when a player sat in a
--- slot. Said at the mission's end, and when nobody is left in a slot.
--- @param why string what ends the session
--- @return boolean whether there was anything to say
function veafCampaignEconomy.summarizeSession(why)
  local said = veafCampaignEconomy.summarizeGains(why)
  if veafCampaignEconomy.ledger then
    summarizeLedger(why)
    said = true
  end
  return said
end

--- The `CREDITS SUMMARY` lines of `summarizeSession`.
--- @param why string what ends the session
--- @return boolean whether there was anything to say
function veafCampaignEconomy.summarizeGains(why)
  local gains = veafCampaignEconomy.sessionGains
  if not gains then
    return false
  end
  local names, total = {}, 0
  for name, amount in pairs(gains) do
    table.insert(names, name)
    total = total + amount
  end
  table.sort(names, function(a, b)
    if gains[a] ~= gains[b] then
      return gains[a] > gains[b]
    end
    return a < b
  end)
  logger():info("CREDITS SUMMARY (%s): %d earned by the side, %d for the side now", why, total, veafCampaignEconomy.credits)
  for _, name in ipairs(names) do
    local books = veafCampaignEconomy.pilots[name]
    logger():info("CREDITS SUMMARY %s: %d this session, %d in the campaign", name, gains[name], books and books.total or gains[name])
  end
  veafCampaignEconomy.sessionGains = nil
  return true
end

--- Whether a player sits in a slot of either side.
local function anyPlayer()
  for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
    local ok, players = pcall(coalition.getPlayers, side)
    if ok and type(players) == "table" and #players > 0 then
      return true
    end
  end
  return false
end

--- What each pilot's aircraft holds until it lands, by unit name: `{ player, amount }`. Not saved: like the aircraft,
--- it does not outlive a restart.
veafCampaignEconomy.held = {}

--- The name of an event's initiator, from the data table veafEventHandler makes or the DCS object.
local function initiatorName(event)
  local name = event and event.initiator and event.initiator.unitName
  if name == nil and event and event.dcsInitiator and event.dcsInitiator.getName then
    local ok, value = pcall(event.dcsInitiator.getName, event.dcsInitiator)
    name = ok and value or nil
  end
  return name
end

--- What the credits a pilot held were when he ejected, by unit name: the sitac shows them next to the pilot on the
--- ground (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 04). Lost at the ejection: a rescue does not give them back. Not saved.
veafCampaignEconomy.lostAtEjection = {}

--- Whether a DCS unit has an attribute; false when it cannot be asked.
local function hasAttribute(unit, attribute)
  if not (unit and unit.hasAttribute) then
    return false
  end
  local ok, value = pcall(unit.hasAttribute, unit, attribute)
  return ok and value == true
end

--- The ranking figure a kill counts under, by Foothold's name: `Air`, `Helo`, `Infantry`, `SAM` or `Ground Units`.
--- @param kill table what `veafCampaign.readPlayerKill` read
--- @param target table the event's target, as veafEventHandler hands it
--- @return string
function veafCampaignEconomy.killStat(kill, target)
  if kill.category == Unit.Category.AIRPLANE then
    return "Air"
  elseif kill.category == Unit.Category.HELICOPTER then
    return "Helo"
  end
  local unit = target and target.unitName and Unit.getByName(target.unitName)
  if hasAttribute(unit, "Infantry") then
    return "Infantry"
  elseif hasAttribute(unit, "SAM related") or hasAttribute(unit, "Air Defence") then
    return "SAM"
  end
  return "Ground Units"
end

--- The `economy` setting a kill pays, by its ranking figure (FIX-CAMPAIGN-ECONOMY-BALANCE 01, Foothold's rewards);
--- `kill_ground` for any other.
veafCampaignEconomy.REWARD_OF_STAT = { Air = "kill_air", Helo = "kill_air", SAM = "kill_sam", Structure = "kill_building" }

--- A building of a campaign zone the enemy holds, destroyed by a player of the players' side: one more `Structure`.
--- veafEventHandler cannot read a static object's side, so `readPlayerKill` never sees it.
--- @return string|nil the player, when it is one
local function countStructure(event)
  local name = event and event.target and event.target.unitName
  local building = name and veafCampaign.structureIndex and veafCampaign.structureIndex[name]
  if not building then
    return nil
  end
  local unit, player = veafCampaign.playerUnitOf(event)
  if not player then
    return nil
  end
  local own = veafCampaign.playerSide()
  local ok, side = pcall(unit.getCoalition, unit)
  if ok and side == veafCampaign.SIDES[own] and building.zone.entry.owner ~= own then
    veafCampaignEconomy.count(player, "Structure")
    return player
  end
  return nil
end

--- Pay a pilot's kill: `economy.landing_share` of its credits is held until the pilot lands at a friendly airfield,
--- FARP or carrier (`onPilotEvent`); the rest is earned at once.
--- @param event table the S_EVENT_KILL
--- @param player string
--- @param stat string the kill's ranking figure, which says its reward (`REWARD_OF_STAT`)
local function payKill(event, player, stat)
  local kind = veafCampaignEconomy.REWARD_OF_STAT[stat] or "kill_ground"
  local amount = veafCampaign.setting("economy", kind)
  local share = math.max(0, math.min(100, veafCampaign.setting("economy", "landing_share") or 0))
  local unitName = initiatorName(event)
  local held = unitName and math.floor(amount * share / 100 + 0.5) or 0
  if held > 0 then
    local books = veafCampaignEconomy.held[unitName] or { player = player, amount = 0, kinds = {} }
    books.amount = books.amount + held
    books.kinds[kind] = (books.kinds[kind] or 0) + held
    veafCampaignEconomy.held[unitName] = books
    veafCampaignEconomy.earnAs(kind, player, amount - held, "campaign.credits.kill_held", player, books.amount)
  else
    veafCampaignEconomy.earnAs(kind, player, amount, "campaign.credits.kill", player)
  end
end

--- A kill: a player of the players' side destroyed an enemy unit, or a building of a zone the enemy holds.
function veafCampaignEconomy.onKill(event)
  if not veafCampaign.over then
    local player = countStructure(event)
    if player then
      payKill(event, player, "Structure")
    end
  end
  local kill = veafCampaign.readPlayerKill(event)
  if veafCampaign.over or not kill then
    return
  end
  local stat = veafCampaignEconomy.killStat(kill, event.target)
  veafCampaignEconomy.count(kill.player, stat)
  payKill(event, kill.player, stat)
  if kill.air then
    for _, task in ipairs(veafCampaignEconomy.tasks) do
      if task.kind == "air" then
        task.kills = task.kills + 1
      end
    end
  end
end

--- Whether an aircraft landed at a place of the players' side: an airfield, a FARP or a ship. veafEventHandler's data
--- table says an airbase is neutral (it reads `Unit.getByName`), so the airbase is asked first.
local function friendlyPlace(event)
  local name = event and event.place and event.place.unitName
  if not name then
    return false -- a landing in the open banks nothing
  end
  local side = nil
  for _, lookup in ipairs({ Airbase.getByName, Unit.getByName }) do
    local ok, object = pcall(lookup, name)
    if ok and object and object.getCoalition then
      side = object:getCoalition()
      break
    end
  end
  return side ~= nil and side == playerCoalition()
end

--- What happens to the credits a pilot's aircraft holds: earned when it lands at a friendly airfield, FARP or carrier,
--- lost when the pilot ejects, dies, crashes or leaves the aircraft.
function veafCampaignEconomy.onPilotEvent(event)
  local id = event and (event.type and event.type.id or event.id)
  if id == world.event.S_EVENT_PILOT_DEAD then
    local unit, player = veafCampaign.playerUnitOf(event)
    local ok, side = false, nil
    if player then
      ok, side = pcall(unit.getCoalition, unit)
    end
    if ok and side == veafCampaign.SIDES[veafCampaign.playerSide()] then
      veafCampaignEconomy.count(player, "Deaths")
    end
  end
  local unitName = initiatorName(event)
  local books = unitName and veafCampaignEconomy.held[unitName]
  if not books then
    return
  end
  if id == world.event.S_EVENT_LAND then
    if friendlyPlace(event) then
      veafCampaignEconomy.held[unitName] = nil
      veafCampaignEconomy.earnAs(books.kinds, books.player, books.amount, "campaign.credits.landed", books.player)
    end
    return
  end
  veafCampaignEconomy.held[unitName] = nil
  if id == world.event.S_EVENT_EJECTION then
    veafCampaignEconomy.lostAtEjection[unitName] = books.amount
  end
  logger():info("%s loses the %d credits held in [%s]", tostring(books.player), books.amount, unitName)
  veafCampaign.announce(
    veafCampaign.playerSide(),
    veafCampaign.playerSide(),
    veaf.t("campaign.credits.held_lost", books.player, books.amount)
  )
end

--- Pay a pilot of the players' side for the downed pilots his helicopter has just delivered to a MASH: `economy.rescue`
--- each, in full — he is on the ground already (FIX-CAMPAIGN-ECONOMY-BALANCE 01, Foothold's 200). The AI's rescues pay
--- nothing.
--- @param heli table the helicopter, as the CSAR module hands it to `csar.rescuePilots`
--- @param pilots number the downed pilots it carried
local function payRescue(heli, pilots)
  if pilots == 0 or veafCampaign.over then
    return
  end
  local okPlayer, player = pcall(heli.getPlayerName, heli)
  local okSide, side = pcall(heli.getCoalition, heli)
  if not (okPlayer and player and okSide and side == playerCoalition()) then
    return
  end
  veafCampaignEconomy.earnBy(player, pilots * veafCampaign.setting("economy", "rescue"), "campaign.credits.rescue", player, pilots)
end

--- Pay the CSAR rescues: wrap the CSAR module's `csar.rescuePilots`, which delivers a helicopter's downed pilots once it
--- has landed by a MASH, and empties `csar.inTransitGroups` for it. Wrapped once, however often it is called.
--- @return boolean whether the CSAR module is there to watch
function veafCampaignEconomy.watchRescues()
  if not (csar and type(csar.rescuePilots) == "function") then
    logger():info("no CSAR module: a rescue pays nothing")
    return false
  end
  if csar.rescuePilots == veafCampaignEconomy.rescueWrapper then
    return true
  end
  local deliver = csar.rescuePilots
  veafCampaignEconomy.rescueWrapper = function(heli)
    local okName, name = pcall(heli.getName, heli)
    local carried = okName and type(csar.inTransitGroups) == "table" and csar.inTransitGroups[name]
    local pilots = 0
    for _ in pairs(type(carried) == "table" and carried or {}) do
      pilots = pilots + 1
    end
    deliver(heli)
    payRescue(heli, pilots)
  end
  csar.rescuePilots = veafCampaignEconomy.rescueWrapper
  return true
end

--- Take a price from the credits for a purchase made outside the shop — the assault order: refused, and
--- told, when the side cannot pay.
--- @param price number
--- @param label string what is bought, as the players read it
--- @param kind string|nil what the session's books write it under, `purchase` when nil
--- @return boolean whether it was paid
function veafCampaignEconomy.charge(price, label, kind)
  if veafCampaignEconomy.credits < price then
    tell("campaign.shop.too_expensive", label, price, veafCampaignEconomy.credits)
    return false
  end
  veafCampaignEconomy.credits = veafCampaignEconomy.credits - price
  veafCampaignEconomy.book("credits", "spent", kind or "purchase", price)
  veafCampaignEconomy.counters.purchases = veafCampaignEconomy.counters.purchases + 1
  tell("campaign.shop.bought", label, "-", price, veafCampaignEconomy.credits)
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Intelligence (ticket 08)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Reveal an enemy zone to the players' side for a while: its strength on the map, its composition in
--- the Intel menu.
--- @param zone table
--- @param seconds number|nil the default is `intel.seconds`
--- @param how string the i18n key's last part: "overflight", "jtac", "purchase", "spy"
function veafCampaignEconomy.reveal(zone, seconds, how)
  local now = timer.getTime()
  local already = (zone.revealedUntil or 0) > now
  zone.revealedUntil = math.max(zone.revealedUntil or 0, now + (seconds or veafCampaign.setting("intel", "seconds")))
  zone:draw()
  if not already then
    veafCampaignEconomy.counters.reveals = veafCampaignEconomy.counters.reveals + 1
    tell("campaign.intel.revealed", veafCampaign.zoneTitle(zone.name), veaf.t("campaign.intel.by_" .. how))
    logger():info("zone [%s] revealed by %s", zone.name, how)
  end
end

--- The composition of a zone's live garrison, air defence first: one line per type, with its count.
function veafCampaignEconomy.compositionText(zone)
  local counts, order = {}, {}
  for _, group in ipairs(zone.entry.garrison or {}) do
    for _, unit in ipairs(group.units) do
      if unit.alive then
        if not counts[unit.type] then
          counts[unit.type] = 0
          table.insert(order, unit.type)
        end
        counts[unit.type] = counts[unit.type] + 1
      end
    end
  end
  table.sort(order, function(a, b)
    local airA = veafCampaign.reserveCategory(a) == "air_defense"
    local airB = veafCampaign.reserveCategory(b) == "air_defense"
    if airA ~= airB then
      return airA
    end
    return a < b
  end)
  local lines = { veaf.t("campaign.intel.report", veafCampaign.zoneTitle(zone.name), zone:strengthPercent()) }
  for _, typeName in ipairs(order) do
    table.insert(lines, string.format("- %s x%d", typeName, counts[typeName]))
  end
  return table.concat(lines, "\n")
end

--- Radio command: what is known of the enemy zones revealed now.
function veafCampaignEconomy.reportIntel()
  local reports = {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == veafCampaign.enemyOf(veafCampaign.playerSide()) and veafCampaign.isRevealed(zone) then
      table.insert(reports, veafCampaignEconomy.compositionText(zone))
    end
  end
  if #reports == 0 then
    table.insert(reports, veaf.t("campaign.intel.none"))
  end
  trigger.action.outTextForCoalition(playerCoalition(), table.concat(reports, "\n\n"), 30)
end

--- An overflight reveals an awake enemy zone: a player aircraft of the side within its circle, lower than
--- `intel.overflight_altitude` above the ground.
function veafCampaignEconomy.checkOverflights()
  local players = coalition.getPlayers(playerCoalition()) or {}
  if #players == 0 then
    return
  end
  local ceiling = veafCampaign.setting("intel", "overflight_altitude")
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.awake and veafCampaign.hidesFrom(zone, veafCampaign.playerSide()) then
      local center = zone:getCenter()
      for _, unit in ipairs(players) do
        if unit and unit:isExist() then
          local point = unit:getPoint()
          local inside = (point.x - center.x) ^ 2 + (point.z - center.z) ^ 2 <= (zone.entry.radius or 2000) ^ 2
          if inside and point.y - land.getHeight({ x = point.x, y = point.z }) <= ceiling then
            veafCampaignEconomy.reveal(zone, nil, "overflight")
            break
          end
        end
      end
    end
  end
end

--- Spy teams: a CTLD 2 troop group of the `intel.spy_troops` template, deployed by the players' side,
--- walks to the nearest enemy zone within `intel.spy_range`, and reveals it on arrival.
function veafCampaignEconomy.followSpies()
  if not (CTLDTroopManager and CTLDTroopManager.getInstance) then
    return
  end
  local ok, manager = pcall(CTLDTroopManager.getInstance)
  local dropped = ok and manager and manager._droppedGroups and manager._droppedGroups[playerCoalition()]
  if not dropped then
    return
  end
  local template = veafCampaign.setting("intel", "spy_troops")
  for _, groupName in ipairs(dropped) do
    if veafCampaign.ctldTroopTemplate(groupName) == template then
      veafCampaignEconomy.followSpy(groupName)
    end
  end
end

--- Follow one spy team: send it on its way the first time it is seen, reveal its zone when it is there.
function veafCampaignEconomy.followSpy(groupName)
  local group = Group.getByName(groupName)
  local unit = group and group:isExist() and group:getUnits()[1]
  if not unit then
    return
  end
  local point = unit:getPoint()
  local spy = veafCampaignEconomy.spies[groupName]
  if not spy then
    local enemy, best, bestDistance = veafCampaign.enemyOf(veafCampaign.playerSide()), nil, nil
    for _, zone in ipairs(veafCampaign.zoneList) do
      if zone.placed and zone.entry.owner == enemy then
        local center = zone:getCenter()
        local d = math.sqrt((center.x - point.x) ^ 2 + (center.z - point.z) ^ 2)
        if d <= veafCampaign.setting("intel", "spy_range") + (zone.entry.radius or 2000) and (not bestDistance or d < bestDistance) then
          best, bestDistance = zone, d
        end
      end
    end
    spy = { zone = best and best.name }
    veafCampaignEconomy.spies[groupName] = spy
    if not best then
      tell("campaign.intel.spy_no_zone", veafCampaign.setting("intel", "spy_range") / 1000)
      return
    end
    local center = best:getCenter()
    local route = {
      { x = point.x, y = point.z, type = "Turning Point", action = "Off Road", speed = 5 },
      { x = center.x, y = center.z, type = "Turning Point", action = "Off Road", speed = 5 },
    }
    group:getController():setTask({ id = "Mission", params = { route = { points = route } } })
    tell("campaign.intel.spy_sent", best.name)
    return
  end
  local zone = spy.zone and veafCampaign.zones[spy.zone]
  if zone and not spy.revealed then
    local center = zone:getCenter()
    if (point.x - center.x) ^ 2 + (point.z - center.z) ^ 2 <= (zone.entry.radius or 2000) ^ 2 then
      spy.revealed = true
      veafCampaignEconomy.counters.spies = veafCampaignEconomy.counters.spies + 1
      veafCampaignEconomy.reveal(zone, 3600, "spy")
    end
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Shop (ticket 06)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What an item costs.
function veafCampaignEconomy.price(itemId)
  local prices = veafCampaign.setting("economy", "prices") or {}
  return prices[itemId] or veafCampaignEconomy.PRICES[itemId]
end

--- Whether a zone suits an item's `zones` rule.
--- The tankers the shop sells: `economy.tanker`, one name or a list of names (a boom and a basket).
--- @return table the names
function veafCampaignEconomy.tankers()
  local setting = veafCampaign.setting("economy", "tanker")
  if type(setting) == "string" then
    return { setting }
  end
  return type(setting) == "table" and setting or {}
end

--- How each tanker type refuels (`veaf_libs/tankers.py` holds the same lists): the KC-10 does both.
veafCampaignEconomy.BOOM_TANKERS = { ["KC-135"] = true, ["KC-10A"] = true }
veafCampaignEconomy.BASKET_TANKERS = {
  ["KC135MPRS"] = true,
  ["KC130"] = true,
  ["KC130J"] = true,
  ["S-3B Tanker"] = true,
  ["IL-78M"] = true,
  ["KC-10A"] = true,
}

--- A tanker's name and how it refuels, "Tanker Arco (panier)" (David, 2026-11-17); the name alone when its
--- group is not in the mission or its type is no tanker known here.
function veafCampaignEconomy.tankerTitle(name)
  local group = Group.getByName(name)
  local unit = group and group.getUnit and group:getUnit(1)
  local typeName = unit and unit:getTypeName()
  local boom, basket = veafCampaignEconomy.BOOM_TANKERS[typeName], veafCampaignEconomy.BASKET_TANKERS[typeName]
  local kind = (boom and basket and "both") or (boom and "boom") or (basket and "basket")
  if not kind then
    return name
  end
  return string.format("%s (%s)", name, veaf.t("tanker.kind." .. kind))
end

local function zoneSuits(rule, zone)
  local own, owner = veafCampaign.playerSide(), zone.entry.owner
  return (rule == "any")
    or (rule == "own" and owner == own)
    or (rule == "neutral" and owner == "neutral")
    or (rule == "enemy" and owner == veafCampaign.enemyOf(own))
end

--- A CAS or SEAD flight of the players' side against an enemy zone (FEAT-CAMPAIGN-SHOP-UPGRADES 02): the enemy AI's own
--- strike (`veafCampaignOps.spawnStrike`), from the side's airfield nearest the zone that the role may take off from.
--- One flight of each kind in the air at a time, as Foothold.
--- @param zone table the enemy zone
--- @param role string "cas" or "sead"
--- @return boolean whether it was sent
--- @return string the i18n key of why not
local function sendStrike(zone, role)
  local side = veafCampaign.playerSide()
  if veafCampaignOps.flightsUp(side, role) > 0 then
    return false, "campaign.shop.refused_flight_up"
  end
  local origin = veafCampaignOps.nearestOwnZone(side, zone, true, role)
  if not origin then
    return false, "campaign.shop.refused_no_airfield"
  end
  local spawned = veafCampaignOps.spawnStrike(side, role, zone, origin)
  if spawned then
    tell("campaign.shop.strike", veaf.t("campaign.shop.item." .. role), origin.name, veafCampaign.zoneTitle(zone.name))
  end
  return spawned ~= nil, "campaign.shop.refused_spawn"
end

--- What each item does. Each returns true when done, or false and the i18n key of why not; a refusal
--- costs nothing.
veafCampaignEconomy.effects = {
  jtac = function(zone)
    local center = zone:getCenter()
    local spawned = veafSpawn.spawnAFAC(
      { x = center.x, y = land.getHeight({ x = center.x, y = center.z }), z = center.z },
      "mq9",
      veaf.getCountryForCoalition(playerCoalition()),
      nil,
      nil,
      nil,
      veafSpawn.convertLaserToFreq(veafCampaignEconomy.JTAC_CODE),
      "FM",
      veafCampaignEconomy.JTAC_CODE,
      true,
      false,
      false
    )
    if not spawned then
      return false, "campaign.shop.refused_jtac"
    end
    veafCampaignEconomy.reveal(zone, nil, "jtac")
    return true
  end,
  illumination = function(zone)
    local center = zone:getCenter()
    veafSpawn.spawnIlluminationFlare({ x = center.x, y = land.getHeight({ x = center.x, y = center.z }), z = center.z }, 500, 4)
    return true
  end,
  smoke = function(zone)
    local placed = 0
    for _, group in ipairs(zone.entry.garrison or {}) do
      for _, unit in ipairs(group.units) do
        if unit.alive and placed < 3 then
          placed = placed + 1
          veafSpawn.spawnSmoke({ x = unit.x, y = land.getHeight({ x = unit.x, y = unit.z }), z = unit.z }, trigger.smokeColor.Red, 20)
        end
      end
    end
    if placed == 0 then
      return false, "campaign.shop.refused_nothing"
    end
    return true
  end,
  intel = function(zone)
    veafCampaignEconomy.reveal(zone, nil, "purchase")
    return true
  end,
  cap = function(zone)
    local side = veafCampaign.playerSide()
    local origin = veafCampaignOps.canTakeOffFrom(side, zone) and zone or veafCampaignOps.nearestOwnZone(side, zone, true)
    if not origin then
      return false, "campaign.shop.refused_no_airfield"
    end
    local center = zone:getCenter()
    local spawned = veafCampaignOps.spawnFlight(
      side,
      "cap",
      origin,
      "zone_defense",
      { zone = { x = center.x, y = center.z, radius = veafCampaignOps.CAP_RADIUS } },
      veafCampaignOps.CAP_ALTITUDE
    )
    return spawned ~= nil, "campaign.shop.refused_spawn"
  end,
  barcap = function(zone)
    local side = veafCampaign.playerSide()
    local station, origin, distance, reach, measured = veafCampaignOps.barcapStation(side, zone)
    if not station then
      return false, "campaign.shop.refused_no_airfield"
    end
    local spawned = veafCampaignOps.spawnFlight(side, "cap", origin, "zone_defense", { zone = station }, veafCampaignOps.CAP_ALTITUDE)
    if spawned then
      tell(
        measured and "campaign.shop.barcap" or "campaign.shop.barcap_assumed",
        zone.name,
        math.floor(distance / 1000),
        math.floor(reach / 1000),
        origin.name
      )
    end
    return spawned ~= nil, "campaign.shop.refused_spawn"
  end,
  capture = function(zone)
    local sent = veafCampaignOps.sendHelicopter(veafCampaign.playerSide(), zone, "capture")
    return sent ~= nil, "campaign.shop.refused_spawn"
  end,
  resupply = function(zone)
    if not zone:isDamaged() then
      return false, "campaign.shop.refused_nothing"
    end
    local sent = veafCampaignOps.sendHelicopter(veafCampaign.playerSide(), zone, "resupply")
    return sent ~= nil, "campaign.shop.refused_spawn"
  end,
  bomber = function(zone)
    local raid = veafCampaignOps.sendRaid(veafCampaign.playerSide(), zone, true)
    return raid ~= nil, "campaign.shop.refused_no_bomber"
  end,
  cas = function(zone)
    return sendStrike(zone, "cas")
  end,
  sead = function(zone)
    return sendStrike(zone, "sead")
  end,
  tanker = function(_, name)
    -- one item per tanker of `economy.tanker`: the boom and the basket are bought apart (David, 2026-11-17)
    local known = false
    for _, tanker in ipairs(veafCampaignEconomy.tankers()) do
      known = known or tanker == name
    end
    if not (known and veafAssets and veafAssets.respawn) then
      return false, "campaign.shop.refused_no_tanker"
    end
    -- back on its Mission Editor orbit, its group id unchanged: the SUPPORT module sees its units born again and
    -- places it out of reach
    veafAssets.respawn(name)
    return true
  end,
}

--- The players' airfield zone nearest a point that aircraft may leave from, or nil.
local function nearestAirfield(side, point)
  local best, bestDistance = nil, nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zone.entry.owner == side and zone.entry.airbase and veafCampaignOps.canTakeOffFrom(side, zone) then
      local center = zone:getCenter()
      local d = math.sqrt((center.x - point.x) ^ 2 + (center.z - point.z) ^ 2)
      if not bestDistance or d < bestDistance then
        best, bestDistance = zone, d
      end
    end
  end
  return best
end

--- Keep an escort's circle over the helicopter it covers: re-aimed when the helicopter has moved far enough,
--- until either group is gone.
function veafCampaignEconomy.followHelicopter(parameters)
  local escortName, escortedName, last = parameters[1], parameters[2], parameters[3]
  local escort, escorted = Group.getByName(escortName), Group.getByName(escortedName)
  if not (escort and escort:isExist() and escorted and escorted:isExist()) then
    logger():info("escort [%s] stops following [%s]", escortName, escortedName)
    return
  end
  local unit = escorted:getUnit(1)
  local point = unit and unit:getPoint()
  if point and math.sqrt((point.x - last.x) ^ 2 + (point.z - last.z) ^ 2) >= veafCampaignEconomy.ESCORT_FOLLOW_DISTANCE then
    local zone = { x = point.x, y = point.z, radius = veafCampaignOps.ESCORT_HELICOPTER_RADIUS }
    if veafAircraftSpawn.assignRole(escortName, "zone_defense", { zone = zone }) then
      last = { x = point.x, z = point.z }
    end
  end
  veaf.scheduleFunction(
    veafCampaignEconomy.followHelicopter,
    { escortName, escortedName, last },
    timer.getTime() + veafCampaignEconomy.ESCORT_FOLLOW_SECONDS
  )
end

--- Radio command: two fighters to escort the caller's own group, bought with the coalition's credits.
---
--- An airplane gets the DCS `Escort` task; a helicopter, too slow for fighters to stay with, gets a CAP
--- circle over it that moves with it. The fighters start in the air over the players' airfield nearest the
--- caller, so that they join quickly; refused with nothing charged when none can leave or none is declared.
--- @param parameters table|string the caller's unit name, as `USAGE_ForGroup` passes it
--- @return boolean whether it was bought
function veafCampaignEconomy.buyEscort(parameters)
  local unitName = type(parameters) == "table" and parameters[2] or parameters
  local unit = unitName and Unit.getByName(unitName)
  local group = unit and unit:getGroup()
  if not group or veafCampaign.over then
    return false
  end
  local label, price = veaf.t("campaign.shop.item.escort"), veafCampaignEconomy.price("escort")
  local function answer(key, ...)
    trigger.action.outTextForGroup(group:getID(), veaf.t(key, ...), 15)
  end
  if veafCampaignEconomy.credits < price then
    answer("campaign.shop.too_expensive", label, price, veafCampaignEconomy.credits)
    return false
  end
  local side = veafCampaign.playerSide()
  local point = unit:getPoint()
  local origin = nearestAirfield(side, point)
  if not origin then
    answer("campaign.shop.refused", label, veaf.t("campaign.shop.refused_no_airfield"))
    return false
  end
  local helicopter = unit:hasAttribute("Helicopters")
  local ok, spawned = pcall(function()
    if helicopter then
      local zone = { x = point.x, y = point.z, radius = veafCampaignOps.ESCORT_HELICOPTER_RADIUS }
      return veafCampaignOps.spawnFlight(side, "cap", origin, "zone_defense", { zone = zone }, veafCampaignOps.CAP_ALTITUDE, true)
    end
    return veafCampaignOps.spawnFlight(
      side,
      "cap",
      origin,
      "air_escort",
      { escorted = group:getName() },
      veafCampaignOps.CAP_ALTITUDE,
      true
    )
  end)
  if not ok or not spawned then
    logger():error("escort for [%s] failed: %s", group:getName(), tostring(spawned))
    answer("campaign.shop.refused", label, veaf.t("campaign.shop.refused_spawn"))
    return false
  end
  if helicopter then
    veaf.scheduleFunction(
      veafCampaignEconomy.followHelicopter,
      { spawned, group:getName(), { x = point.x, z = point.z } },
      timer.getTime() + veafCampaignEconomy.ESCORT_FOLLOW_SECONDS
    )
  end
  veafCampaignEconomy.credits = veafCampaignEconomy.credits - price
  veafCampaignEconomy.book("credits", "spent", "shop escort", price)
  veafCampaignEconomy.counters.purchases = veafCampaignEconomy.counters.purchases + 1
  trigger.action.outTextForCoalition(
    playerCoalition(),
    veaf.t("campaign.shop.escort", group:getName(), origin.name, price, veafCampaignEconomy.credits),
    15
  )
  logger():info(
    "bought an escort [%s] for [%s] (%s), %d credits",
    spawned,
    group:getName(),
    helicopter and "helicopter" or "airplane",
    price
  )
  return true
end

--- Buy an item, for a zone or none: refused with no credit taken when the side cannot pay, the zone no
--- longer suits, or the effect cannot be had.
--- @param parameters table `{ itemId, zoneName }`
--- @return boolean whether it was bought
function veafCampaignEconomy.buy(parameters)
  local itemId, zoneName = parameters[1], parameters[2]
  local price = veafCampaignEconomy.price(itemId)
  local item
  for _, candidate in ipairs(veafCampaignEconomy.ITEMS) do
    if candidate.id == itemId then
      item = candidate
    end
  end
  if not item or veafCampaign.over then
    return false
  end
  if veafCampaignEconomy.credits < price then
    tell("campaign.shop.too_expensive", veaf.t("campaign.shop.item." .. itemId), price, veafCampaignEconomy.credits)
    return false
  end
  local zone = zoneName and veafCampaign.zones[zoneName]
  if item.zones and not (zone and zoneSuits(item.zones, zone)) then
    tell("campaign.shop.refused", veaf.t("campaign.shop.item." .. itemId), veaf.t("campaign.shop.refused_zone"))
    return false
  end
  local ok, done, why = pcall(veafCampaignEconomy.effects[itemId], zone, zoneName)
  if not ok then
    logger():error("shop item [%s] failed: %s", itemId, tostring(done))
    done, why = false, "campaign.shop.refused_spawn"
  end
  if not done then
    tell("campaign.shop.refused", veaf.t("campaign.shop.item." .. itemId), veaf.t(why or "campaign.shop.refused_spawn"))
    return false
  end
  veafCampaignEconomy.credits = veafCampaignEconomy.credits - price
  veafCampaignEconomy.book("credits", "spent", "shop " .. itemId, price)
  veafCampaignEconomy.counters.purchases = veafCampaignEconomy.counters.purchases + 1
  tell("campaign.shop.bought", veaf.t("campaign.shop.item." .. itemId), zoneName or "-", price, veafCampaignEconomy.credits)
  logger():info("bought [%s] for [%s], %d credits", itemId, tostring(zoneName), price)
  veafCampaign.debug("SHOP", "%s bought on [%s] for %d credits, %d left", itemId, tostring(zoneName), price, veafCampaignEconomy.credits)
  return true
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Zone upgrades (FEAT-CAMPAIGN-SHOP-UPGRADES 01)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What each upgrade places, by id, once drawn: see `upgradeOffer`.
veafCampaignEconomy.offers = {}

local function upgradeOf(upgradeId)
  for _, upgrade in ipairs(veafCampaignEconomy.UPGRADES) do
    if upgrade.id == upgradeId then
      return upgrade
    end
  end
  return nil
end

--- The upgrades the shop offers in the campaign's era, in the menu's order.
--- @return table the entries of `UPGRADES`
function veafCampaignEconomy.availableUpgrades()
  local available = {}
  for _, upgrade in ipairs(veafCampaignEconomy.UPGRADES) do
    local offered = upgrade.eras == nil
    for _, era in ipairs(upgrade.eras or {}) do
      offered = offered or era == veaf.config.era
    end
    if offered then
      table.insert(available, upgrade)
    end
  end
  return available
end

--- The group an upgrade places, drawn once a mission and kept: the price the menu shows and the group a purchase
--- places are then the same units, where a template's random counts would draw another group at each call.
--- @param upgradeId string
--- @return table|nil the group, as `veafUnits.processGroup` hands it back; nil when it cannot be had
function veafCampaignEconomy.upgradeOffer(upgradeId)
  local offer = veafCampaignEconomy.offers[upgradeId]
  local upgrade = upgradeOf(upgradeId)
  if offer or not upgrade then
    return offer
  end
  local side, name = playerCoalition(), "upgrade " .. upgradeId
  local draw = veafCampaignEconomy.UPGRADE_DRAW
  if upgrade.group then
    offer = veafUnits.findGroup(upgrade.group)
  else
    local definition
    if upgrade.draw == "infantry" then
      definition = veafCasMission.generateInfantryGroup(name, draw.defense, draw.armor, side)
    elseif upgrade.draw == "armor" then
      definition = veafCasMission.generateArmorPlatoon(name, draw.defense, draw.armor, side)
    else
      definition = { disposition = { h = 4, w = 4 }, units = {}, description = name, groupName = name }
      for _, typeName in ipairs(upgrade.units) do
        table.insert(definition.units, { typeName, random = true })
      end
    end
    offer = veafUnits.processGroup(definition)
  end
  if not (offer and offer.units and #offer.units > 0) then
    logger():error("the upgrade [%s] cannot be drawn: it is left out of the shop", upgradeId)
    return nil
  end
  veafCampaignEconomy.offers[upgradeId] = offer
  return offer
end

--- What an upgrade costs: its `economy.prices` entry, else its units' spawn price in credits — a Hawk battery costs
--- what spawning one costs, and the two never drift apart.
--- @param upgradeId string
--- @return number|nil credits; nil when the upgrade cannot be had
function veafCampaignEconomy.upgradePrice(upgradeId)
  local override = (veafCampaign.setting("economy", "prices") or {})[upgradeId]
  if override then
    return override
  end
  local offer = veafCampaignEconomy.upgradeOffer(upgradeId)
  if not offer then
    return nil
  end
  local types = {}
  for _, unit in ipairs(offer.units) do
    table.insert(types, unit.typeName)
  end
  return veafCampaign.unitsPrice(types) * veafCampaign.setting("economy", "credits_per_point")
end

--- Why an upgrade cannot be bought on a zone now, or nil: the zone is not the players' any more, holds
--- `economy.upgrades_per_zone` bought upgrades already, or an upgrade it may hold only one of.
--- @return string|nil the i18n key
--- @return any the key's argument
local function upgradeRefusal(upgrade, zone)
  if not (zone and zone.placed and zone.entry.owner == veafCampaign.playerSide() and zone.entry.garrison) then
    return "campaign.shop.refused_zone"
  end
  local bought, limit = zone:upgrades(), veafCampaign.setting("economy", "upgrades_per_zone")
  if #bought >= limit then
    return "campaign.shop.refused_upgrades_full", limit
  end
  for _, group in ipairs(bought) do
    if upgrade.once and group.upgrade == upgrade.id then
      return "campaign.shop.refused_upgrade_once"
    end
  end
  return nil
end

--- Radio command: buy an upgrade on one of the players' zones. Refused with no credit taken when the side cannot pay,
--- the zone no longer suits, or the group cannot be placed.
--- @param parameters table `{ upgradeId, zoneName }`
--- @return boolean whether it was bought
function veafCampaignEconomy.buyUpgrade(parameters)
  local upgradeId, zoneName = parameters[1], parameters[2]
  local upgrade = upgradeOf(upgradeId)
  if not upgrade or veafCampaign.over then
    return false
  end
  local label = veaf.t("campaign.shop.upgrade." .. upgradeId)
  local price = veafCampaignEconomy.upgradePrice(upgradeId)
  if not price then
    tell("campaign.shop.refused", label, veaf.t("campaign.shop.refused_spawn"))
    return false
  end
  if veafCampaignEconomy.credits < price then
    tell("campaign.shop.too_expensive", label, price, veafCampaignEconomy.credits)
    return false
  end
  local zone = veafCampaign.zones[zoneName]
  local why, argument = upgradeRefusal(upgrade, zone)
  local group = not why and zone:addUpgrade(upgradeId, veafCampaignEconomy.upgradeOffer(upgradeId))
  if not group then
    tell("campaign.shop.refused", label, veaf.t(why or "campaign.shop.refused_placed", argument))
    return false
  end
  veafCampaignEconomy.credits = veafCampaignEconomy.credits - price
  veafCampaignEconomy.book("credits", "spent", "upgrade " .. upgradeId, price)
  veafCampaignEconomy.counters.purchases = veafCampaignEconomy.counters.purchases + 1
  tell("campaign.shop.bought", label, veafCampaign.zoneTitle(zoneName), price, veafCampaignEconomy.credits)
  logger():info("bought the upgrade [%s] for [%s], %d unit(s), %d credits", upgradeId, zoneName, #group.units, price)
  veafCampaign.debug(
    "SHOP",
    "upgrade %s bought on [%s] (%s, %d units) for %d credits, %d left",
    upgradeId,
    zoneName,
    group.name,
    #group.units,
    price,
    veafCampaignEconomy.credits
  )
  return true
end

--- Radio command: the balance.
function veafCampaignEconomy.reportCredits()
  tell("campaign.credits.balance", veafCampaignEconomy.credits)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task board (ticket 07)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- What a task of that kind is worth.
function veafCampaignEconomy.reward(kind)
  local rewards = veafCampaign.setting("tasks", "rewards") or {}
  return rewards[kind] or veafCampaignEconomy.REWARDS[kind]
end

local function zonePosted(zoneName)
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    if task.zone == zoneName then
      return true
    end
  end
  return false
end

local function kindPosted(kind)
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    if task.kind == kind then
      return true
    end
  end
  return false
end

--- The tasks the situation offers now, in the order they are posted: attack the weakest enemy zone on
--- the front, capture a neutral zone we border, resupply our most damaged zone, then air superiority.
--- Targets already posted are left out.
function veafCampaignEconomy.candidateTasks()
  local own = veafCampaign.playerSide()
  local candidates = {}
  -- the enemy's bombers out come first: they will not wait (ticket 17)
  local raid = veafCampaignOps and veafCampaignOps.raidUnderway and veafCampaignOps.raidUnderway(veafCampaign.enemyOf(own))
  if raid and not kindPosted("intercept") then
    table.insert(candidates, { kind = "intercept", zone = raid.target, raid = raid })
  end
  local attack = veafCampaign.attackTarget(own)
  if attack and not zonePosted(attack.name) then
    table.insert(candidates, { kind = "attack", zone = attack.name })
  end
  local capture = nil
  for _, zone in ipairs(veafCampaign.zoneList) do
    if not capture and zone.placed and zone.entry.owner == "neutral" and not zonePosted(zone.name) then
      for _, neighbour in ipairs(veafCampaign.neighbours(zone.name)) do
        if neighbour.entry.owner == own then
          capture = zone
          break
        end
      end
    end
  end
  if capture then
    table.insert(candidates, { kind = "capture", zone = capture.name })
  end
  local worst, worstStrength = nil, 100
  for _, zone in ipairs(veafCampaign.zoneList) do
    if
      zone.placed
      and zone.entry.owner == own
      and zone:isDamaged()
      and not zonePosted(zone.name)
      and zone:strengthPercent() < worstStrength
    then
      worst, worstStrength = zone, zone:strengthPercent()
    end
  end
  if worst then
    table.insert(candidates, { kind = "resupply", zone = worst.name })
  end
  if not kindPosted("air") then
    table.insert(candidates, { kind = "air" })
  end
  return candidates
end

--- Post a task: on the board, on the map for the side, and told to it.
function veafCampaignEconomy.post(task)
  task.reward = veafCampaignEconomy.reward(task.kind)
  task.kills = 0
  local zone = task.zone and veafCampaign.zones[task.zone]
  if zone then
    task.markId = veaf.getUniqueIdentifier()
    trigger.action.markToCoalition(
      task.markId,
      veaf.t("campaign.task." .. task.kind, task.zone, task.reward),
      zone:getCenter(),
      playerCoalition(),
      true
    )
  end
  table.insert(veafCampaignEconomy.tasks, task)
  veafCampaignEconomy.counters.posted = veafCampaignEconomy.counters.posted + 1
  local side = veafCampaign.playerSide()
  veafCampaign.announce(
    side,
    side,
    veaf.t(
      "campaign.task.posted",
      veaf.t("campaign.task." .. task.kind, task.zone and veafCampaign.zoneTitle(task.zone) or "-", task.reward)
    )
  )
end

--- Fill the board's empty places.
function veafCampaignEconomy.refreshTasks()
  for _, candidate in ipairs(veafCampaignEconomy.candidateTasks()) do
    -- an interception does not wait for a place: the bombers are out now (ticket 17)
    if candidate.kind == "intercept" or #veafCampaignEconomy.tasks < veafCampaign.setting("tasks", "count") then
      veafCampaignEconomy.post(candidate)
    end
  end
end

--- Whether a task is done, given up, or still open: "done", "withdrawn" or nil.
function veafCampaignEconomy.taskState(task)
  local own = veafCampaign.playerSide()
  local zone = task.zone and veafCampaign.zones[task.zone]
  if task.kind == "air" then
    return task.kills >= veafCampaign.setting("tasks", "air_kills") and "done" or nil
  elseif task.kind == "intercept" then
    if not task.raid.done then
      return nil
    end
    return task.raid.outcome == "destroyed" and "done" or "withdrawn"
  elseif task.kind == "attack" then
    return zone.entry.owner ~= veafCampaign.enemyOf(own) and "done" or nil
  elseif task.kind == "capture" then
    return (zone.entry.owner == own and "done") or (zone.entry.owner ~= "neutral" and "withdrawn") or nil
  elseif task.kind == "resupply" then
    return (zone.entry.owner ~= own and "withdrawn") or (not zone:isDamaged() and "done") or nil
  end
  return nil
end

--- Close what is done or given up: reward, mark removed, told.
function veafCampaignEconomy.checkTasks()
  local open = {}
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    local state = veafCampaignEconomy.taskState(task)
    if state then
      if task.markId then
        trigger.action.removeMark(task.markId)
      end
      local title = veaf.t("campaign.task." .. task.kind, task.zone or "-", task.reward)
      if state == "done" then
        veafCampaignEconomy.counters.completed = veafCampaignEconomy.counters.completed + 1
        veafCampaignEconomy.earn(task.reward, "campaign.credits.task", title)
      else
        veafCampaign.announce(veafCampaign.playerSide(), veafCampaign.playerSide(), veaf.t("campaign.task.withdrawn", title))
      end
    else
      table.insert(open, task)
    end
  end
  veafCampaignEconomy.tasks = open
end

--- The sitac's ranking (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 03): each pilot's figures by Foothold's names, `Points` the
--- credits he earned. The team, which earns what nobody flew for (a capture, a task), is no pilot and is left out.
--- @return table by player name
function veafCampaignEconomy.sitacStats()
  local ranking = {}
  for name, books in pairs(veafCampaignEconomy.pilots) do
    if name ~= veafCampaignEconomy.TEAM then
      local entry = { Points = books.total or 0 }
      for stat, value in pairs(books.stats or {}) do
        entry[stat] = value
      end
      ranking[name] = entry
    end
  end
  return ranking
end

--- The sitac's task board (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT 05), in Foothold's `missions` shape: each open task's
--- title as the F10 menu gives it, an air task's progress as its description, and its kind, zone and reward.
--- @return table a list
function veafCampaignEconomy.sitacTasks()
  local missions = {}
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    local description = ""
    if task.kind == "air" then
      description = string.format("%d/%d", task.kills or 0, veafCampaign.setting("tasks", "air_kills"))
    end
    table.insert(missions, {
      title = veaf.t("campaign.task." .. task.kind, task.zone and veafCampaign.zoneTitle(task.zone) or "-", task.reward),
      description = description,
      isRunning = true,
      isEscortMission = false,
      kind = task.kind,
      zone = task.zone,
      reward = task.reward,
    })
  end
  return missions
end

--- Radio command: the board.
function veafCampaignEconomy.reportTasks()
  local lines = { veaf.t("campaign.task.header") }
  for _, task in ipairs(veafCampaignEconomy.tasks) do
    local line = "- " .. veaf.t("campaign.task." .. task.kind, task.zone or "-", task.reward)
    if task.kind == "air" then
      line = line .. string.format(" (%d/%d)", task.kills, veafCampaign.setting("tasks", "air_kills"))
    end
    table.insert(lines, line)
  end
  trigger.action.outTextForCoalition(playerCoalition(), table.concat(lines, "\n"), 30)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu, loop, save, self-check
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- The players' side's menus under Campaign: Credits, Shop, Tasks, Intel. The shop lists, under each
--- item, the zones it applies to now; it is rebuilt when a zone changes hands.
function veafCampaignEconomy.buildRadioMenu()
  if not (veafRadio and veafCampaign.rootPath) then
    return
  end
  local side = playerCoalition()
  if not veafCampaignEconomy.menuBuilt then
    veafCampaignEconomy.menuBuilt = true
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.credits"),
      veafCampaign.rootPath,
      veafCampaignEconomy.reportCredits,
      nil,
      veafRadio.USAGE_ForAll
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.tasks"),
      veafCampaign.rootPath,
      veafCampaignEconomy.reportTasks,
      nil,
      veafRadio.USAGE_ForAll
    )
    veafRadio.addCommandToSubmenu(
      veaf.t("menu.campaign.intel"),
      veafCampaign.rootPath,
      veafCampaignEconomy.reportIntel,
      nil,
      veafRadio.USAGE_ForAll
    )
    veafCampaignEconomy.shopPath = veafRadio.addSubMenu(veaf.t("menu.campaign.shop"), veafCampaign.rootPath, side)
  else
    veafRadio.clearSubmenu(veafCampaignEconomy.shopPath)
  end
  for _, item in ipairs(veafCampaignEconomy.ITEMS) do
    local title = veaf.t("menu.campaign.shop_item", veaf.t("campaign.shop.item." .. item.id), veafCampaignEconomy.price(item.id))
    if item.zones then
      local path = veafRadio.addSubMenu(title, veafCampaignEconomy.shopPath, side)
      for _, zone in ipairs(veafCampaign.zoneList) do
        if zone.placed and zoneSuits(item.zones, zone) then
          veafRadio.addCommandToSubmenu(
            veafCampaign.zoneTitle(zone.name),
            path,
            veafCampaignEconomy.buy,
            { item.id, zone.name },
            veafRadio.USAGE_ForAll
          )
        end
      end
    elseif item.id == "escort" then
      -- for the caller's own group: each player's menu carries it
      veafRadio.addCommandToSubmenu(title, veafCampaignEconomy.shopPath, veafCampaignEconomy.buyEscort, nil, veafRadio.USAGE_ForGroup)
    elseif item.id == "tanker" then
      for _, name in ipairs(veafCampaignEconomy.tankers()) do
        local tankerTitle = veaf.t("menu.campaign.shop_item", veafCampaignEconomy.tankerTitle(name), veafCampaignEconomy.price(item.id))
        veafRadio.addCommandToSubmenu(
          tankerTitle,
          veafCampaignEconomy.shopPath,
          veafCampaignEconomy.buy,
          { item.id, name },
          veafRadio.USAGE_ForAll
        )
      end
    else
      veafRadio.addCommandToSubmenu(title, veafCampaignEconomy.shopPath, veafCampaignEconomy.buy, { item.id }, veafRadio.USAGE_ForAll)
    end
  end
  veafCampaignEconomy.buildUpgradesMenu(side)
  veafRadio.refreshRadioMenu()
end

--- The shop's zone upgrades (FEAT-CAMPAIGN-SHOP-UPGRADES 01): Shop > Zone upgrades > one of the players' zones > the
--- upgrades of the campaign's era, each with its price. A zone full is listed all the same: the purchase says why not.
--- @param side number the players' DCS coalition
function veafCampaignEconomy.buildUpgradesMenu(side)
  local upgrades = {}
  for _, upgrade in ipairs(veafCampaignEconomy.availableUpgrades()) do
    local price = veafCampaignEconomy.upgradePrice(upgrade.id)
    if price then
      table.insert(upgrades, { id = upgrade.id, price = price })
    end
  end
  if #upgrades == 0 then
    return
  end
  local path = veafRadio.addSubMenu(veaf.t("menu.campaign.upgrades"), veafCampaignEconomy.shopPath, side)
  for _, zone in ipairs(veafCampaign.zoneList) do
    if zone.placed and zoneSuits("own", zone) then
      local zonePath = veafRadio.addSubMenu(veafCampaign.zoneTitle(zone.name), path, side)
      for _, upgrade in ipairs(upgrades) do
        veafRadio.addCommandToSubmenu(
          veaf.t("menu.campaign.shop_item", veaf.t("campaign.shop.upgrade." .. upgrade.id), upgrade.price),
          zonePath,
          veafCampaignEconomy.buyUpgrade,
          { upgrade.id, zone.name },
          veafRadio.USAGE_ForAll
        )
      end
    end
  end
end

--- One beat, inside veafCampaign's loop.
function veafCampaignEconomy.beat(now)
  if veafCampaign.over then
    return
  end
  local playing = anyPlayer()
  if playing and not veafCampaignEconomy.ledger then
    veafCampaignEconomy.openLedger()
  elseif not playing and (veafCampaignEconomy.sessionGains or veafCampaignEconomy.ledger) then
    veafCampaignEconomy.summarizeSession("nobody left in a slot")
  end
  veafCampaignEconomy.checkOverflights()
  veafCampaignEconomy.followSpies()
  veafCampaignEconomy.checkTasks()
  if now >= (veafCampaignEconomy.nextTasks or 0) then
    veafCampaignEconomy.nextTasks = now + veafCampaign.setting("tasks", "refresh_seconds")
    veafCampaignEconomy.refreshTasks()
  end
end

--- What the save keeps: the credits, and the intelligence still valid, as seconds left.
function veafCampaignEconomy.save()
  local now, revealed = timer.getTime(), {}
  for _, zone in ipairs(veafCampaign.zoneList) do
    if (zone.revealedUntil or 0) > now then
      revealed[zone.name] = math.floor(zone.revealedUntil - now)
    end
  end
  return { credits = veafCampaignEconomy.credits, revealed = revealed, pilots = veafCampaignEconomy.pilots }
end

--- Take back what the save kept.
function veafCampaignEconomy.load(saved)
  if type(saved) ~= "table" then
    return
  end
  veafCampaignEconomy.credits = tonumber(saved.credits) or veafCampaignEconomy.credits
  if type(saved.pilots) == "table" then
    veafCampaignEconomy.pilots = saved.pilots
  end
  for name, seconds in pairs(type(saved.revealed) == "table" and saved.revealed or {}) do
    local zone = veafCampaign.zones[name]
    if zone and tonumber(seconds) then
      zone.revealedUntil = timer.getTime() + tonumber(seconds)
    end
  end
end

--- The self-check's lines.
function veafCampaignEconomy.selfCheck(verdict)
  local c = veafCampaignEconomy.counters
  return {
    verdict(true, "campaign.check.credits", veafCampaignEconomy.credits, c.purchases),
    -- an empty board is wrong once it has been drawn, not before the first beat draws it
    verdict(
      #veafCampaignEconomy.tasks > 0 or veafCampaignEconomy.nextTasks == nil,
      "campaign.check.tasks",
      #veafCampaignEconomy.tasks,
      c.posted,
      c.completed
    ),
    verdict(true, "campaign.check.intel", c.reveals, c.spies),
  }
end

--- Start credits, shop, tasks and intelligence. Called by veafCampaign.initialize.
function veafCampaignEconomy.initialize()
  logger():info("Initializing module")
  veafCampaignEconomy.credits = veafCampaign.setting("economy", "start_credits")
  veafCampaignEconomy.pilots, veafCampaignEconomy.sessionGains, veafCampaignEconomy.ledger = {}, nil, nil
  veafCampaignEconomy.tasks, veafCampaignEconomy.spies, veafCampaignEconomy.nextTasks = {}, {}, nil
  veafCampaignEconomy.menuBuilt, veafCampaignEconomy.shopPath, veafCampaignEconomy.offers = false, nil, {}
  veafCampaignEconomy.counters = { purchases = 0, posted = 0, completed = 0, reveals = 0, spies = 0 }
  veafCampaignEconomy.load(veafCampaign.savedPart("economy"))
  veafCampaign.saveParts.economy = { save = veafCampaignEconomy.save }
  table.insert(veafCampaign.beatHooks, veafCampaignEconomy.beat)
  table.insert(veafCampaign.selfChecks, veafCampaignEconomy.selfCheck)
  veafCampaign.listen("captured", function(zone, side)
    if side == veafCampaign.playerSide() then
      veafCampaignEconomy.earn(veafCampaign.setting("economy", "capture"), "campaign.credits.capture", veafCampaign.zoneTitle(zone.name))
    end
    veafCampaignEconomy.buildRadioMenu()
  end)
  veafCampaign.listen("neutral", function()
    veafCampaignEconomy.buildRadioMenu()
  end)
  veafCampaign.listen("raid", function(raid)
    if raid.side ~= veafCampaign.playerSide() then
      veafCampaignEconomy.refreshTasks()
    end
  end)
  veafCampaign.listen("delivered", function(zone, side)
    if side == veafCampaign.playerSide() then
      veafCampaignEconomy.earn(veafCampaign.setting("economy", "delivery"), "campaign.credits.delivery", veafCampaign.zoneTitle(zone.name))
    end
  end)
  veafEventHandler.addCallback("veafCampaignEconomy.onKill", { "S_EVENT_KILL" }, veafCampaignEconomy.onKill)
  veafEventHandler.addCallback("veafCampaignEconomy.onMissionEnd", { "S_EVENT_MISSION_END" }, function()
    veafCampaignEconomy.summarizeSession("the mission ends")
  end)
  veafCampaignEconomy.held, veafCampaignEconomy.lostAtEjection = {}, {}
  veafEventHandler.addCallback(
    "veafCampaignEconomy.onPilotEvent",
    { "S_EVENT_LAND", "S_EVENT_EJECTION", "S_EVENT_PILOT_DEAD", "S_EVENT_CRASH", "S_EVENT_DEAD", "S_EVENT_PLAYER_LEAVE_UNIT" },
    veafCampaignEconomy.onPilotEvent
  )
  veafCampaignEconomy.watchRescues()
  veafCampaignEconomy.buildRadioMenu()
  return true
end

veaf.loggers.get(veafCampaignEconomy.Id):info(veaf.loggers.get(veafCampaignEconomy.Id):getVersionInfo())
