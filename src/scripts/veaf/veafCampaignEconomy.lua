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
  tanker = 300,
  intel = 150,
  capture = 250,
  resupply = 200,
}

--- The shop's items, in the menu's order, with the zones each applies to: "enemy", "own", "neutral",
--- "any", or none for an item that needs no zone.
veafCampaignEconomy.ITEMS = {
  { id = "jtac", zones = "enemy" },
  { id = "illumination", zones = "any" },
  { id = "smoke", zones = "enemy" },
  { id = "intel", zones = "enemy" },
  { id = "cap", zones = "own" },
  { id = "capture", zones = "neutral" },
  { id = "resupply", zones = "own" },
  { id = "tanker" },
}

--- What a task is worth when `tasks.rewards` does not say.
veafCampaignEconomy.REWARDS = { attack = 300, capture = 300, resupply = 200, air = 200 }

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

--- Add credits (or take them, with a negative amount; never below zero), and tell the side.
--- @param amount number
--- @param reasonKey string|nil the i18n key of why, nil to say nothing
function veafCampaignEconomy.earn(amount, reasonKey, ...)
  veafCampaignEconomy.credits = math.max(0, veafCampaignEconomy.credits + amount)
  if reasonKey and amount ~= 0 then
    tell("campaign.credits.earned", amount, veaf.t(reasonKey, ...), veafCampaignEconomy.credits)
  end
end

--- A kill: a player of the players' side destroyed an enemy unit.
function veafCampaignEconomy.onKill(event)
  local kill = veafCampaign.readPlayerKill(event)
  if veafCampaign.over or not kill then
    return
  end
  veafCampaignEconomy.earn(veafCampaign.setting("economy", kill.air and "kill_air" or "kill_ground"), "campaign.credits.kill", kill.player)
  if kill.air then
    for _, task in ipairs(veafCampaignEconomy.tasks) do
      if task.kind == "air" then
        task.kills = task.kills + 1
      end
    end
  end
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
    tell("campaign.intel.revealed", zone.name, veaf.t("campaign.intel.by_" .. how))
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
  local lines = { veaf.t("campaign.intel.report", zone.name, zone:strengthPercent()) }
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
local function zoneSuits(rule, zone)
  local own, owner = veafCampaign.playerSide(), zone.entry.owner
  return (rule == "any")
    or (rule == "own" and owner == own)
    or (rule == "neutral" and owner == "neutral")
    or (rule == "enemy" and owner == veafCampaign.enemyOf(own))
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
    local origin = zone.entry.airbase and zone or veafCampaignOps.nearestOwnZone(side, zone, true)
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
  tanker = function()
    local name = veafCampaign.setting("economy", "tanker")
    if not (name and veafAssets and veafAssets.respawn) then
      return false, "campaign.shop.refused_no_tanker"
    end
    veafAssets.respawn(name)
    return true
  end,
}

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
  local ok, done, why = pcall(veafCampaignEconomy.effects[itemId], zone)
  if not ok then
    logger():error("shop item [%s] failed: %s", itemId, tostring(done))
    done, why = false, "campaign.shop.refused_spawn"
  end
  if not done then
    tell("campaign.shop.refused", veaf.t("campaign.shop.item." .. itemId), veaf.t(why or "campaign.shop.refused_spawn"))
    return false
  end
  veafCampaignEconomy.credits = veafCampaignEconomy.credits - price
  veafCampaignEconomy.counters.purchases = veafCampaignEconomy.counters.purchases + 1
  tell("campaign.shop.bought", veaf.t("campaign.shop.item." .. itemId), zoneName or "-", price, veafCampaignEconomy.credits)
  logger():info("bought [%s] for [%s], %d credits", itemId, tostring(zoneName), price)
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
  tell("campaign.task.posted", veaf.t("campaign.task." .. task.kind, task.zone or "-", task.reward))
end

