# 05 — Player economy: credits, shop, ranks, rewards and player missions (Foothold v6.5.3)

Source: upstream tag v6.5.3, `Common Scripts/zoneCommanderv2.lua` (engine), `Common Scripts/Foothold Config.lua`, `Setup files/MA_Setup_CAv2.lua` (Caucasus), `Common Scripts/Foothold_Localization.lua`.
Short file names are used in citations: `zoneCommanderv2.lua` → `zc`, `Foothold Config.lua` → `Config`, `MA_Setup_CAv2.lua` → `Setup`, `Foothold_Localization.lua` → `L10N`.

## Feature list

| # | Feature | One-line description | Main code location |
|---|---|---|---|
| 1 | Coalition credits | one shared account per side, spent in the shop and on CTLD | `zc:19368-19375`, `zc:21418-21548` |
| 2 | Shop core | item registry, per-side shelves with stock and rank, purchase validation, deferred payment | `zc:19322-19366`, `zc:21770-22132` |
| 3 | Personal (unclaimed) credits | rewards accumulate on the player and are banked by landing in a friendly zone; lost on death, 25 % kept on ejection | `zc:41264-41273`, `zc:41818-41922`, `zc:42083-43149` |
| 3.1 | Kill attribution | `S_EVENT_KILL` only, target classified by DCS attributes | `zc:42812-42891`, `zc:43151-43233` |
| 3.3 | Flight-time, turnaround and night bonuses | per-minute reward, same-aircraft bonus, night-takeoff bonus | `zc:101289-101318`, `zc:41504-41612` |
| 3.4 | Refuelling reward | credits per 100 lb received from a tanker | `WelcomeMessage.lua:2731-2829` |
| 3.5 | Logistics / CSAR / capture reward hooks | supply delivery, capture, rescue, enemy pilot capture | `zc:98238-98300`, `zc:100538-100558`, `zc:42284-42311` |
| 3.6 | Friendly-fire penalty | rank credits removed for team kills | `zc:42641-42675` |
| 4 | Shop F10 menu and marker shop | per-group categorised menu with zone selectors; `buy:<id>` map marks | `zc:22395-22533`, `zc:28555-28706` |
| 5 | Shop catalogue | every item, price, rank, target, effect | `Setup:3009-5751`, `Config:1608-1916` |
| 5 | Dynamic Control menu | control of purchased flights, tankers, carrier | `zc:16259`, `zc:106266-106480` |
| 6 | CAP auto-buy after loss (6.5.2) | automatic re-purchase of a destroyed CAP flight | `zc:21863-21876`, `zc:106427-106466` |
| 7 | Ranks | 20-step ladder on personal rank credits, gates shop / CTLD / carrier | `zc:17231-17232`, `zc:44332-44408` |
| 8 | Statistics and leaderboards | per-sortie, per-session and lifetime stats; top lists | `zc:40510-40970`, `zc:21395` |
| 9 | Career and achievements | lifetime counters per player and per aircraft with paid achievement ladders | `zc:12040-12101`, `zc:44035-44100` |
| 10 | Joint missions | parties of up to 4 players sharing mission rewards | `zc:18059`, `zc:41275-41360` |
| 11 | Player missions | polled mission list, target registry, strike events, escort missions | `zc:102460-103960`, `zc:8866-9072`, `Setup:6073-9700` |
| 12 | F10 menu tree | menu paths, scope and refresh | `zc:101203-101215`, `zc:101490-101497` |
| 13 | Economy Config knobs | every setting that tunes prices, rewards and penalties | `Config:260-292`, `Config:1573-1952` |

## 1. Coalition credits (the shared account)

### Player view

- Each coalition owns one integer account; every purchase message ends with the remaining balance (`SHOP_BOUGHT_BY_PLAYER`, `zc:22093-22095`).
- `F10 > Shop > Budget overview` prints `Credits: <n>[/<cap>]`, every shop item with its cost and remaining stock, and an "Unclaimed credits" list of players who are airborne with unbanked credits (`zc:21418-21464`, menu entry at `zc:22411-22413`).

### Mission-maker view

- `bc:addFunds(side, amount)` adds (or removes, negative) credits; the balance is clamped at 0 and at `bc.creditsCap` when that cap is set (`zc:19368-19375`).
- `StartupFunds = {[1]=1000,[2]=1000}` are the PvP starting funds of a new or reset round (`Config:304-311`); the setup applies them as a delta on the current account (`Setup:5861-5862`).
- `CreditLosewhenKilled` (default `false`) and `CreditLosewhenKilledAmount` (100) make the coalition lose credits on each player death (`Config:260-264`).
- Admin chat/marker aliases `addBlueFunds`, `addRedFunds` exist in `AdminCommandAliases` (`Config:3477-3483`).
- The setup file grants credits from mission triggers with `bc:addFunds(2,200)` / `bc:addFunds(2,500)` in a series of scripted callbacks (`Setup:2583-2727`).

### Mechanism

- State: `bc.accounts[side]` (number), `bc.creditsCap` (optional), `bc._pendingShopCreditReservations[side]` (credits reserved by purchases whose delivery is still pending) (`zc:19368-19375`, `zc:21550-21573`).
- A purchase checks `accounts[side] - reserved >= cost` (`zc:21945-21953`).
- No Moose involved: plain Lua tables and `trigger.action.outTextForCoalition/Group`.

## 2. Shop core: item registry, per-coalition shelves, purchase flow

### Data model

- `bc:registerShopItem(id, name, cost, action, altAction, aiPurchaseChance, flightRole, flightTemplatesBySide)` stores the definition in `bc.shopItems[id]` (`zc:19322-19339`).
- `action(sender[, ownerSide])` runs when the item is bought with no parameter; `altAction(sender, params[, ownerSide])` runs when a parameter table is given (zone selected in the menu, or marker point) (`zc:22036-22049`).
- An action returns `true`/`nil` for success, a string or a function (localised text builder) for a refusal message shown to the buyer, `false` for the generic "not available now", or `{deferredShopPurchase=true}` when payment will be settled later (`zc:22054-22131`).
- `bc:addShopItem(side, id, amount, prio, reqRank, category)` puts the item on a coalition shelf `bc.shops[side][id] = {name,cost,stock,prio,category,reqRank}`; `amount = -1` means unlimited stock, a positive amount is a finite stock that is decremented and removes the item at 0 (`zc:19341-19361`, `zc:22073-22079`).
- `reqRank` is stored only when `RankingSystem` is true (`zc:19353`, `zc:19357`).
- `bc:removeShopItem(side, id)` removes it and rebuilds the shop menus of the coalition (`zc:19363-19366`).
- `AvailableShopItems[id] == false` in the Config makes `registerShopItem` mark the item `purchaseAvailable = false`, which makes `addShopItem` ignore it (`zc:19323`, `zc:19344`).
- In PvP a hard-coded list of ids is forced unavailable (`dynamicstatic`, `armor`, `artillery`, `recon`, `airdef`, `calav`, `camgs`, `cadragoon`, `jtac`, `9lineam`, `9linefm`, `zsup3`, `zwh50`, `advancecapture`, `cruisemsl`, the red AI items), and flight items need a `flightRole` plus a template row for the buying side (`zc:19324-19338`, `zc:19345`).

### Purchase flow (`BattleCommander:buyShopItem`, `zc:21770-22132`)

Checks, in order:

1. The item must be on the coalition shelf, else `SHOP_ITEM_NOT_FOUND` (`zc:21780-21787`).
2. PvP: flight/upgrade items must belong to the buyer's side, the buyer group must be of that coalition, and the buyer's rank must reach `reqRank` (`zc:21791-21803`).
3. Tankers (`dynamicarco`, `dynamictexaco`) are "persistent unlocks": once unlocked the item is removed from the shelf and the action is re-run for free with the message `SHOP_ALREADY_UNLOCKED` (`zc:21809-21852`).
4. `purchaseAvailable == false` → refuse (`zc:21853`).
5. `zpat` refused if the zone already has a Patriot (`zc:21854-21862`).
6. CAP auto-buy pre-checks (see §6) (`zc:21863-21876`).
7. `StoreLimit` (Config, default `false`): a player may only buy an item costing more than 250 / 1000 / 2000 / 3000 if his lifetime `Points` stat is at least 100 / 1000 / 2000 / 3000 (`zc:21877-21894`, `Config:277-282`).
8. `supplies`: refused with `SHOP_ALL_ZONES_UPGRADED` when every owned zone is fully built and at full strength (`zc:21895-21923`).
9. `capture`: refused with `SHOP_NO_NEUTRAL_ZONES` when no eligible neutral zone exists (`zc:21925-21943`).
10. Enough unreserved credits, else `SHOP_NOT_ENOUGH_CREDITS_FOR_ITEM` (`zc:21945-21953`).
11. Stock not exhausted, else `SHOP_OUT_OF_STOCK` (`zc:21955-21962`).
12. If the target zone is "idle-suspended" (dormant zone), the zone is woken up, the buyer gets `SHOP_TARGET_STANDBY`, and a 0.5 s `timer.scheduleFunction` loop retries the purchase until the zone is awake or `idleZoneWakeHoldSec` elapses (`zc:21980-22018`).
13. The action runs; on success the cost is debited, the stock decremented, `Points spent` is added to the buyer's stats and career spending, and the coalition gets `SHOP_BOUGHT_BY_PLAYER` (or `SHOP_BOUGHT` when bought without a player, e.g. by AI or a marker out of slot) (`zc:22056-22113`).

Deferred payment ("pending shop purchase"): for `supplies`, `supplies2`, `capture`, `advancecapture` (and in PvP `groundattack` and flights) a purchase record `{coalition,id,cost,buyerGroupId,buyerName,itemName}` is attached to the `GroupCommander` that will deliver, its cost is reserved, and the debit happens only in `_completePendingShopPurchase` when the delivery group actually launches; `_failPendingShopPurchase` releases the reservation with an optional message (`zc:22030-22034`, `zc:21575-21671`).