--- Fill the board's empty places.
function veafCampaignEconomy.refreshTasks()
  for _, candidate in ipairs(veafCampaignEconomy.candidateTasks()) do
    if #veafCampaignEconomy.tasks >= veafCampaign.setting("tasks", "count") then
      return
    end
    veafCampaignEconomy.post(candidate)
  end
end

--- Whether a task is done, given up, or still open: "done", "withdrawn" or nil.
function veafCampaignEconomy.taskState(task)
  local own = veafCampaign.playerSide()
  local zone = task.zone and veafCampaign.zones[task.zone]
  if task.kind == "air" then
    return task.kills >= veafCampaign.setting("tasks", "air_kills") and "done" or nil
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
        tell("campaign.task.withdrawn", title)
      end
    else
      table.insert(open, task)
    end
  end
  veafCampaignEconomy.tasks = open
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
          veafRadio.addCommandToSubmenu(zone.name, path, veafCampaignEconomy.buy, { item.id, zone.name }, veafRadio.USAGE_ForAll)
        end
      end
    elseif item.id ~= "tanker" or veafCampaign.setting("economy", "tanker") then
      veafRadio.addCommandToSubmenu(title, veafCampaignEconomy.shopPath, veafCampaignEconomy.buy, { item.id }, veafRadio.USAGE_ForAll)
    end
  end
  veafRadio.refreshRadioMenu()
end

--- One beat, inside veafCampaign's loop.
function veafCampaignEconomy.beat(now)
  if veafCampaign.over then
    return
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
  return { credits = veafCampaignEconomy.credits, revealed = revealed }
end

--- Take back what the save kept.
function veafCampaignEconomy.load(saved)
  if type(saved) ~= "table" then
    return
  end
  veafCampaignEconomy.credits = tonumber(saved.credits) or veafCampaignEconomy.credits
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
    verdict(#veafCampaignEconomy.tasks > 0, "campaign.check.tasks", #veafCampaignEconomy.tasks, c.posted, c.completed),
    verdict(true, "campaign.check.intel", c.reveals, c.spies),
  }
end

--- Start credits, shop, tasks and intelligence. Called by veafCampaign.initialize.
function veafCampaignEconomy.initialize()
  logger():info("Initializing module")
  veafCampaignEconomy.credits = veafCampaign.setting("economy", "start_credits")
  veafCampaignEconomy.tasks, veafCampaignEconomy.spies, veafCampaignEconomy.nextTasks = {}, {}, nil
  veafCampaignEconomy.menuBuilt, veafCampaignEconomy.shopPath = false, nil
  veafCampaignEconomy.counters = { purchases = 0, posted = 0, completed = 0, reveals = 0, spies = 0 }
  veafCampaignEconomy.load(veafCampaign.savedPart("economy"))
  veafCampaign.saveParts.economy = { save = veafCampaignEconomy.save }
  table.insert(veafCampaign.beatHooks, veafCampaignEconomy.beat)
  table.insert(veafCampaign.selfChecks, veafCampaignEconomy.selfCheck)
  veafCampaign.listen("captured", function(zone, side)
    if side == veafCampaign.playerSide() then
      veafCampaignEconomy.earn(veafCampaign.setting("economy", "capture"), "campaign.credits.capture", zone.name)
    end
    veafCampaignEconomy.buildRadioMenu()
  end)
  veafCampaign.listen("neutral", function()
    veafCampaignEconomy.buildRadioMenu()
  end)
  veafCampaign.listen("delivered", function(zone, side)
    if side == veafCampaign.playerSide() then
      veafCampaignEconomy.earn(veafCampaign.setting("economy", "delivery"), "campaign.credits.delivery", zone.name)
    end
  end)
  veafEventHandler.addCallback("veafCampaignEconomy.onKill", { "S_EVENT_KILL" }, veafCampaignEconomy.onKill)
  veafCampaignEconomy.buildRadioMenu()
  return true
end

veaf.loggers.get(veafCampaignEconomy.Id):info(veaf.loggers.get(veafCampaignEconomy.Id):getVersionInfo())