The red AI commander also buys through the same function, with a Director-supplied price (`alternateParams._redDirectorPurchase`, `_directorShopCost`) (`zc:21804-21808`).

### CTLD debit/credit hooks

- `bc:debit(side, amount, groupId, groupObj, reason, reqRank)` is the entry point used by CTLD to charge a crate/troop: it checks the buyer's rank against `reqRank` ("Insufficient rank for …"), then the balance ("Our team does not have enough credits for …"), debits, adds `Points spent`, and announces "X spent N credits on CTLD …" to the coalition (`zc:21466-21513`).
- `bc:credit(...)` refunds (e.g. crate returned) and reduces `Points spent` (`zc:21516-21548`).
- `CTLDCost = true` enables these costs; `CTLDPrices[name] = {available, price, reqRank}` lists price and rank for each CTLD item (`Config:1958-1959`, `Config:1975-2058`).

## 3. Personal ("unclaimed") credits and how they are earned

### Principle

- A player in an aircraft does not feed the coalition account directly: every reward goes to `bc.playerContributions[side][playerName]`, a temporary purse that only becomes coalition credits (and personal rank credits) when the player lands in a friendly zone (`zc:41264-41273`, `zc:41818-41922`).
- Rewards are shared with the whole multicrew: `addContribution` adds the same amount to each crew member returned by `getMulticrewPlayersNow` (`zc:41264-41273`).
- A player is "enrolled" when `playerContributions[side][name] ~= nil`; most reward paths test this before paying (`zc:42876`, `zc:41483`, `zc:98272`).
- A 60 s `SCHEDULER` (first run at 1 s) drops the purse of players who are neither in a unit of that coalition nor connected on that side (`zc:43110-43148`).
- The rewards are switched on by the setup with `bc:startRewardPlayerContribution(15, RewardContribution)`: 15 is the default reward for an unclassified kill, the table is the Config reward table (`Setup:6000`, `zc:43016-43019`).

### Reward table (`RewardContribution`, `Config:1920-1936`)

| Key | Default | Paid when | Code |
|---|---|---|---|
| `infantry` | 10 | kill of a unit with attribute `Infantry` | `zc:43181-43184` |
| `ground` | 10 | kill of a unit with attribute `Ground Units` | `zc:43189-43192` |
| `sam` | 30 | kill of a unit with `SAM SR`, `SAM TR` or `IR Guided SAM` | `zc:43177-43180` |
| `airplane` | 50 | kill of a unit with `Planes` | `zc:43169-43172` |
| `helicopter` | 50 | kill of a unit with `Helicopters` | `zc:43173-43176` |
| `ship` | 200 | kill of a unit with `Ships` | `zc:43185-43188` |
| `structure` | 100 | kill of an object with `Buildings`, or of a category-4 static that is a zone "built" group or the zone warehouse facility | `zc:43193-43225` |
| (default) 15 | — | any other static (message `REWARD_UNIT_KILL`) | `zc:43165`, `zc:43226-43228` |
| `ctldGround` / `ctldAir` | 10 / 20 | a ground unit that the player built with CTLD kills an enemy ground / air unit | `zc:42827-42849`, `zc:42791-42810` |
| `crate` | 100 | a supply crate is delivered to a friendly zone (paid straight to the coalition; 25 % if the zone has no demand) | `zc:55236-55246` |
| `rescue` | 200 | a downed pilot is picked up (plus the 75 % the ejected player had lost) | `zc:100540-100550` |
| `enemyPilotCapture` | 200 | per enemy pilot delivered to a friendly zone | `zc:42284-42300` |
| `Zone upgrade` | 100 | player supply delivered to a friendly zone (25 % when the zone cannot receive supply) | `zc:98269-98290` |
| `Zone capture` | 200 | player supply delivered to a neutral zone that results in a capture | `zc:98248-98267`, `zc:24691-24710` |
| `Warehouse delivery` | 150 | CTLD warehouse cargo delivered (hook in the CTLD script) | `Foothold CTLD.lua:5305` |

- Critical statics of a zone (`zone.criticalObjects`) never pay (`zc:43155-43163`).
- Other earners: flight time (§3.3), air refuelling (§3.4), career achievements (§9), player missions (§10–11).

### 3.1 Kill attribution

- One `world.addEventHandler` is installed by `BattleCommander:init`; it calls `_handleWorldEvent` for every event (`zc:30226-30231`).
- Reward-relevant event ids are `S_EVENT_LAND`, `S_EVENT_EJECTION`, `S_EVENT_PILOT_DEAD`, `S_EVENT_KILL`, `S_EVENT_SCORE`, `S_EVENT_UNIT_LOST` (`zc:43024-43031`); `S_EVENT_TAKEOFF`, `S_EVENT_BIRTH` (id 15), `S_EVENT_LANDING_AFTER_EJECTION`, `S_EVENT_SHOT` (Hercules cargo) and `S_EVENT_DEAD` (airdrome runway only) are dispatched earlier in the same function (`zc:42906-42992`).
- `S_EVENT_HIT` is not used for attribution: the kill credit relies only on `S_EVENT_KILL` (initiator = killer, target = victim) (`zc:43041-43044`, `zc:42812-42891`).
- `_handleRewardKillEvent`: the initiator must be a player-controlled airplane or helicopter (`unit:getPlayerName()`), enrolled, and the target coalition must differ and not be neutral (`zc:42868-42887`).
- Same-coalition target → friendly-fire branch (§3.6) (`zc:42878-42879`).
- Enemy target → `_handleRewardEnemyKill`: classifies the target with `objectToRewardPoints2`, adds the earning to the purse, adds one temp stat of the class, records the career kill, feeds the CAS/SEAD/CAP mission counters and the mission-target registry (`zc:42677-42789`).
- The per-kill message `[player] <text>` is shown to the killer's group only if `ShowKills == true` (Config, default `false`) (`zc:42711-42714`, `Config:275`).
- A ground unit whose `unit:getID()` is registered in `Foothold_ctld.PlayerCtldRewards.unitsById` credits its builder (`ctldGround`/`ctldAir`) when it kills an enemy (`zc:42827-42849`).
- AI kills (no player name) are only recorded as "air combat evidence" for the AI Director, not rewarded (`zc:42888-42890`, `zc:42584-42639`).
- Splash kills: `Splash_Damage_3.4.1_leka.lua` is an optional script (`SplashDamage`, Config default `false`, `Config:272-273`); the reward path has no dedicated splash attribution and only reacts to the `S_EVENT_KILL` it receives (what the splash script itself emits: not read, estimation).
- `S_EVENT_SCORE` is used for "score targets" (scenery/static strike objectives): when a player triggers a score event with comment `general` and amount 0, a 6 s timer re-checks every registered `ScoreTargets[flag]` object and counts those whose relative life is ≤ 50 % as destroyed (`zc:42083-42131`).

### 3.2 Banking on landing, losing on death

- Takeoff (`S_EVENT_TAKEOFF` → `LogisticCommander:_handleTakeoff` → `_armPlayerTakeoffRewardState`): arms the loss penalty (`lossPenaltyArmByPlayer[player] = true` when `CreditLosewhenKilled` or `RankLoseWhenKilled`), promotes a turnaround bonus from `armed` to `active`, and records `flightTimeTakeoffByPlayer[player] = {t, gid, rewardEligible}` (`zc:42947-42979`, `zc:101289-101318`).
- Landing (`S_EVENT_LAND`, player): `_handleRewardPlayerLanding` first delivers carried enemy pilots, then, if the purse is positive or a flight-time reward is due, looks for a friendly zone containing the landing point (`CustomZone:isInside`), else a `CTLD FARP` / `Escort Mission FARP` zone (Moose `GROUP:IsInZone`), else a carrier within 200 m (`zc:42442-42582`).
- The player gets `PLAYER_LANDED_CLAIM_ZONE` ("landed at <zone>, wait N seconds") and a one-shot `SCHEDULER` fires 5 s later (10 s on a carrier); the claim is paid only if the same unit object is still there, still landed (`Utils.isLanded`), alive (`getLife() > 0`), inside the zone, and the zone still belongs to his side (`zc:42486-42513`, `zc:42568-42577`).
- `_claimLandingRewards` (per crew member): amount = purse + turnaround bonus + night bonus; `bc:addFunds(side, amount)`; temp stats are committed to the persistent stats with `Points += amount`; the purse is zeroed; with `RankingSystem` the same amount is added to the personal rank credits and a promotion is announced with `PLAYER_PROMOTED` and the sound `Rank.ogg`, then the shop menu of the group is rebuilt (`zc:41869-41917`).
- The coalition gets one redeem message listing each crew member, amount and the per-flight stats (`PLAYER_REDEEM_HEADER`, `PLAYER_REDEEM_LINE`, `zc:41839`, `zc:41889`, `zc:41918-41920`).
- A reward earned by a player who is already on the ground (e.g. a joint-mission partner finishing the job) triggers a synthetic `S_EVENT_LAND` through `world.onEvent` after 5 s so that it is banked without a new flight (`zc:41316-41328`).
- Ejection (`S_EVENT_EJECTION`): 25 % of the purse goes to the coalition immediately (`PLAYER_EJECTED_CREDITS`), the player gets `Points +25 %` and `Deaths +1`, the purse is zeroed, and the remaining 75 % is stored as `lostCredits` in an `ejectedPilotOwnersByAircraft[aircraftId]` record attached to the downed pilot, recoverable by whoever rescues him (`zc:42133-42159`, `zc:41742-41803`).
- Pilot death (`S_EVENT_PILOT_DEAD`): `Deaths +1`, temp stats reset, mission kill counters reset, joint party left; the purse itself is cleared at the next slot birth by `_cleanupPlayerRespawnRewardState` (`zc:42161-42206`, `zc:41658-41693`).
- Aircraft lost (`S_EVENT_UNIT_LOST`) with the penalty armed: 2 s later, unless the loss was a team-kill by another player (`lossPenaltySkipByPlayer`), the coalition loses `CreditLosewhenKilledAmount` (if enabled) and the player loses `RankLoseWhenKilledAmount` rank credits and `Points`, with `PLAYER_AIRCRAFT_LOST_CREDITS`, `PLAYER_AIRCRAFT_LOST_RANK` and possibly `PLAYER_DEMOTED` (`zc:42208-42255`).

### 3.3 Flight time, turnaround and night bonuses

- `RewardFlightTime` (default `true`), `FlightTimeRewardPerMinute` (2), `RewardAllAircraft` (`false`) and the per-type table `AllowedFlightTimeReward` (only C-130J-30, CH-47F and Hercules are `true` by default) pay `minutes × rate` when the flight lasted at least 300 s; the stat `Flight time` is added in minutes (`Config:2262-2303`, `zc:41826-41837`).
- The flight-time reward is also paid on ejection (`zc:41727-41740`).
- `TurnaroundRewardPercent` (default 10, max 50): after a qualifying flight (≥ 300 s) that redeemed credits the state becomes `armed`; taking off again makes it `active`; the next redeem gets `+N %` (`PLAYER_REDEEM_SAME_AIRCRAFT_BONUS`); any loss, ejection, death or respawn clears it (`Config:1586-1589`, `zc:41876-41879`, `zc:41913-41915`, `zc:101296-101303`, `zc:42209`, `zc:41664`).
- `NightRewardPercent` (default 10, max 50): if the takeoff happened at night and the flight lasted ≥ 5 min with the same unit object, the redeem gets `+N %` (`PLAYER_REDEEM_NIGHT_OPERATION_BONUS`) (`Config:1591-1594`, `zc:41838`, `zc:41880-41888`).
- Night is computed in-engine with a sunrise/sunset formula (same model as Moose `GetSunRiseAndSet`) from `coord.LOtoLL` of the departure zone, `env.mission.date`, and a per-theatre UTC offset table; results are cached per zone and per day (`zc:41504-41612`).

### 3.4 Air refuelling reward

- `RefuelReward` (default 2 credits per 100 lb) and `RefuelRewardMinimumLbs` (100) (`Config:1938-1939`, `zc:11993-11994`).
- Implemented in `WelcomeMessage.lua` on Moose `EVENTS.Refueling` / `EVENTS.RefuelingStop` (DCS `S_EVENT_REFUELING` / `S_EVENT_REFUELING_STOP`): the fuel fraction at start is stored per unit; at stop, `gained = Δfuel × fuelMassMax × 2.2046`; the reward goes to the purse, the stat `Refueling` is counted once per sortie, and the lbs are added to the career stat (`WelcomeMessage.lua:2731-2829`).
- When the start event comes from the tanker (no player initiator), every player aircraft within 300 m of the tanker is registered as refuelling (`WelcomeMessage.lua:2751-2776`).

### 3.5 Logistics, CSAR and capture hooks (reward side only)

- Supply unloaded by a player in a friendly zone: `Zone upgrade` reward to the purse and `Zone upgrade +1` (25 % and a "no demand" message if the zone cannot receive supply) (`zc:98269-98290`).
- Supply unloaded in a neutral zone starts a "pending capture" with a delivery payload `{captureFundReward, upgradeFundReward, playerName}`; the reward is paid when the capture delivery succeeds, by the registered handler `zonecommander_capture_delivery` (`zc:98248-98267`, `zc:30232-30234`, `zc:24691-24710`).
- Pilot rescue: `rewards.rescue` plus the victim's `lostCredits`, stat `Pilot Rescue`, message `CSAR_RESCUED_WITH_CREDITS` (`zc:100538-100558`).
- Enemy pilot delivered: `enemyPilotCapture × count`, stat `Enemy Pilot Capture`, then after a random 10–60 s a "debrief" with a 50 % chance per pilot to grant 30 min of zone intel and 20 % to reveal the enemy Director's current operation (`zc:42284-42363`, `zc:42365-42440`).
- `CsarPilotSpawnWithoutCreditsChance` (default 50): chance to spawn a downed pilot when the ejecting pilot carried no credits (`Config:2229-2230`).

### 3.6 Friendly fire

- A kill on a same-coalition target announces `FRIENDLY_FIRE_PLAYER` / `FRIENDLY_FIRE_UNIT` to the coalition, records a career friendly kill, flags the victim so that he is not charged the loss penalty, and, with `RankingSystem` and the penalty armed (i.e. after a takeoff), removes `FriendlyFireRankPenalty` (default 500) rank credits and `Points`, at most once per 30 s (`zc:42641-42675`, `Config:287-288`).

### Mechanism notes

- State tables: `playerContributions[side][name]`, `tempStats[name][stat]` (current sortie), `sessionStats`, `playerStats` (persistent), `flightTimeTakeoffByPlayer`, `turnaroundRewardStateByPlayer`, `lossPenaltyArmByPlayer`, `lossPenaltySkipByPlayer`, `lossPenaltyCooldownUntilByPlayer`, `refuelLbsByPlayer`, `ejectedPilotOwnersByAircraft` (`zc:40510-40575`, `zc:43020-43021`, `zc:41767-41770`).
- Moose used: `SCHEDULER:New` (wraps `timer.scheduleFunction`) for the delayed claims and the 60 s purge, `UNIT:Find():IsInZone`, `GROUP:FindByName():IsInZone`, `COORDINATE` for the FARP/carrier cases, Moose event handlers in `WelcomeMessage.lua` for refuelling (`zc:42498-42499`, `zc:42512`, `zc:42529-42534`, `zc:42561-42562`).
- Multicrew handling uses `net.get_player_list` and `net.get_player_info(pid,'slot')` to tell the pilot (sub-slot 0) from the crew (`zc:40551-40571`, `zc:42134-42136`).

### Reproduction notes

- The "bank on landing" rule needs a robust landed test, object identity (`unit.id_`) across the 5 s delay and a zone-ownership re-check; a touch-and-go must not pay.
- Multicrew sharing depends on the `net.*` API being reachable from the mission scripting environment.
- The reward classification relies on DCS unit attributes (`hasAttribute`), not on type lists.
- All per-event work is O(1) except `objectToRewardPoints2` for statics, which scans every zone's `criticalObjects` and `built` lists (`zc:43155-43163`, `zc:43202-43215`).

## 4. The shop menu (F10) and the map-marker shop

### Player view

- Root: `F10 > Other > Shop` (`MENU_SHOP` = "Shop"), one menu per player group (`zc:22400-22402`, `L10N:161`).
- Under it, one submenu per category that has at least one visible item, in a fixed order: "AI Attack", "Zone Upgrades", "JTAC & Intel", "Marking & Tools", "Combined Arms", "Capture & resources", "Other support" (`Setup:5515-5534`, `zc:22445-22476`, `zc:22524-22530`, `L10N:548-553`).
- Each item is labelled `[<cost>] <name>` (`SHOP_ITEM_LABEL`, `zc:22492`, `L10N:1549`).
- An item that needs a target is a submenu listing the candidate zones (ordered by the zone's waypoint number, nearest-to-front first according to `sortPolicy`), each zone label optionally suffixed with the waypoint tag and `built/total` upgrade count; items without a selector are direct commands (`zc:22506-22520`, `zc:22166-22231`).
- Lists longer than 9 entries are paged with nested "More" submenus (9 entries, then a `MENU_MORE` submenu, recursively) (`zc:22353-22368`, `zc:22488-22504`).
- Last entry of the Shop menu: "Budget overview" (`zc:22411-22413`, `zc:22531`).
- Items whose `reqRank` is above the player's rank are not shown at all (`zc:22428-22439`).
- An empty selector shows a single informative line (e.g. "No eligible zone") (`zc:22300-22305`).
- Marker shop: a map mark whose text is `buy` prints the list with the ids (`buy:<id>`); a mark `buy:<id>` buys the item with `{zone = zone under the mark, point = mark position}` as parameters; the rank is checked first with a detailed "Insufficient rank" message (`zc:28555-28620`).
- `adminbuy` / `adminbuy:<id>` do the same without buyer and therefore without rank check, when `AllowAdminBuy` (Config default `true`); the admin alias `buyWithoutRank` (or the legacy Swedish `köp`) does the same (`zc:28622-28706`, `Config:1946-1948`, `Config:3488-3489`).
- Other marker texts related to this theme are reserved words: `stats`, `top`, `mystats`, `missions`, `intelstatus`, `addrank:<name>,<n>`, `caphere1/2`, `arcohere1/2`, `texacohere1/2`, `farphere…` (`zc:28358-28408`).

### Mechanism

- Menus are built with the raw DCS API (`missionCommands.addSubMenuForGroup`, `addCommandForGroup`, `removeItemForGroup`), not Moose `MENU_*` (`zc:22401-22413`, `zc:22519`).
- State per group: `bc.groupSupportMenus[groupId] = {menu, items = {handles}, selectorNodes = {[itemId] = {menu, children, category, coalition, defaultRows}}}` (`zc:22400-22410`, `zc:22510-22516`).
- `refreshShopMenuForGroup` removes every tracked child handle and rebuilds the whole tree for one group; it is called at slot birth, on promotion/demotion, when an item is added/removed from the shelf (`zc:22395-22533`, `zc:41907`, `zc:42248`, `zc:19358`, `zc:19365`).
- A legacy coalition-wide menu "shop for all" (`refreshShopMenuForCoalition`, `missionCommands.addCommandForCoalition`) still exists in the code (`zc:13041-13072`).
- Selector refresh (zones changing side, upgrades, supply demand): `requestShopSelectorRefreshForCoalition(side, tags|itemIds)` accumulates dirty items, a 0.15 s debounce `SCHEDULER` flushes them into a work queue, and a worker runs every `shopSelectorRefreshInterval` (0.5 s) processing at most `shopSelectorRefreshBudget` (8) "group × item" jobs per tick; every fourth tick is reserved for the Dynamic Control menu when both queues have work (`zc:17382-17411`, `zc:17615-17689`).
- A selector rebuild is skipped when the candidate rows and labels are unchanged for that group/locale (`zc:22266-22279`).
- Candidate zones come from pre-computed "buckets" (`blue_unsuspended`, `enemy_unsuspended`, …) maintained incrementally when a zone changes state, or from a `candidatesBuilder`, or from all zones; filters are `targetzoneside`, `allow`, `extraPredicate`, `includeSuspended` (`zc:22147-22215`, `zc:34139-34220` — bucket maintenance not read in detail).
- The marker shop is an event handler on event id 26 (`S_EVENT_MARK_CHANGE`) installed by `startMonitorPlayerMarkers` (`zc:28354`, `zc:28455-28456`).
- Text is localised per group through `L10N:ForGroup(groupId)`; item names may be functions `name(T)` resolved at display time (`zc:19307-19320`).

### Reproduction notes

- The DCS F10 menu holds 10 entries per level, hence the paging code everywhere.
- Rebuilding group menus is expensive with many players and many zones; the queue + budget + "unchanged" check exist to avoid frame hitches and command-id churn.
- `missionCommands.removeItemForGroup` on a parent removes its children, so the handles must be tracked per group and dropped when the group dies.

## 5. Shop catalogue (Caucasus setup, default Config)

Columns: price = `ShopPrices` (`Config:1771-1842`); rank = `ShopRankRequirements` (`Config:1846-1916`); stock from `addShopItem` (`Setup:5504-5751`): ∞ = `-1`.
"Blue" = on the blue shelf; "PvP red" = also on the red shelf when `GlobalSettings.pvpEnabled`.

### AI Attack

| id | Name | Price | Rank | Stock | Target selection | Effect | Code |
|---|---|---|---|---|---|---|---|
| `dynamiccap` | CAP Flight | 500 | 2 | ∞ (one active at a time) | friendly zone → Orbit, or heading (Hot 360…315) → leg 10–50 NM | spawns an AI fighter flight that orbits/racetracks at the zone; see §6 | `Setup:3009-3096`, `Setup:5537-5538` |
| `dynamiccas` | CAS Flight | 1000 | 5 | ∞ (one active) | enemy zone | spawns a CAS flight from the closest safe friendly zone, attacks the zone | `Setup:3283-3353`, `zc:107991` |
| `dynamicbomb` | Bomber Flight | 500 | 4 | ∞ (one active) | enemy zone | spawns a bomber flight that bombs the zone | `Setup:3580-3645`, `zc:109391` |
| `dynamicsead` | SEAD Flight | 500 | 4 | ∞ (one active) | enemy zone → "Push when ready/now" or "Push on command" | spawns a SEAD flight; in command mode it holds until the player uses Dynamic Control > Push | `Setup:3450-3570`, `zc:108779`, `zc:108699` |
| `dynamicdecoy` | TALD Decoy Flight | 300 | 1 | ∞ | enemy zone (+ push mode) | spawns a flight launching decoys toward the zone | `Setup:3360-3447`, `zc:108316` |
| `dynamicstatic` | Static structure Flight | 500 | 4 | ∞ | enemy zone that has structures | spawns a strike flight against the zone's buildings | `Setup:3841-3882`, `zc:109719` |
| `groundattack` | Ground attack | 1000 | 5 | ∞ | enemy zone (PvP: optional FARP origin) | launches a ground convoy from the closest friendly zone or FARP within range | `Setup:4473-4544`, `zc:20673` |
| `strategicbomber` | Strategic Bomber | 1500 | 6 | ∞ | enemy zone → origin / escort options built by `StrategicBomber.BuildBlueShopMenu` | launches a heavy bomber raid with AI or player escort | `Setup:3652-3838`, `zc:3518`, `zc:3759` |
| `cruisemsl` | Cruise Missile Strike | 800 | 10 | 12 | — | put on the shelf by `addShopItem` but **not registered** in the Caucasus setup, so it never appears there; it is registered in the Syria, Persian Gulf and South Atlantic setups (not read) | `Setup:5555`, `zc:19342-19344` |

### Zone Upgrades (adds a permanent defensive group to a friendly zone)

| id | Name | Price | Rank | Template added | Code |
|---|---|---|---|---|---|
| `zinf` | Infantry | 500 | 5 | `blueInfantry` | `Setup:4869-4910` |
| `zarm` | Armor | 1000 | 7 | `Blue Armor Modern` / `Coldwar` / `Vietnam` by era | `Setup:5275-5320`, `Setup:39-41` |
| `zhawk` | Hawk | 2000 | 6 | `Blue SAM HAWK` | `Setup:4977-4991` |
| `zsam` | NASAMS (Modern only) | 2000 | 6 | NASAMS template | `Setup:4913-4975`, `Setup:5845-5848` |
| `zpat` | Patriot (not Vietnam) | 5000 | 8 | Patriot; one per zone | `Setup:5342-5346`, `zc:21854-21862` |
| `zavenger` | Avenger | 1000 | 5 | `Blue SAM SHORAD Avenger` | `Setup:4979` |
| `zroland` | Roland | 1000 | 5 | `Blue SAM SHORAD Roland` | `Setup:4980` |
| `zgepard` | Gepard | 750 | 4 | `Blue SAM AAA Gepard` | `Setup:4981` |
| `zvulcan` | Vulcan | 500 | 3 | `Blue SAM AAA Vulcan` | `Setup:4982` |
| `zcram` | C-RAM (Modern only) | 1500 | 6 | `Blue SAM AAA C-RAM` | `Setup:4983` |
| `zpantsir` | Pantsir (PvP, Modern) | 1500 | 6 | `Blue SAM SHORAD Pantsir` | `Setup:4993-5001` |
| `zhimars` | HIMARS (Modern) | 2500 | 8 | `HiMars` | `Setup:5005-5046` |
| `zgci` | GCI station | 500 | 3 | `BlueGCI` | `Setup:5352-5394` |
| `zewr` | EWR (PvP) | 500 | 3 | `Blue EWR Upgrade` | `Setup:5614-5622` |
| `gslot` | Unlock extra upgrade slot | 3000 | 9 | stock 1; raises the per-zone limit by one | `Setup:5322-5338` |

- Target: a friendly, active, non-carrier zone whose `upgradesUsed` is below the limit (`isEligibleBlueZoneUpgradeTarget`, `zc:23786-23800`).
- Limit of purchased upgrades per zone: 2 for blue (1 for red in PvE), +1 once `gslot` has been bought (`bc.globalExtraUnlock`) (`zc:23778-23784`, `zc:48130-48136`).
- Effect: `zone:addExtraSlot(template)` increments `upgradesUsed` and `level`, appends the template to `zone.upgrades.blue|red` and to `zone.extraUpgrade` (persisted); the group then appears through the normal zone build/upgrade cycle (`zc:48130-48161`).
- Message `SYRIA_SHOP_UPGRADE_ADDED` to the coalition; `bc:refreshZoneLabel` updates the map label (`Setup:4889-4893`).

### JTAC & Intel

| id | Name | Price | Rank | Target | Effect | Code |
|---|---|---|---|---|---|---|
| `jtac` | MQ-9 Reaper JTAC | 500 | 2 | enemy zone | deploys one of two JTAC drones over the zone (max 2 active, the oldest is removed) and shows its menu | `Setup:4246-4275` |
| `smoke` | Smoke markers | 20 | 1 | enemy zone | `trigger.action.smoke` on up to 3 random units/statics of the zone | `Setup:4547-4574`, `zc:23618-23660` |
| `flare` | Flare markers | 20 | 1 | enemy zone | 3 bursts of red `trigger.action.signalFlare`, 5 s apart, on up to 3 targets | `Setup:4577-4604`, `zc:23662-23694` |
| `illum` | Illumination bomb | 100 | 1 | enemy zone | illumination bombs at 1000 m above the zone's groups (power 700000) | `Setup:4607-4634`, `zc:23696-23716` |
| `intel` | Satellite Intel | 150 | 5 | enemy zone | `startZoneIntel(zone, nil, side)`: 60 min of intel on the zone (map markers of units, refreshed periodically) | `Setup:4762-4795`, `zc:6954-6963` |
| `9lineam` / `9linefm` | JTAC 9-line AM / FM | 0 | 1 | enemy zone | free radio 9-line JTAC drone on the zone | `Setup:4316-4410` |

### Combined Arms (PvE only)

| id | Name | Price | Rank | Effect | Code |
|---|---|---|---|---|---|
| `armor` | Deploy armor | 100 | 3 | `CustomZone:spawnGroup('ca-tanks')` in a friendly zone (a player-drivable group) | `Setup:4057-4079` |
| `artillery` | Deploy artillery | 100 | 3 | `spawnGroup('ca-arty')` | `Setup:4083-4105` |
| `recon` | Deploy recon | 50 | 3 | `spawnGroup('ca-recon')` | `Setup:4109-4131` |
| `airdef` | Deploy air defence | 150 | 3 | `spawnGroup('ca-airdef')` | `Setup:4135-4157` |
| `calav` / `camgs` / `cadragoon` | Deploy LAV-25 / M1128 MGS / M1296 Dragoon | 100 | 3 | `spawnGroup('CA-…Hunter_Killer_…')` | `Setup:4161-4232` |

### Capture & resources

| id | Name | Price | Rank | Target | Effect | Code |
|---|---|---|---|---|---|---|
| `capture` | Capture neutral zone | 500 | 1 | neutral zone | `bc:requestCaptureMission`: dispatches the nearest available AI supply group (helo, plane, convoy) to capture it; paid when it launches | `Setup:4638-4731`, `zc:23416` |
| `advancecapture` | Advance capture (PvE) | 500 | 1 | enemy zone with ≤ `AdvanceCaptureRemainingThreshold` % of its upgrade groups left | same, launched before the zone is neutral | `Setup:4733-4758`, `Config:1598-1602`, `zc:50133` |
| `supplies2` | Resupply friendly zone | 200 | 1 | friendly zone needing supply | `bc:requestFriendlySupplyMission` (AI delivery, max 2 paid deliveries in progress per zone) or, with `AllowScriptedSupplies`, an immediate stock/upgrade step | `Setup:3893-4014`, `zc:23255-23300` |
| `supplies` | Fully upgrade friendly zone | 1000 | 6 | friendly zone not fully built | `zone:UpgradeUntilComplete` (only on the shelf when `AllowScriptedSupplies`) | `Setup:4017-4052`, `Setup:5727-5731` |
| `zlogc` | Logistic Center [WH] | 5000 | 1 | fully upgraded friendly airbase zone | spawns a warehouse static `[WH] <zone>` and activates warehouse logistics | `Setup:5048-5066`, `zc:24155-24200` |
| `zwhrepair` | Repair Logistic Center | 2000 | 1 | zone whose warehouse is destroyed | 30 min repair timer | `Setup:5069-5086`, `zc:24236-24253` |
| `zsup3` | Add 3 supplies to zone (PvE) | 750 | 2 | friendly zone | `bc:applyZoneSupplyStockAdd(zone, 3)` | `Setup:5089-5106` |
| `zwh50` | Resupply warehouse with 50 (PvE) | 500 | 2 | zone with warehouse | `bc:applyWarehouseResupply` | `Setup:5108-5128` |

### Other support

| id | Name | Price | Rank | Stock | Target | Effect | Code |
|---|---|---|---|---|---|---|---|
| `dynamicarco` | Tanker (Drogue) | 1000 | 3 | 1 | friendly zone → orbit or heading/leg | one-time unlock; afterwards the tanker is re-positioned for free from Dynamic Control or with `arcohere1/2` marks | `Setup:3099-3189`, `zc:21809-21852`, `zc:107690` |
| `dynamictexaco` | Tanker (Boom) | 1000 | 3 | 1 | same | same | `Setup:3191-3281`, `zc:107813` |
| `farphere` | Deploy FARP | 1000 | 4 | ∞ | map marker `buy:farphere` only (the menu entry just prints the help) | an AI helicopter flies from the nearest friendly airbase/FARP to the mark and builds a FARP; refused inside a zone, within 10 NM of an enemy zone, or without a flat spot within 100 m | `Setup:5398-5403`, `zc:21332-21380` |
| `replaceawacs` | Replace one lost AWACS (PvP) | 1000 | 3 | — | none | `bc:replaceLostAwacs(side)` | `Setup:3283-3285`, `zc:106029` |

### Red AI items (PvE; bought by the red Director, not by players)

| id | Price | Effect | Code |
|---|---|---|---|
| `redzoneupgrade` | 3000 (`RED_ZONE_UPGRADE_COST`, `Setup:4799`) | the Director picks a red zone and adds an upgrade slot, then upgrades it at once; announced to both sides (`WAREHOUSE_RED_REINFORCED`) | `Setup:4802-4808`, `zc:24115-24153` |
| `redmassattack` | 2500 | `bc:triggerRedMassAttack()` | `Setup:4811-4822`, `zc:35003` |
| `strategicbomberRed` | 1500 | `StrategicBomber.LaunchRed()` | `Setup:4827-4829` |
| `redwarehouse` / `redwhrepair` | 3000 / 2000 (setup defaults, absent from the Config table, `Setup:2931-2932`) | create / repair a red rear supply depot | `Setup:4833-4865` |

- The red account is fed by the red side's own income rules and spent by `BudgetCommander`/the Director (another theme); the shelf entries are `bc:addShopItem(1, …)` (`Setup:5504-5512`).

### Red shop in PvP

- With `PvP = true` the red coalition gets its own shelf with the flight items, `groundattack`, `strategicbomber`, `gslot`, markers, intel, `capture`, `supplies2`, `supplies`, `zlogc`, `zwhrepair`, tankers and `farphere` (`Setup:5538-5551`, `Setup:5574-5576`, `Setup:5690-5702`, `Setup:5723-5736`, `Setup:5745-5751`).
- Red zone upgrades are separate items `rzinf`, `rzarm1-3`, `rzaaa`, `rzsa2`, `rzsa3`, `rzsa6`, `rzsa10`, `rzsa11`, `rzsa8`, `rzsa9`, `rzsa13`, `rzsa15`, `rzsa19`, `rztorm2`, `rzpantsir`, `rzmanpad`, `rzgci`, `rzarty`, `rzewr`, each priced and ranked like a blue "tier" item (e.g. `rzsa10` = `zpat`), filtered by era, template presence and `RedTemplateEnabled` (`Setup:5637-5683`).
- Each PvP item carries `upgradeSide`; `buyShopItem` refuses a purchase from the other coalition (`zc:21791-21803`).
- Flight items in PvP keep one runtime per side in `item.flightBySide[side]` and need a group template for that side (`zc:19332-19338`, `Setup:3066-3075`).

### How purchased effects are executed (summary)

- AI flights (`dynamiccap`, `dynamiccas`, `dynamicsead`, `dynamicdecoy`, `dynamicbomb`, `dynamicstatic`): Moose `SPAWN:NewFromTemplate(...)` then `SpawnAtParkingSpot` / `SpawnAtAirbase` (when `AIAttackTakeoffFromGround`, Config default `true`) or `SpawnFromCoordinate` (air start); the resulting Moose `GROUP` is given options and a route (`COORDINATE:WaypointAir…`, `GROUP:Route`) (`zc:107095-107111`, `zc:108165-108185`, `zc:107270-107273`, `zc:107306-107316`, `Config:1941-1944`).
- Every purchased flight is registered in `DynamicSupportNative.groups[groupName]` with callbacks and messages (`airborneMessage`, `winchesterMessage`, `landedMessage`, `killedMessage`) (`zc:106367`, `zc:107276-107325`).
- A single shared `timer.scheduleFunction` loop (30 s, only alive while at least one record exists) reads `unit:getAmmo()` of each flight; when a flight that had mission ammo has none left it fires `onWinchester` (RTB route to the nearest friendly airdrome) and tells the coalition (`zc:106303-106365`, `zc:107283-107316`).
- `S_EVENT_TAKEOFF`, `S_EVENT_LAND` and `S_EVENT_UNIT_LOST` of these groups are routed to `DynamicSupportNative:HandleTakeoff/HandleLanding/HandleUnitLost`, which free the "one active flight" slot and send the landed/killed message (`zc:42965-42972`, `zc:42262-42266`, `zc:43070-43073`, `zc:106402-106425`, `zc:106454-106469`).
- A navy artillery item exists in the engine (`spawnNavyArtyAt`) and uses Moose `AUFTRAG:NewARTY` and `FLIGHTGROUP` / `AUFTRAG:NewANTISHIP` (OPS layer); it is not on the Caucasus shelf (`zc:109950-110075`).
- The strategic bomber uses its own module (`StrategicBomber`, `zc:2350-4195`; internals belong to the AI themes); the shop only calls `StrategicBomber.LaunchBlue/LaunchRed` and `BuildBlueShopMenu` (`Setup:3743-3757`, `Setup:3775`).

### Dynamic Control menu (control of purchased support)

- `F10 > Other > Dynamic Control` (`MENU_DYNAMIC_CONTROL`), per group, rebuilt by `refreshDynamicControlMenuForGroup` (`zc:16259`, `zc:16425`).
- Entries seen in the code: CAP control (reposition by zone, reposition by position, hold racetrack, flight sweep, help, destroy), SEAD push / destroy, decoy push / destroy, CAS destroy, bomber destroy, building-strike destroy, navy arty destroy, strategic bomber push / destroy, tankers control and info, carrier navigation and info (label keys `DYNAMIC_*`; internal layout not read in detail, estimation for the exact nesting).
- Tanker control and carrier navigation are rank-gated (`_getTankerRequiredRank`, `CarrierRankRequirement = 5`) (`zc:13326`, `zc:13692`, `Config:290-292`).

## 6. CAP auto-buy after loss (6.5.2)

### Player / admin view

- `AllowCapAutoBuyAfterLoss` (default `false`, PvE only) and `MaxCapAutoBuys` (1–5, default 1) (`Config:1577-1584`).
- When enabled, each choice in the CAP purchase menu becomes a submenu with "Yes, Buy again if Dead" and "No" (`zc:22307-22341`).
- If the purchased CAP flight is entirely destroyed, the engine re-buys a CAP at the same launch zone, heading and leg, debiting the coalition again, up to the authorised number of replacements; when it cannot, the coalition gets `SHOP_CAP_AUTO_BUY_STOPPED` (`zc:106439-106466`).
- The buyer can cancel from Dynamic Control ("CAP auto-buy cancelled. The current flight will continue.") (`zc:106427-106437`).

### Mechanism

- An "order" `{buyer, remaining, launchZone, heading, leg, point, committed}` travels with the purchase; `buyShopItem` builds a pending purchase and calls `spawnCapAt(..., purchase, nil, target, order, isReplacement)` directly (`zc:22019-22029`).
- The payment is settled only once the flight has its route (`settlePurchasedCap`); if the coalition can no longer afford it at that moment the flight is destroyed (`zc:107229-107246`).
- Preconditions re-checked at each replacement: no CAP active, the buyer is still the same player in the same blue group (`_isCapAutoBuyBuyer`), the station zone is still eligible, the buyer's rank is still sufficient (`zc:21863-21876`, `zc:21753-21768`).
- Trigger: `DynamicSupportNative:HandleUnitLost` on `S_EVENT_UNIT_LOST` when no other unit of the group is alive (`zc:106454-106466`).

## 7. Ranks

### Player view

- 20 ranks, numbered 1–20; thresholds are personal rank credits: 0, 3000, 5000, 8000, 12000, 16000, 22000, 30000, 45000, 65000, 90000, 120000, 155000, 195000, 240000, 290000, 345000, 405000, 470000, 540000 (`zc:17231`).
- Names in the same order: Recruit, Aviator, Airman, Senior Airman, Staff Sergeant, Technical Sergeant, Master Sergeant, Senior Master Sergeant, Chief Master Sergeant, Second Lieutenant, First Lieutenant, Captain, Major, Lieutenant Colonel, Colonel, Brigadier General, Major General, Lieutenant General, General, General of the Air Force (`zc:17232`).
- `F10 > Stats and Settings > Stats > Rank Help` prints the ladder as a dotted table (`zc:40883-40908`, `zc:101209`).
- Promotion: coalition message `PLAYER_PROMOTED` and sound `Rank.ogg` at redeem time; demotion: `PLAYER_DEMOTED` (`zc:41897-41902`, `zc:42240-42242`).
- A rank unlocks: shop items (`ShopRankRequirements`, hidden below the rank), CTLD items (`CTLDPrices[...].reqRank`, checked in `bc:debit`), tanker control, carrier navigation (`CarrierRankRequirement = 5`) (`zc:22428-22439`, `zc:21478-21487`, `zc:13326`, `zc:13692`, `Config:292`).

### Mission-maker view

- `RankingSystem` (default `true`): when `false`, `reqRank` is never stored on shelf items and everyone sees the full shop (`Config:284-285`, `zc:19353-19357`).
- `RankLoseWhenKilled` (`true`) / `RankLoseWhenKilledAmount` (100), `FriendlyFireRankPenalty` (500) (`Config:266-270`, `Config:287-288`).
- `bc.rankThresholds` / `bc.rankNames` can be supplied to `BattleCommander:new` (they default only when absent) (`zc:17231-17232`).
- Admin marker `addrank:<player>,<n>` adjusts a player's rank credits (parsing at `zc:28394`; handler not read).

### Mechanism

- Rank credits are a separate counter from the coalition account: `record.credits` in the player's `RankSave` record, increased by exactly the amount redeemed at landing (`addPlayerRankCredits`), decreased by death / friendly-fire penalties, floored at 0 (`zc:44400-44408`, `zc:41895`, `zc:42237`, `zc:42668`).
- `getPlayerRank` walks the threshold array and returns the highest index whose threshold is reached (0 when the player has no record) (`zc:44384-44393`).
- Persistence: global table `RankSave = {players = {[ucid] = record}, legacyPlayers = {[name] = record}, playerAliases, version, …}` written to `<writedir>/Missions/Saves/Foothold_Ranks.lua` by `Utils.saveTable`, as part of the staged save job, only when `RankingSystem` is true (`zc:44332-44377`, `zc:44508`, `zc:44533`).
- Identity: records are keyed by UCID (resolved with `net.get_player_list` / `net.get_name`; UCID lookup itself not read), with a name→UCID alias cache and a "legacy" name-keyed table for players never seen with a UCID (`zc:43358-43378`, `zc:43685-43700`, `zc:43446-43466`).
- The same file also stores each player's EWRS and self-JTAC settings (`_syncRankEwrsSettings`, `_syncRankSelfJtacSettings`, `zc:44360-44361`).
- The rank file is independent of the campaign save, so ranks survive a campaign reset (the file path is separate, `zc:44334-44340`; reset behaviour itself not read, estimation).

## 8. Statistics and leaderboards

### Player view

- `F10 > Stats and Settings > Stats >` "My Stats", "Top 10 Players", "Top 5 Players", "Top 5 Today", "Rank Help", and a "Career" submenu (`zc:101203-101215`, `L10N:1018-1024`).
- "My Stats": leaderboard position (by `Points`), current rank, next rank and credits remaining, then Air, Helo, Ground Units, Ship, SAM, Structure, Deaths, Captured by enemy, Zone capture, Zone upgrade, Pilot Rescue, Enemy Pilot Capture, Refueling (with lbs), Points, Points spent, Flight time (min) (`zc:40638-40742`).
- "Top N": players sorted by lifetime `Points`, with their rank name (`zc:40912-40955`).
- "Top 5 Today": sorted by `sessionStats[name].Points` (since mission start) (`zc:21395-21410`).
- The same outputs are reachable with map marks `stats`, `top`, `mystats` (`zc:29215-29240`).
- At redeem, the coalition message lists the sortie's stats per player (`+N Air`, `+N Ground Units`, `Flight time (N MIN)` …) (`zc:40605-40636`, `zc:41889`).

### Mechanism

- Three layers: `tempStats[name]` (current sortie, lost on death, committed on redeem), `sessionStats[name]` (since mission start, never saved), `playerStats` (persistent, by UCID in `playerStatsByUcid` or by name in `legacyPlayerStats`) (`zc:40510-40549`, `zc:40958-40970`, `zc:43446-43466`).
- Stat keys are free strings; the known ones have localisation keys (`FootholdStatLabelKeys`), mission-specific ones are created on the fly (`'CAP mission'`, `'Recon mission'`, `'Escort Mission'`, `'Strategic bomber escort'`, `'<title> (Joint mission)'`, `'Achievement'`) (`zc:40577-40603`, `zc:41346-41353`, `Setup:8253-8254`, `Setup:8667`, `zc:3148`).
- `Points` is the lifetime sum of redeemed credits (minus penalties); `Points spent` is the sum of shop and CTLD spending (`zc:41890`, `zc:21501`, `zc:22088`).

## 9. Career and achievements

### Player view

- `F10 > Stats and Settings > Stats > Career >` "Overview", "Flight progress", "Combat progress", "Logistics progress", "Aircraft" (`zc:101210-101215`).
- Overview: flight time (total / fixed wing / helicopter), sorties (takeoffs, landings, carrier takeoffs/landings, traps), kills by class, air-kill streaks, friendly kills / ejections / deaths, fuel received, supply delivered, CTLD builds, troop drops, pilot rescues, enemy pilots captured, lifetime spending and number of purchases (`zc:40799-40823`).
- Progress pages: one line per metric with current value, current title, unlocked/total and next title with its threshold (`zc:40771-40797`, `zc:40825-40847`).
- Aircraft page: per aircraft type flown, flight time, kills, landings, carrier landings, supplies, builds, achievements (`zc:40849-40881`).
- Crossing an achievement threshold pays credits into the purse and adds an `Achievement` stat; the announcement is batched and published 10 s later (`zc:44035-44060`).

### Mechanism

- Career counters are integer ids (`CAREER_STAT`, `CAREER_AIRCRAFT_METRIC`) stored in the rank record: `record.career[statId]` and `record.aircraft[aircraftId][metricId]` (`zc:12040-12078`, `zc:44085-44095`, `zc:40853-40857`).
- Each metric has a ladder of up to 9 levels; the reward of level n is `{100, 250, 500, 1000, 2000, 3500, 5000, 7500, 10000}[n]`; friendly kills, ejections and pilot deaths have ladders but no reward (`zc:12080-12101`, `zc:44062-44083`).
- Counters are fed from the reward handlers: kills (`recordCareerKillForCrew`), landings and carrier traps at redeem, ejections, deaths, fuel, supply and CTLD deliveries, rescues, purchases (`zc:42718`, `zc:41849-41864`, `zc:42144`, `zc:42175`, `WelcomeMessage.lua:2803-2808`, `zc:21504`).
- Ladder definitions (titles, thresholds) are in `CAREER_GLOBAL_ACHIEVEMENTS` / `_careerAchievementLadder` (not read).

## 10. Joint missions (reward sharing parties)

- `F10 > Missions > Joint missions >` "Request player", "Pending requests", "Status", "Leave", "Help" (label keys `JOINT_MENU_*`, menu creation at `zc:18653`).
- A party holds at most 4 players (`JOINT_MAX_MEMBERS`, `zc:18059`).
- When a member completes a mission target, every living party member who is enrolled receives the full reward as well, and the stat is recorded as `<stat> (Joint mission)` (`zc:41330-41360`, `zc:41283-41314`).
- For group targets with several killers, the reward is split between killers, then topped up to the full reward for killers who are in a party, and party members who did not kill get the full reward (`zc:41383-41413`).
- A member who dies, ejects or respawns leaves the party (`JOINT_YOU_HAVE_LEFT`, `JOINT_PLAYER_DIED_LEFT`, `JOINT_LEFT_DUE_RESPAWN`) (`zc:41790-41801`, `zc:42187-42197`, `zc:41699-41710`).
- Request/accept flow internals (`zc:18059-19200`) not read.

## 11. Player missions (`MissionCommander`)

### Data model

- One instance: `mc = MissionCommander:new({side = 2, battleCommander = bc, checkFrequency = 60})`; the constructor forces `checkFrequency` to 15 s whatever is passed (`Setup:6075`, `zc:102558-102560`).
- `mc:trackMission(def)` appends a definition to `mc.missions`; fields: `title`, `description` (string or `function(T)`), `messageStart`, `messageEnd`, `isActive()` (condition), `startAction()`, `endAction()`, optional `canExecute()`, `missionFail()`, `startOver()`, `reward` (paid straight to the coalition account), `side`, `missionType`, `idleAttackEvent`, and for escorts `isEscortMission`, `missionGroup`, `zoneName`, `titleBefore`, `returnAccepted` (`zc:103747-103761`, `zc:103763-103936`).
- A mission has no explicit trigger: `checkMissions` polls every mission each cycle (`timer.scheduleFunction`, first run at +15 s, then every `checkFrequency`) and derives a two-state machine from `isActive()` (`zc:103960`, `zc:103763-103936`).
  - not running and `isActive()` true (and `canExecute()` if present) → show `messageStart` to the coalition (30 s), call `startAction`, set `isRunning` (`zc:103866-103912`).
  - running and `isActive()` false → show `messageEnd`, add `reward` to the coalition account with `bc:addFunds`, call `endAction`, clear `isRunning` (`zc:103832-103860`).
  - running, still active and `missionFail()` true → the mission is removed from the list and `startOver()` is called (`zc:103815-103830`).
- After a start or an end the loop returns early and re-runs 6 s / 2 s later, so at most one transition is announced per pass (`zc:103858`, `zc:103909`).
- The "who triggered it" side is external: something else sets the variable or the `ActiveMission[flag]` that `isActive()` reads (a Director objective slot, an `EventCommander` event, a setup-file generator).
- `EventCommander` (`evc`): `evc = EventCommander:new({decissionFrequency = 15*60, decissionVariance = 10*60, skipChance = 15, strikeFrequency = 5*60})`; every ~15–25 min it picks one random executable non-strike event (85 % chance), and every 5 min one random executable strike event (`Setup:6073`, `zc:96294-96361`).

### Target registry and completion detection

- `RegisterUnitTarget(unitName, reward, stat, flag, custom)`, `RegisterGroupTarget(groupName, reward, stat, flag, custom)`, `RegisterStaticGroup(key, source, reward, stat, flag, custom)`, `RegisterScoreTarget(flag, sceneryObj, reward, stat, custom)` fill the global tables `MissionTargets[unitName]`, `MissionGroups[groupName] = {reward, stat, alive, remaining, killers, flag}`, `ScoreTargets[flag]` and set `ActiveMission[flag] = true` (`zc:8866-8878`, `zc:9000-9072`).
- A kill of a registered unit by an enrolled player (`S_EVENT_KILL`) removes it from `alive`, records the killer, and when `remaining == 0` pays: the group reward is split equally between the killers still enrolled, message `MISSION_REWARD_COMPLETED_SOLO/GROUP/JOINT`, sound `cancel.ogg`, the mission mark is removed, `ActiveMission[flag]` is cleared and, for "custom" (one-shot) targets, `CustomFlags[flag] = true` is set so that it never comes back (`zc:41467-41502`, `zc:41362-41465`).
- Scenery/static strike targets are detected through `S_EVENT_SCORE` + a 6 s delayed life check (≤ 50 % relative life = destroyed) (`zc:42083-42131`).
- If a registered group dies without a player kill (AI, despawn), `isActive()` of the mission notices the group is gone and the mission ends without reward; `endAction` calls `bc:cancelGroupTargetMission(flag, side)` (`Setup:6205-6216`).
- A killer who dies, ejects or respawns is removed from every `MissionGroups[*].killers` (`zc:41677`, `zc:41766`, `zc:42184`).
- Map mark: 30 s after registration, if the group is stationary (speed < 1 m/s), a coalition mark with the mission label is placed on its first unit (`trigger.action.markToCoalition`, id from the global counter `missionMarkId`, stored in `MissionMarks[groupName]`) (`zc:9028-9056`).

### Mission types in the Caucasus setup

| Mission | Source of activation | Completion | Reward | Code |
|---|---|---|---|---|
| Attack zone (3 slots) | Director objective slots / `attackTarget1..3` set by the engine generator | target zone no longer red (captured or neutralised) | zone tag "Attack" on the map label; no direct `reward` field read | `Setup:6888-7228`, `zc:64183` |
| Resupply zone (2 slots) | `resupplyTarget1..2` chosen at random among friendly zones needing supply | zone no longer needs supply | per-delivery `Zone upgrade` rewards (§3.5) | `Setup:6575-6884`, `zc:63750`, `zc:63876` |
| Capture zone | `captureTarget` | zone no longer neutral or capture pending | per-delivery `Zone capture` reward | `Setup:7232-7458`, `zc:64370` |
| SEAD (slots) | Director SEAD slots (`RegisterDirectorSeadMission`) | all SAM targets of the slot destroyed or zone lost | pool = kills × 50, shared by weight between eligible participants | `Setup:7461-7632`, `zc:63506-63560`, `zc:62634` |
| DEAD | `mc:registerDeadMissions()` | (not read) | (not read) | `Setup:7637-7640`, `zc:103458` |
| Recon (slots) | Director recon slots; cancelled when the zone gets intel | a player flies the recon over the zone (detection not read) | 100 to the winner, joint-shared, stat `Recon mission` | `Setup:7646-7946`, `Setup:7911-7912` |
| CAP | engine generator: at least one red air group airborne, players online, no cooldown; target = 2–8 kills depending on the player-count tier | first player to reach the kill count | `kills × 100` to the winner (joint-shared), then 900 s cooldown | `Setup:8322-8368`, `zc:65567-65606`, `zc:42780-42787` |
| CAS (slots) | Director CAS slots (`RegisterDirectorCasMission`) | slot targets destroyed | pool = kills × 30, shared by weight | `Setup:8378-8545`, `zc:63362-63412`, `zc:62632` |
| Runway strike (slots) | Director runway slots | (not read) | (not read) | `Setup:8739-8996` |
| Destroy artillery | auto-tracked: every red `GroupCommander` with `mission == 'attack'`, `type == 'surface'`, `MissionType == 'ARTY'`, plus hand-written ones | registered group destroyed | `gc.Reward` or 250 | `zc:102746-102760`, `Setup:7952-8117` |
| Destroy EWR (strike) | auto: each red EWR within 70 NM of a friendly zone is queued with a random 60–300 s delay, then started by the strike event | EWR group destroyed | 300 | `zc:102460-102465`, `zc:102804-102908` |
| Destroy SCUDs | `evc` event respawns `Maykop-Scuds` and registers it; 2700 s cooldown | group destroyed | 100 | `Setup:6120-6216` |
| Intercept cargo plane | `evc` event | plane shot down | 500 | `Setup:6254-6290` |
| Destroy cargo / battle ships | `evc` event | ship destroyed | 500 | `Setup:6323-6370` |
| Intercept bombers | `evc` event (red bomber raid) | bombers destroyed | (not read) | `Setup:6374-6410` |
| Intercept enemy airstrike | `evc` event, group `evt-attack` | group destroyed | 250 | `Setup:6478-6555` |
| High-value strike targets (scenery, generals, warehouses) | strike events, each gated by which zones blue holds | scenery ≤ 50 % life, or group destroyed | 1000 / 500 | `Setup:9040-9700` |
| Red mass attack defence | `autoTrackRedMassAttackMission` | (not read) | (not read) | `zc:103062` |
| Industry strike (PvP) | built in `MissionCommander:new` from zones' industry statics within 100 NM | statics destroyed | `min(1000, 300 × objects)` | `zc:102566-102742` |
| Ground convoy escort | player lands/spawns in a zone that has an escort mission | convoy reaches and captures the target zone | 1000 shared between the escorting players (or to the coalition if none) | `Setup:2067-2100`, `Setup:8591-8700` |
| Strategic bomber escort | buyer chose "Player escort" in the shop | bomber raid completes with qualified escorts | 1000 split between qualified players | `zc:3125-3158`, `Setup:3715` |

- In PvE, the mission definitions close over setup-file globals (`attackTarget1`, `capMissionTarget`…); in PvP the same roles are driven by per-side "objective slots" (`bc.objectivesBySide[side].<role>Missions.slots[i].activation`), which is why `checkMissions` carries the long ownership checks (`zc:103763-103800`).
- Start/end sounds are coalition sounds (`ding.ogg`, `cas.ogg`, `cancel.ogg`) played from `startAction` / `endAction` (`Setup:6201-6209`, `Setup:7093-7095`).

### Ground escort missions (accept flow)

- Defined in the setup table `missions[zone] = {zone, missionGroup, menuTitle, missionTitle, TargetZone, radius, MissionType = "Escort", flag, ActivateZone}` (PvE only) (`Setup:2067-2100`).
- `handleMission(zoneName, groupName, groupID, group)` is scheduled after a player **helicopter** spawns in a zone (PvE only, `_scheduleSpawnMissionHandle`, `zc:101053-101058`); if the mission can start, the group gets a top-level F10 submenu titled with the mission title containing "Accept" and "Deny" (`zc:104606-104706`).
- "Accept": `mc:acceptMission` flags the tracked mission as accepted and running, optionally activates a hidden zone (`ActivateZone`), replaces the accept menu by a control menu for every tracked group, tells them who accepted, and 5 s later drops blue smoke next to the convoy (`zc:104638-104695`).
- "Deny": marks the mission `denied` and removes the accept menu (`zc:104696-104709`).
- Control menu entries: "Move", "Hold position", "Manual Hold", enable/disable forced hold, "Deploy smoke near the convoy", "Get Bearing to the Convoy", "Restart Mission", "Set up FARP?" (label keys `ESCORT_*`, `L10N:1987-1995`; handlers not read).
- Failure: the convoy group is no longer active → `missionFail` returns true, "escort failed" message, menus removed, and `startOver` re-offers the mission 10 s later (`Setup:8605-8641`).
- Success: target zone blue and active → 1000 credits split between the players of the tracked groups (purse + stat `Escort Mission`), convoy destroyed, and 30 s later the next leg is offered from the target zone (`Setup:8643-8697`).
- No altitude choice was found in this ground-escort flow; the strategic bomber purchase offers "AI escort" or "Player escort" per origin zone (`zc:3553-3585`), and the free AI fighter escort for players is requested from `WelcomeMessage.lua` (`AddEscortRequestMenu`, `EscortTypeByPlayerType`, `PvPEscorts`; not read — altitude options, if any, are there, estimation).

### Display

- `F10 > Missions > Missions` prints the running missions visible to the viewer's side (title + description, separated by rules), then "Available missions" for escort missions not yet accepted (`zc:103413-103456`, `zc:101490-101497`).
- `F10 > Missions > Strike missions >` one command per running strike mission (title, suffixed with the flag when titles collide) that prints that mission; "none" entry when empty (`zc:103227-103300`).
- `F10 > Missions > Intel >` (zones with active intel) and `F10 > Missions > Joint missions` live under the same root (`zc:103322-103347`, `zc:18653`).
- A map mark with text `missions` prints the mission list (`zc:29080`).
- Strike menus are rebuilt per group only when the signature (sorted list of active strike flags) changes (`zc:103218-103262`).

### Reproduction notes

- The polling design means a mission definition is a closure with arbitrary side effects; reproducing it needs a clear contract for `isActive` (it is called every 15 s for every mission and sometimes mutates state, e.g. clears its own target, `Setup:7117-7128`).
- Reward attribution relies on per-unit registration at mission start, so late-spawned units of the same group are not targets.
- Three separate reward channels coexist: `reward` on the mission (coalition account), registry rewards (player purse), and custom payouts inside `endAction` (CAP, recon, CAS/SEAD pools, escort).
- Moose use here is light: `SCENERY:FindByZoneName` for scenery targets (`Setup:9045`), `UTILS` conversions, otherwise raw `trigger.action.markToCoalition`, `missionCommands.*`, `timer.scheduleFunction`.

## 12. F10 menu tree (this theme)

All entries below are per player group (`missionCommands.add…ForGroup`), created at slot birth by the logistic commander's birth handler and removed when the group dies (`pruneGroupMenus`) (`zc:101203-101215`, `zc:101490-101497`, `zc:43033-43035`).

```
F10 > Other
├─ Shop                                             (zc:22401)
│  ├─ AI Attack > [cost] item > zone > (options)    (zc:22524-22530)
│  ├─ Zone Upgrades > [cost] item > zone
│  ├─ JTAC & Intel > [cost] item > zone
│  ├─ Combined Arms > [cost] item > zone
│  ├─ Capture & resources > [cost] item > zone
│  ├─ Other support > [cost] item > zone > Orbit | Hot xxx > nn NM Leg
│  └─ Budget overview                               (zc:22412)
├─ Dynamic Control                                  (zc:16425)
│  └─ CAP / SEAD / Decoy / CAS / Bomber / Tankers / Carrier controls
├─ Missions                                         (zc:101490)
│  ├─ Missions                                      (zc:101497)
│  ├─ Strike missions > <mission>                   (zc:103235)
│  ├─ Intel > <zone>                                (zc:103337)
│  └─ Joint missions > Request player | Pending requests | Status | Leave | Help   (zc:18653)
├─ Stats and Settings                               (zc:101203)
│  ├─ Stats > My Stats | Top 10 Players | Top 5 Players | Top 5 Today | Rank Help
│  │        └─ Career > Overview | Flight progress | Combat progress | Logistics progress | Aircraft
│  └─ AI Logistics (Currently …)                    (zc:101172)
└─ <escort mission title> > Accept | Deny           (zc:104636-104696)
```

- Scope: group-level for everything above; the only coalition-level menus in this theme are the legacy "shop for all" and the legacy CAP request menu (`DYNAMIC_REQUEST_CAP_FROM`) (`zc:13044`, `zc:107506`).
- Refresh triggers: slot birth, rank change, shelf change, zone state change (queued selector refresh), mission start/end (strike and intel menus), locale change (`L10N:ForGroup`).
- Language: each group has its own locale, so every label is resolved per group (`zc:22398`).

## 13. Config knobs that tune the economy

| Setting | Default | Meaning | Code |
|---|---|---|---|
| `ShopPrices[id]` | see §5 | item price | `Config:1771-1842` |
| `ShopRankRequirements[id]` | see §5 | minimum rank | `Config:1846-1916` |
| `AvailableShopItems[id]` | all `true` | `false` removes the item | `Config:1608-1767` |
| `RewardContribution` | see §3 | per-event rewards | `Config:1920-1936` |
| `RefuelReward` | 2 | credits per 100 lb received | `Config:1939` |
| `TurnaroundRewardPercent` | 10 | same-aircraft second-sortie bonus | `Config:1589` |
| `NightRewardPercent` | 10 | night takeoff bonus | `Config:1594` |
| `RewardFlightTime`, `FlightTimeRewardPerMinute`, `RewardAllAircraft`, `AllowedFlightTimeReward` | `true`, 2, `false`, transports only | flight-time reward | `Config:2265-2303` |
| `CreditLosewhenKilled`, `CreditLosewhenKilledAmount` | `false`, 100 | coalition penalty per player loss | `Config:261-264` |
| `RankingSystem` | `true` | rank gating on/off | `Config:285` |
| `RankLoseWhenKilled`, `RankLoseWhenKilledAmount` | `true`, 100 | personal penalty per loss | `Config:267-270` |
| `FriendlyFireRankPenalty` | 500 | personal penalty per team kill | `Config:288` |
| `StoreLimit` | `false` | lifetime-points gate on expensive items | `Config:282` |
| `ShowKills` | `false` | per-kill message to the killer | `Config:275` |
| `StartupFunds` | 1000 / 1000 | PvP starting credits | `Config:308-311` |
| `AllowCapAutoBuyAfterLoss`, `MaxCapAutoBuys` | `false`, 1 | CAP auto re-buy | `Config:1580-1584` |
| `AdvanceCaptureRemainingThreshold` | 50 | % of upgrade groups left for "advance capture" | `Config:1602` |
| `AIAttackTakeoffFromGround`, `AIAttackTakeoffFromGroundExtraNM` | `true`, 40 | purchased flights start from an airbase | `Config:1943-1944` |
| `AllowAdminBuy` | `true` | `adminbuy` marker | `Config:1948` |
| `AllowScriptedSupplies` | `false` | instant supplies instead of AI delivery; puts `supplies` on the shelf | `Config:1952` |
| `CTLDCost`, `CTLDPrices` | `true`, table | CTLD prices and ranks | `Config:1959`, `Config:1975-2058` |
| `CarrierRankRequirement` | 5 | rank to move the carrier | `Config:292` |
| `CsarPilotSpawnWithoutCreditsChance` | 50 | downed pilot spawn chance without credits | `Config:2230` |
| `PvPEscorts` | `false` | free two-fighter escort offer in PvP | `Config:327` |
| `AdminCommandAliases.addBlueFunds / addRedFunds / buyWithoutRank` | `""` | custom marker words for admin actions | `Config:3477-3489` |

- The setup file merges its own defaults under the Config tables (`mergeDefaults`), so a key missing from the Config falls back to the setup value (e.g. `redwarehouse = 3000`, `redwhrepair = 2000`) (`Setup:2996-3004`, `Setup:2931-2932`).
- Hard-coded economy constants: achievement rewards (`zc:12080-12090`), CAS/SEAD per-kill pools 30 / 50 (`zc:62632-62634`), auto-EWR reward 300 (`zc:102465`), recon 100 (`Setup:7911`), CAP `kills × 100` (`Setup:8346`), escort 1000 (`Setup:8648`), strategic bomber escort 1000 (`Setup:3715`), ejection split 25 % / 75 % (`zc:41749`, `zc:41764`), red zone upgrade 3000 and red mass attack 2500 (`Setup:4799`, `Setup:4812`).

## Seen outside this theme

- Hunter: enemy interceptors/hunters spawned against a player after a number of kills (`initHunter`, `registerHuntKill`, `_spawnHunterForPlayer`) (`zc:40974-41059`).
- Zone intel (`startZoneIntel`, markers of units, refresh loop, 60 min default) (`zc:6954-7010`).
- Night handling of MANTIS detection interval and radar blur (`_applyNightMantisState`) (`zc:41614-41643`).
- Director air-combat evidence collection from kill events (`_recordDirectorAirCombatEvidence`) (`zc:41926-42081`).
- Runway destruction: `S_EVENT_DEAD` on an airdrome blocks plane spawns for 3300 s (`zc:42906-42920`).
- Hercules cargo air-drop on `S_EVENT_SHOT` (`HercCargoDropSupply.HandleShot`) (`zc:42921-42930`).
- Enemy pilot capture "debrief" intel, including disclosure of the enemy Director's plan (`zc:42313-42363`).
- Idle zone suspension / wake-up on purchase (`_idleSuspended`, `idleZoneWakeHoldSec`) (`zc:21980-22018`).
- Warehouse / Logistic Center facility (`applyLogisticCenterUpgrade`, `applyWarehouseRepair`) (`zc:24155-24253`).
- Dynamic FARPs bought by marker and built by an AI helicopter (`processMapFarpPurchase`, `_dispatchMarkerFarpFlight`) (`zc:21332`, `zc:20870`).
- Admin marker commands (`startMonitorPlayerMarkers`: help, debug, spawn, event, capture, Tarawa movement…) (`zc:28354-28408`).
- Strategic bomber module and its player-escort envelope watch (`StrategicBomber.StartPlayerEscortWatch`) (`zc:3293`).
- Free AI escort for players and callsign handling in `WelcomeMessage.lua` (`AddEscortRequestMenu`, `WelcomeMessage.lua:2727`).
- Navy artillery support using Moose OPS (`AUFTRAG:NewARTY`, `FLIGHTGROUP`) (`zc:109950-110075`).
