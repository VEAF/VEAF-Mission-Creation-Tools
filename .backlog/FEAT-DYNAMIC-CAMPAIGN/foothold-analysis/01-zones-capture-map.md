# 01 — Zones, ownership, capture and the map (Foothold v6.5.3)

Sources, with the short names used in citations: `zc2` = `Common Scripts/zoneCommanderv2.lua`, `setup` = `Setup files/MA_Setup_CAv2.lua`, `config` = `Common Scripts/Foothold Config.lua`, `ctld` = `Common Scripts/Foothold CTLD.lua`, `ctldred` = `Common Scripts/Foothold_CTLD_Red.lua`, `l10n` = `Common Scripts/Foothold_Localization.lua`.
Coalition numbers are the DCS ones: 0 neutral, 1 red, 2 blue.
"PvE" is the default mode (blue players against a red AI); `GlobalSettings.pvpEnabled` switches many branches to a symmetric mode.

## Feature list

| # | Feature | One-line description | Main code location |
|---|---|---|---|
| 1 | Zone model | A zone = one `ZoneCommander` object + one trigger zone (circle or quad) with owner, facility type, garrison lists, flags. | `zc2:46584-46695`, `zc2:4226-4356`, `setup:765-865` |
| 2 | Garrison definition and random generation | Per-owner ordered list of template groups/statics, optionally re-drawn per campaign from size templates; spawn in sub-zones. | `zc2:48329-49620`, `zc2:4621-4674`, `zc2:5214-5339` |
| 3 | Zone initialisation | Draw, set airbase coalition, spawn or restore the garrison. | `zc2:51378-51779` |
| 4 | Zone update loop, losses, repair, upgrade, surrender | 10 s staggered tick; polled loss detection; one-step upgrade/repair; red zones weaken visibly and may surrender. | `zc2:43291-43347`, `zc2:55146-56030`, `zc2:56884-57100` |
| 5 | Neutralisation and disabling | An emptied zone turns neutral; some zones are destroyed for good (critical objects, single-use zones). | `zc2:55294-55451`, `zc2:50185-50270` |
| 6 | Capture channels | Everything that can capture a neutral zone, and what a capture triggers. | `zc2:56557-56818` and callers |
| 7 | Pending capture | Capture takes `ZoneCaptureBuildSeconds` and needs a surviving participant in the zone. | `zc2:46711-47125` |
| 8 | Advance capture | Supply pre-positioned against a weakened red zone, released when it falls. | `zc2:50100-50142`, `zc2:55453-55502`, `zc2:60041-60292` |
| 9 | Zone dormancy | Distance suspension, idle suspension, proximity and mission wake-up, queued respawn. | `zc2:37445-37990`, `zc2:37071-37163`, `zc2:47748-48084` |
| 10 | Connection graph | Hand-declared adjacency and derived "connected to blue" tables. | `zc2:27025-27054`, `zc2:27303-27535` |
| 11 | Frontline | Nearest-enemy segments, signed distance to front, neighbour lists. | `zc2:9092-9612` |
| 12 | Map: zone shapes and labels | Coloured shape and one text box per coalition, updated in place; attack flash. | `zc2:51392-51436`, `zc2:51694-51742`, `zc2:56076-56264` |
| 13 | Map: connection lines / supply arrows | Lines or arrows between zone edges, coloured by ownership. | `zc2:38010-38292`, `zc2:38985-39110` |
| 14 | Map: territory overlays | Voronoi cells tinted by owner with frontier borders, incremental redraw. | `zc2:39115-40310` |
| 15 | Hidden zones, pop-up zones, scripted zone events | Invisible reserve zones, zones that appear during the campaign, setup-file reactions. | `zc2:44581-44598`, `zc2:50470-50640`, `setup:1851-1940` |
| 16 | F10 menu "Intel & Zone status" and status message | Per-group zone list by side; status text with garrison health and coordinates. | `zc2:40312-40507`, `zc2:50274-50465` |
| 17 | Admin marker commands on zones | Capture, upgrade, clear, explain. | `zc2:28886-29202` |
| 18 | Campaign win / lose | All visible zones of one side gone → message, save reset, mission end. | `setup:2732-2849` |


## 1. Zone model (`ZoneCommander` + `CustomZone`)

### Mission-maker view

A zone is one Lua object created in the setup file and one trigger zone of the same name in the `.miz`.
`ZoneCommander:new({facility=, zone=, side=, size=, level=, upgrades=, crates=, flavorText=, income=, isHeloSpawn=, isPlaneSpawn=, NeutralAtStart=, isHidden=})` is the constructor call, for example `batumi = ZoneCommander:new({facility='airbase', isPlaneSpawn=true, isHeloSpawn=true, zone='Batumi', side=1, size='big', level=25, upgrades=upgrades.airfield1, crates={}, flavorText=flavor.batumi})` (`setup:768`).
The Caucasus setup declares 89 zones this way (`setup:766-865`, count by grep).
The zone is then registered with `bc:addZone(zone)`, which gives it its map-mark base id `index = #zones + 3000`, caches its `CustomZone` in `zone._cz`, and derives `isHidden` from the name containing "hidden" when the field was not set (`zc2:26791-26812`).

Constructor fields actually read by the engine:

| Field | Meaning | Where |
|---|---|---|
| `zone` | Name of the trigger zone in the `.miz`; also the display name and the key in `bc.indexedZones`. | `zc2:46682`, `zc2:26802` |
| `side` | Starting owner 0/1/2. | `zc2:51394-51400` |
| `facility` | One of `airbase`, `farp`, `carrier`, `ground`, `logistics`, `none`; asserted, defaults to `none` with a log line. | `zc2:45868-45875`, `zc2:46586-46591` |
| `isPlaneSpawn`, `isHeloSpawn` | The zone can launch AI planes / helicopters; a blue zone with either gets a green dashed outline. | `zc2:46592-46593`, `zc2:51739-51742` |
| `level` | Number of upgrade slots spawned at mission start (slots `1..level`); 25 everywhere in Caucasus, i.e. "all of them". | `zc2:51621-51623`, `setup:768` |
| `upgrades = {red={...}, blue={...}}` | Ordered garrison list per owner; each entry is a late-activated group name, a static name, or `{n='name', p=true}` ("pinned": never randomised or replaced). | `zc2:46653-46674`, `zc2:48604-48615` |
| `size` | Key into the random-garrison templates (`small`, `smallmedium`, `medium`, `mediumbig`, `big`, `bignosam`, `smallwithShorad`, `redarmycamp`…). | `zc2:48539-48542`, `setup:768-834` |
| `income` | Credits added to the owner at every zone update tick. | `zc2:55157-55167` |
| `crates` | Names of static cargo objects in the `.miz` that capture or upgrade the zone when found on the ground inside it. | `zc2:55206-55253` |
| `flavorText` | Free text shown in the zone status message. | `setup:768` (display code: `zc2:50274` onwards) |
| `NeutralAtStart` | Marks zones that begin neutral; cleared at init if the zone has an owner, and on first capture. | `zc2:51407-51409`, `zc2:56622` |
| `isHidden` | Zone has no map drawing, no label, no status menu entry, no loss message. | `zc2:51411-51417`, `zc2:55370` |
| `upgradesUsed` | Per-side counters `upgradesUsedRed` / `upgradesUsedBlue`. | `zc2:46607-46610` |

Fields set after construction in the setup file:

- `zones.X.airbaseName = 'Batumi'` binds the zone to a DCS airbase or FARP object (`setup:1231-1288`); used for `Airbase:setCoalition`, warehouses and slot statics.
- `zones.X.industryCores = {['static name']=true}` (PvP industry zones, `setup:869-873`).
- `zones.X.customSuspendNm`, `zones.X.noIdleSuspend` override the dormancy rules per zone (`setup:989-992`).
- `zone:addCriticalObject(staticName)`: when every critical static is dead the zone is disabled for good (`zc2:50036-50039`, `zc2:51904-51930`).
- `zone:registerTrigger(eventType, action, id, timesToRun, options)` with event types `captured`, `upgraded`, `repaired`, `lost`, `destroyed` (`zc2:50062-50072`); `options.disablesZone` on a `lost` trigger flags the zone as "disappears when lost", which also bars it from advance capture (`zc2:50066-50071`, `zc2:50126`).
- `zone:addRestrictedPlayerGroup({name=, side=})`: a user flag named after the group is set to 1 when the zone is not owned by `side`, to be used by slot-blocking logic (`zc2:50022-50024`, `zc2:55197-55202`, `zc2:51745-51747`).

Trigger-zone conventions in the `.miz` (all read from `env.mission.triggers.zones`, `zc2:203-223`):

- The main zone can be a circle or a 4-point quad (`type` 0 or 2); both are supported for containment tests and drawing (`zc2:4244-4278`, `zc2:4294-4306`).
- `<Zone>-<number>` are spawn sub-zones for garrison groups (`zc2:1423-1442`).
- `<Zone>-SAM-…` and `<Zone>-SHORAD-…` are sub-zones reserved for long-range SAM and SHORAD groups (matching is case-insensitive) (`zc2:4725-4745`, `zc2:5257-5269`).
- `<Key>-Supply-<n>` zones are waypoints of helicopter cargo routes (other theme) (`zc2:209-222`).
- A zone whose name contains "hidden" is hidden (`zc2:4236`, `zc2:26792-26794`).

### Mechanism

`CustomZone:getByName` builds once per name a table `{name, type, point, radius, vertices, minX…maxZ, radiusSq, isHidden}` from the mission table and caches it (`zc2:4228-4284`).
`CustomZone:isInside(point)` does a bounding-box rejection, then a squared-distance test for circles or `UTILS.IsPointInPolygon` for quads (`zc2:4294-4306`); this Moose utility is a plain ray-casting test (crossing-number on `x`/`z`, on a deep copy of the vertex list at every call) and is the only Moose dependency of the geometry (`Moose_2026-10-11.lua:5145-5168`).
`CustomZone:getZoneBuildings` runs `world.searchObjects(Object.Category.SCENERY, sphere)` once per zone and caches the positions of scenery objects with the `Buildings` attribute (`zc2:4308-4343`).

State kept per zone at runtime: `side`, `active`, `suspended`, `built` (slot index → live group or static name), `spawnSubZones` (slot → sub-zone used), `groups` (the AI `GroupCommander`s based there, other theme), `triggers`, `criticalObjects`, `restrictedGroups`, `pendingCapture`, and a set of caches and dormancy flags (`zc2:46594-46651`).

### Reproduction notes

The zone name is used as identifier everywhere, including as prefix for sub-zones; a zone renamed in the editor silently loses its sub-zones.
Quad zones are stored with `y` and `z` swapped relative to the mission table (`zc2:4249-4253`).
The "hidden" property is name-based in two places and field-based in a third, so the three must agree.

## 2. Garrison definition, random generation and spawn placement

### Mission-maker view

The `upgrades` global in the setup file names reusable lists, for instance `airfield1 = { blue = {'blueInfantry', 'Blue Armor Modern', 'Blue SAM NASAMS'}, red = {'Enemy ground forces', 'Red SAM AAA', …} }` (`setup:89-97`).
Each name must exist in the `.miz` as a late-activated group (used as a template) or as a static object; a missing name raises an on-screen message at init (`zc2:51558-51584`).
A name containing `Fixed` is spawned exactly where it was placed in the editor instead of in a random sub-zone (`zc2:5220-5243`).
A name containing `Fixed` or `(p)`, or an entry with `p=true`, is excluded from randomisation (`zc2:48598-48615`).
A name containing `dismounted` is never spawned by the zone itself (`zc2:51560`, `zc2:51606`, `zc2:51631`).
Group names containing `IsNotShown` or `Red EWR` are spawned hidden on the F10 map (`zc2:4658-4660`).

Random garrisons: `RandomGroundGroups` and `RandomBlueGroups` default to true (`zc2:48417-48418`).
`applyRandomRedUpgrades()` rewrites `zone.upgrades.red` of every eligible zone (not hidden-without-size, not a carrier) from a size template `RandomUpgradeTemplates[size]` that gives a count or `{min,max}` range per category `sam`, `shorad`, `aaa`, `ground`, `armor`, `arty` and a `total` (`zc2:49516-49598`; the tables themselves are in `setup:698-728`, resolved by `resolveTemplate`, `zc2:48506-48524`).
`MaxRedGroundGroupsPerZone` (Config) caps the number of red groups per zone, clamped to 5–12 (3–6 on Normandy), and scales the templates down per size tier when below the map maximum (`zc2:49517-49581`).
Categories are derived from the group name by substring (`aaa`, `shorad`/`sa-8`/`sa-15`…, `sa-2`/`sa-10`/`hawk`/`patriot`…, `arty`/`mlrs`…, `armor`, `infantry`/`truck`…) (`zc2:48550-48596`).
Pinned, `Fixed` and static entries are kept; the rest is drawn from a global pool of red (or blue) templates filtered by the Config "enabled templates" switches (detail below).
The draw is deterministic per campaign: a campaign seed is created once (from `socket.gettime` if LuaSocket loads, else mission date and timers) and mixed with side, zone size and zone name before each zone is generated (`zc2:48450-48494`); all draws go through `fhRand`, a linear congruential generator `seed = (1103515245 × seed + 12345) mod 2^31` (`zc2:48420-48440`).
The setup file calls `applyRandomRedUpgrades()` and `applyRandomBlueUpgrades()` only when no save was loaded, and `applyRandomUpgradesForNewZonesOnly()` otherwise (`setup:5917-5919`, `setup:5938-5939`).

Size templates for red, Caucasus (`setup:698-714`); a single number is a fixed count, `a–b` a uniform range, "flak" = `flakChance` / `flakSecondChance` / `flakMax`, "keep" = `RandomRedPickKeepChance` for both `Red SAM SHORAD Pantsir S1` and `Red SAM SHORAD Tor M2`:

| size | sam | shorad | aaa | ground | armor | arty | total | flak | keep % |
|---|---|---|---|---|---|---|---|---|---|
| `small` | 0 | 0–2 | 0–2 | 0–3 | 0–2 | 0–2 | 4–6 | 10 / 0 / 1 | 20 |
| `smallwithShorad` | 0 | 2 | 2 | 0–1 | 1 | 0 | 4–7 | 10 / 0 / 1 | 30 |
| `smallmedium` | 0 | 0–3 | 0–2 | 0–3 | 0–3 | 0–2 | 4–7 | 12 / 0 / 1 | 30 |
| `medium` | 0–1 | 0–3 | 0–3 | 0–3 | 0–3 | 0–3 | 4–9 | 20 / 0 / 1 | 40 |
| `mediumbig` | 0–1 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 30 / 5 / 2 | 50 |
| `big` | 0–1 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 50 / 20 / 2 | 70 |
| `bignosam` | 0 | 0–4 | 0–3 | 0–3 | 0–4 | 0–3 | 5–10 | 50 / 20 / 2 | 70 |
| `extrabig` | 1–2 | 0–5 | 0–4 | 0–4 | 0–4 | 0–4 | 7–12 | 60 / 30 / 2 | 100 |
| `sam` | 1 | 1–2 | 1–2 | 0 | 0 | 0 | 3–5 | 10 / 0 / 1 | 70 |
| `sam2` | 1 | 1–2 | 1–2 | 0 | 0–1 | 0 | 3–6 | 10 / 0 / 1 | — |
| `samspecial` | 2 | 1–3 | 1–2 | 0 | 0 | 0 | 6–7 | 25 / 8 / 2 | 0 |
| `redarmycamp` | 0 | 0 | 0 | 3–5 | 0 | 0–5 | 6–8 | — | — |
| `redarmycamp2` | 0 | 0 | 1–2 | 3–5 | 0 | 0–4 | 6–8 | 0 / 0 / 0 | — |
| `redarmycamp3` | 0–2 | 0–3 | 1–3 | 0 | 0 | 0 | 6–8 | 0 / 0 / 0 | — |

Blue size templates (`RandomUpgradeTemplatesBlue`, `setup:716-727`): every size has `ground 0–1`, `armor 1`, `aaa 0–1`, `shorad 0–1`; `sam` is 0 for `small`, `smallmedium`, `medium`, `mediumbig`, `bignosam` and 0–1 for `big`, `extrabig`, `sam`, `sam2`, `samspecial`; `total` is 2 (`small`, `smallmedium`), 2–3 (`medium`, `mediumbig`), 3–4 (`big`, `extrabig`, `bignosam`), 4 (`sam`, `sam2`, `samspecial`).
In PvP both sides use `PvPBaseGarrisonProfiles`, which maps every size onto the blue `small` / `medium` / `big` / `bignosam` / `sam` rows with the big ones forced to `total = 3` (`setup:729-746`).
`ZoneSizeExclusions[size]` is a list of lower-case substrings a template name must not contain for that size, e.g. `small = {"sa-10","sa-11","sa-2","pantsir","tor m2"}`, `medium = {"sa-10","sa-11","pantsir"}` (`setup:689-696`, `zc2:48728-48744`); `zone.noLongRangeSam` additionally bans SA-2/SA-10/SA-11 names (`zc2:48739-48741`, `zc2:48633-48639`).
`RandomRedPool` (55 names for the modern era: 5 strategic SAM, 7 SHORAD, 10 AAA, 2 infantry, 3 armour, 6 mech, 3 special, 10 artillery, plus 6 "Enemy Ground-Light" groups outside Vietnam and 3 "…-Modern" ones in the modern era) and `RandomBluePool` (9 names) are literal lists in the setup file, swapped name by name for the Cold War and Vietnam eras (`setup:594-687`, counts by reading the list).

### Mechanism — the random draw

Pools (`zc2:48746-48866`).
`getGlobalRedPool()` returns `RandomRedPool` when the setup file defines it; otherwise it scans every `upgrades.<key>.red` list (carrier and "hidden" keys excepted) and keeps each name that is not pinned, not `Fixed`, not a static and that exists as a template (`zc2:48746-48780`).
`getGlobalBluePool()` is the same over `upgrades.<key>.blue`, with `Blue SAM PATRIOT` always excluded (`zc2:48782-48813`).
`fillPoolsFrom(source, pools, zone, size)` sorts the candidate names into per-category lists after four filters: not pinned/`Fixed`/static; enabled by the Config switches; not excluded by `ZoneSizeExclusions` or `noLongRangeSam`; a template of that name exists (`zc2:48815-48848`).
The Config switch is a table `RedTemplateEnabled` (or the older `RedSamTemplateEnabled`) keyed by family — `SA-2`, `SA-3`, `SA-5`, `SA-6`, `SA-8`, `SA-9`, `SA-10`, `SA-11`, `SA-13`, `SA-15`, `SA-19`, `Tor M2`, `Pantsir S1`, `MANPAD`, all true by default; the family of a name is found by substring (`manpad`, `pantsir`, `tor m2`, then `sa-19` … `sa-2` longest first, with hyphen or space), with per-name overrides `RedTemplateKeyByName` and the built-in `Enemy Task forces` → `MANPAD` (`zc2:48641-48687`, `zc2:48689-48712`).
A disabled name is replaced by `RedTemplateReplacementByName[name]` (built-in: `Enemy Task forces` → `Enemy ground forces`) and the replacement is filtered again; with no replacement it is dropped (`zc2:48714-48719`, `zc2:48828-48836`).
In PvP the "base-garrison" purpose additionally bans SA-5, SA-10, SA-11, SA-15, SA-19, Tor M2 and Pantsir, and any SAM/SHORAD whose family is not SA-2/3/6/8/9/13/MANPAD (`zc2:48691-48706`).

`buildRandomRedUpgrades(zone, maxGroups, generationProfiles)` (`zc2:49028-49302`):

1. Seed the generator for (zone, "red", size); with no template for that size the authored list is returned with disabled names replaced (`resolveConfiguredRedUpgrades`) (`zc2:49030-49034`, `zc2:49000-49014`).
2. Resolve the template: each range is rolled once with `fhRand`, and `total` is clamped to `maxGroups` (`zc2:48506-48524`, `zc2:49037`).
3. Walk the authored list: statics go to `staticList`; a pinned entry whose family is disabled is dropped; `Fixed`, pinned and "extra forced" entries (the names in `zone.extraUpgrade` bought for red) go to `fixedList` and are counted per category (`zc2:49039-49083`).
4. Build the pools from the global red pool (or, when `RandomGroundGroups` is false, from the zone's own list, falling back to the global pool if that yields nothing), and remove the forced names from them (`zc2:49104-49128`).
5. Flak: when the template has `flakChance`, the flak pool (`RandomFlakPool` or the default `Red SAM AAA 3` and `Red SAM AAA 4`, filtered like any pool and restricted to the `aaa` category) is taken out of the ordinary AAA pool (`zc2:48926-48942`, `zc2:49130-49136`).
6. Targets: `needed[cat] = rolled count − fixed count`; `targetTotal` is at least `fixed + sum of category minimums` and at most `maxGroups`; if the category needs exceed the room left, random categories that have a range are decremented one by one, never below their minimum (`zc2:49138-49190`).
7. Output order: statics (only if `UseStatics`), then fixed, then for each category in the order sam, shorad, aaa, ground, armor, arty: `want` names drawn without repetition from the category pool, with repetition only when the pool is smaller than `want` (`pickFromPoolAllowRepeats`) (`zc2:49191-49228`, `zc2:48869-48900`).
8. Each picked name passes `applyRandomRedPickKeepChance`: a name listed in the template's `RandomRedPickKeepChance` is kept with that percentage, otherwise swapped for another name of the same pool that is not already picked and preferably not itself in the keep-chance list (`zc2:48902-48924`).
9. If room remains (`total` larger than the sum of categories), names are drawn one at a time from the union of all category pools that still have room below their maximum, falling back to the `other` pool (`zc2:49230-49266`).
10. Flak substitution: one roll of `flakChance` %, then (if `flakMax > 1` and at least two random AAA slots exist) one roll of `flakSecondChance` %; that many randomly chosen random-AAA slots are overwritten with distinct names of the flak pool (`zc2:48956-48998`, `zc2:49268-49270`).

Scaling by `MaxRedGroundGroupsPerZone` (`zc2:49517-49581`): only in PvE, not on Normandy, and only when the setting is below both 12 and the largest `total` maximum of the sizes in use.
Each size then gets a `ceiling`: with a setting ≤ 6, `min(high, setting − gap)` where `gap` is 2 for `small`, 1 for `smallmedium` and `medium`, 0 for `mediumbig`, `big`, `bignosam`; above 6, `high` is reduced by `(high − (6 − gap)) × (mapMax − setting) / (mapMax − 6)` rounded down (rounded to nearest when `gap` is 0); the low bound follows (`zc2:49528`, `zc2:49556-49574`).
With a setting ≤ 6 and `gap > 0` a "weight budget" is also applied: budget = 2 × (min(rolled total, max(tierMinimum, rolled total − 1)) − fixed count) with `tierMinimum` 2 for `small` and 3 otherwise; every random pick costs 2, or 1 for a single-unit AAA/SHORAD template; picks that satisfy a category minimum are always paid, the others are kept in order only while the budget lasts (`zc2:49575-49577`, `zc2:49142-49147`, `zc2:49272-49299`).
Sizes without a `tierGap` entry (`extrabig`, `sam…`, `redarmycamp…`, `smallwithShorad`) keep their template and only the global clamp of `total` (`zc2:49557-49558`, `zc2:49094-49101`).

`buildRandomBlueUpgrades(zone, actualOwner)` follows the same plan with fewer steps: template from `RandomUpgradeTemplatesBlue[size]`, `total` clamped to `MaxBlueGroundGroupsPerZone` (itself clamped to 1–4), statics and fixed/pinned/forced entries first, then per category in the order sam, shorad, ground, aaa, armor, arty a draw **without** repetition, then a fill from the categories still below their maximum, each name used once (`zc2:49304-49330`, `zc2:49366-49399`, `zc2:49438-49506`).
There is no keep-chance, no flak and no scaling for blue.
With `actualOwner` given (PvP), the same function builds the base garrison of either side from `PvPBaseGarrisonProfiles`, keeps the industry-core statics first, and returns a second "materialized" list = base + the paid extra upgrades of that side appended as pinned entries (`zc2:49305-49350`, `zc2:49449-49455`, `zc2:49508-49512`).

Result storage: the drawn list is stored twice, as `zone.randomUpgradesRed` / `randomUpgradesBlue` (the "base", persisted) and as a copy in `zone.upgrades.red` / `.blue` (the working list that extra upgrades later extend) (`zc2:49587-49594`, `zc2:49608-49615`).

`applyRandomUpgradesForNewZonesOnly()` (`zc2:49621-49849`), run instead of the two functions above when a save was loaded:

- a zone is drawn only if it has no saved entry at all, or (PvE) a saved entry without either `randomUpgrades*` list; it then also forgets `remainingUnits` and sets `_refreshRandomUpgrades` (`zc2:49732-49771`);
- on Normandy it first renames old saved extra upgrades `EWR` / `BluePD` to `bluePD` (`zc2:49624-49658`);
- for every zone restored as suspended, each slot of `remainingUnitsSnapshot` is compared with the unit types of the template now in that slot (`_getUpgradeTemplateUnitCount`): the saved survivors are kept when the template name is unchanged and the saved types are a sub-multiset of the template's types for an idle-suspended zone, a PvP zone, a `_preserveSuspendedLosses` zone or a `Blue SAM …` / `Blue Armor …` template; otherwise the slot is reset to the full template (and its saved sub-zone forgotten) as soon as the name changed or the saved types are not exactly the template's (`zc2:49773-49846`, `zc2:49685-49722`).

`pickReplacementUpgrade(zone, missingName, upgradesList, side)` (`zc2:49851-50020`) is the single-slot fallback used when a template fails to spawn or is disabled: it builds the same filtered pools, takes the category of the missing name, and draws uniformly among the pool names of that category not already in `upgradesList`; when that category is empty, not allowed by the size template (maximum 0) or already at its maximum, it draws among all categories that still have room; it returns nil when nothing fits.

### Mechanism — spawning one garrison group

`ZoneCommander:_spawnBuiltGroup` → `CustomZone:spawnGroup(grname, …)` (`zc2:47728`, `zc2:5214-5339`).

1. `Fixed` groups: take the editor template (`GROUP:GetTemplate()` or `_DATABASE.Templates.Groups[name]`), destroy any live copy, `SPAWN:NewFromTemplate(tpl, grname, nil, true):Spawn()` — i.e. `coalition.addGroup` with the original name and positions (`zc2:5220-5243`).
2. Otherwise choose a sub-zone pool: `-SAM-` sub-zones for strategic SAMs, `-SHORAD-` for SHORAD, else the numbered sub-zones, each time preferring ones not yet used by this zone or globally (`USED_SUB_ZONES`), and excluding blacklisted ones and the sub-zone reserved for the warehouse static (`zc2:5254-5288`).
3. If a saved placement `{template, subZone}` is supplied (after a restart or a wake-up) and still valid, reuse it (`zc2:5290-5318`).
4. Else pick sub-zones at random until `SpawnCustom` succeeds; with no sub-zone at all the main zone is used (`zc2:5285-5288`, `zc2:5320-5334`).

`SpawnCustom(grname, zoneName, side, alias)` (`zc2:4621-4674`):
alias is `"<template> # <n>"` with a per-template counter (`zc2:4622-4623`);
`SPAWN:NewFromTemplate(tpl, grname, alias, true):InitSkill(...)` (`zc2:4654`);
non-SAM groups get their unit layout re-randomised with `InitSetUnitRelativePositions(randomGroundLayout(...))`, ships get `InitRandomizeUnits(true, 1500, 1000)` (`zc2:4655-4657`);
SAM templates keep their editor layout;
the spawn point comes from `GetValidCords`, which tries up to 100 random points of the Moose zone and accepts the first whose `land.getSurfaceType` is LAND or ROAD (WATER/SHALLOW_WATER for carrier zones), never RUNWAY (`zc2:4390-4403`, `zc2:4643-4649`);
a sub-zone with no valid point is blacklisted in `INVALID_SPAWN_SUB_ZONES` for the session (`zc2:4404-4413`);
then `spawn:SpawnFromCoordinate(coord)` → `coalition.addGroup` (`zc2:4661-4668`).
SAM groups may be flagged `hiddenOnMFD` according to the `HideSAMOnMFD` setting (`true`, `false`, `"random"`) (`zc2:4432-4439`, `zc2:4651-4653`).

### Reproduction notes

Templates are consumed by name from the mission's late-activated groups; the original template group is destroyed if alive (`zc2:4630`).
Sub-zone bookkeeping is global (`USED_SUB_ZONES`) and per zone (`usedSpawnZones`) and is cleared by prefix when a zone becomes neutral (`zc2:5341-5350`, `zc2:55354-55355`).
The Moose pieces used are `SPAWN` (template copy, alias, unit repositioning, skill) and `ZONE:GetRandomCoordinate`; neither is deep.

## 3. Zone initialisation (`ZoneCommander:init`)

Called for every zone by `bc:init()` after the save file has been applied (`setup:5835`, `setup:5961`).

- Draws the zone shape and its two labels (section 12) (`zc2:51411-51417`, `zc2:51694-51736`).
- For a zone with `airbaseName` (carriers `CVN-72…75` excepted): turns DCS auto-capture off (`ab:autoCapture(false)`), sets the airbase coalition to the zone side with `Airbase:setCoalition`, respawns the slot statics of that base for the side (`RespawnStaticsForAirbase`, 1 s later), and clears the warehouse weapons when warehouse logistics is on and the zone is not a logistic centre (`zc2:51434-51485`).
- Builds the garrison: if the zone has a saved per-slot survivor list (`remainingUnits`), only those slots are respawned and then trimmed unit by unit (`weedOutRemainingUnits`); otherwise slots `1..level` of the filtered upgrade list are spawned (`zc2:51593-51688`, `zc2:51743`).
- A group that fails to spawn is replaced by another template of the same category when one exists (`pickReplacementUpgrade`), and the replacement is written back into the upgrade list (`zc2:51645-51677`).
- A zone restored as suspended does not spawn its garrison: slot names are put in `built` and remembered in `_persistedHibernatedSlots`; only groups whose template is a "suspension-persistent radar" (blue GCI/EWR) are spawned (`zc2:51504-51545`).
- Sets the restricted-group flags, initialises the zone's AI group commanders, seeds supply/advance-capture caches (`zc2:51745-51756`).

`weedOutRemainingUnits(opts)` is the trim pass that turns a freshly respawned full-strength garrison back into the damaged one that was saved (`zc2:51788-51901`).
It first destroys any live group whose name is in the zone's upgrade list but not in `built` (template leftovers), unless `skipDestroyUnspawnedGroups` is set (`zc2:51794-51807`, `zc2:51893-51895`).
The trim itself runs twice, 2 s and 4 s after the call (two one-shot `SCHEDULER`s, the second also fires `opts.onTrimComplete`), because the groups have only just been requested from `coalition.addGroup` (`zc2:51896-51900`).
For each built group it reads the saved slot, either `remainingUnits[slot]` (a list of unit **type names**) or, for "fixed hidden" groups, `remainingUnitNames[slot]` (a list of unit **names**) (`zc2:51814-51821`).
Exact-name branch: if at least one live unit name is in the saved list, every unit whose name is not in it (or exceeds its saved count) is destroyed with `Unit:destroy()` (`zc2:51824-51850`).
Type branch (the "sort by type" case): otherwise a multiset `need[typeName] = count` is built from the saved list and the group's units are walked in order; a unit whose type still has a positive count consumes one, any other unit is destroyed, so the survivors are the first N units of each type, not the same individuals (`zc2:51851-51865`).
An empty saved type list destroys nothing, except in an idle-wake restore (`idleRestoreToken`) where it empties the group (`zc2:51851`).
It also destroys statics listed in `newStatics` that are not in `built` (PvP neutral industry cores excepted) and marks the supply-efficiency cache dirty when anything was removed (`zc2:51869-51891`).
An idle-wake trim is abandoned if the zone changed side, went back to sleep or was superseded by a newer wake in the meantime (`zc2:51810-51812`).

Statics as garrison: when `UseStatics` is true a static named in `upgrades` counts as a built slot as long as it exists; when false, such statics are destroyed by `getFilteredUpgrades` (`zc2:51510-51515`, `zc2:48403-48408`).

`getFilteredUpgrades()` returns the upgrade list of the current owner with red templates disabled in Config removed or substituted (`getRedTemplateReplacement`), and returns an empty list for a neutral zone (`zc2:48329-48414`).

## 4. The zone update loop, losses, repairs and "combat effectiveness"

### Mechanism

`BattleCommander:new(savepath, updateFrequency, saveFrequency)` is called with `updateFrequency = 10` s and `saveFrequency = 60` s (`setup:754`, `zc2:17082`).
`BattleCommander:update()` runs once per period; after a first synchronous pass it processes zones as a "wave": one `zone:update()` every 0.1 s through a self-rescheduling `timer.scheduleFunction`, and a tick that arrives while a wave is still running is queued, not run in parallel (`zc2:43291-43347`).
After the wave: zone-intel update, ROE monitor, difficulty fade (`zc2:43255-43276`).

`ZoneCommander:update()` per zone (`zc2:55146-55204`):

1. Inactive zones do nothing.
2. Advance the pending capture timer (section 7).
3. Warehouse facility state (other theme).
4. Pay `income` to the owner (PvE: a blue zone that is distance-suspended earns nothing; `redIncomeOnly` zones pay only red) (`zc2:55155-55168`).
5. Suspended zones stop here (only their active AI groups are updated) (`zc2:55169-55174`).
6. Every `GlobalSettings.builtMaintenanceNormalSec` (default 30 s, per-zone override `_builtMaintenanceInterval`), aligned on the 10 s tick and spread over slots by a per-zone ordinal so that all zones do not scan on the same tick, run `_maintainBuiltState` (`zc2:55175-55182`, `zc2:37394-37406`).
7. If `built` is empty and the zone has an owner → `_neutralizeEmptyBuiltZone()` (section 6) (`zc2:55184-55188`).
8. Update the zone's active AI groups, process supply crates, refresh restricted-group flags (`zc2:55190-55203`).

`_maintainBuiltState` (`zc2:55741-56030`) walks every built slot with raw DCS calls (`Group.getByName`, `StaticObject.getByName`, `getSize`, `getInitialSize`, `getLife`):

- a group with size 0 or with no unit of life ≥ 1 is destroyed and its slot removed; a static with life < 1 likewise; a name that no longer resolves is removed (`zc2:55844-55847`, `zc2:55923-55948`, `zc2:55971-55979`);
- a removed slot produces the optional message "ZONE_LOST_GROUP" (`GlobalSettings.messages.grouplost`) (`zc2:55624`);
- a slot is kept in `built` although destroyed if a local repair/rebuild job already targets it, unless everything was destroyed (`zc2:55598-55613`);
- with `UseStatics`, a destroyed static is recorded in `retiredStaticUpgrades` and removed from the upgrade list for good (`zc2:55617-55647`);
- it accumulates "operational capacity" (alive units / authored units per group), counts damaged groups, and publishes snapshots used by supply demand, SEAD threat, JTAC targets and labels (`zc2:55898-55922`, `zc2:56018-56026`).

Combat effectiveness and surrender (red, visible, non-carrier zones only, `zc2:55780-55781`):

- State `full`, `reduced` (damaged, mobile units left, no air defence left) or `static` (damaged, only statics left) recolours the zone fill: red `{1,0,0,0.3}`, light red `{1,0.45,0.45,0.3}`, purple `{0.55,0.2,0.7,0.3}` (`zc2:55655-55664`, `zc2:45911-45915`).
- Air defence = unit has attribute `SAM TR`, `AAA` or `IR Guided SAM`; "weak" = not air defence and `Unarmed vehicles` or `Infantry` (`zc2:45901-45908`).
- When the zone is no longer "strong" (no static, no ship, no air defence, all mobile groups weak, at most 4 live units), a tier 4..1 is evaluated and a surrender roll is made with chance 40/60/70/80 % for tiers 4/3/2/1 (`zc2:55666-55683`, `zc2:45916-45921`).
- The tier **is** the number of live garrison units (1 to 4): `EvaluateZoneSurrenderTransition` keeps three values per zone — the last observed live-unit count, whether the zone was strong at the last scan, and the lowest tier already rolled (`surrenderEvaluatedTier`, persisted) — and returns a tier to roll only when the zone has weakened since the last scan (it was strong, or the count dropped) and the count is lower than any tier already rolled (`zc2:45942-45970`).
- Consequences: at most one roll per tier and per weakening cycle, so at most four rolls (4, 3, 2, 1 units) as the garrison is worn down; the first scan after a load or wake-up only seeds the observation and never rolls; a zone that becomes strong again (repair, upgrade) forgets its rolled tiers; a protected zone (below) is left untouched (`zc2:45944-45958`, `zc2:45973-45982`).
- The roll itself uses `math.random(1,100) <= chance`, not the campaign generator (`zc2:55998`).
- On success all weak groups are destroyed and removed from `built`, and blue gets "ZONE_ENEMY_FORCES_SURRENDERED" (`zc2:55998-56010`, `zc2:55686-55705`).
- Units targeted by an active CAS slot are "surrender-protected" (`zc2:55729-55733`, `zc2:46001`).

### Upgrade and repair (`ZoneCommander:upgrade`)

`zone:upgrade(silent, repairTargetName, upgradeTargetIndex)` does exactly one step per call (`zc2:56884-57100`):

- first pass over `built`: the first group whose size is below its initial size is respawned whole (`RespawnZoneRepairTarget`), message "ZONE_REPAIRED" (red) or "ZONE_GROUP_REPAIRED" (blue), trigger `repaired`, `world.removeJunk` over the zone sphere, label refresh, then stop (`zc2:56919-56985`, `zc2:56873-56882`);
- if nothing needed repair and all slots are full → "ZONE_ALREADY_FULLY_UPGRADED" (blue only), return false (`zc2:56990-56995`);
- otherwise the first missing slot is spawned (group via `_spawnBuiltGroup`, static via `SPAWNSTATIC:NewFromTemplate(...):SpawnFromCoordinate` → `coalition.addStaticObject`), message "ZONE_UPGRADED_COUNT" n/total (blue) or "ZONE_DEFENSES_UPGRADED" (red, also shown to blue in PvE), trigger `upgraded` (`zc2:56997-57089`).

Who calls `upgrade()`: each successful supply delivery to a friendly zone (AI supply flight or convoy, player supply crate, pre-placed crate — `zc2:55236-55248`, `zc2:69981-69985`), the capture itself (one step, `zc2:56702-56707`), the regular-supply "local recovery" jobs (other theme: logistics), admin commands, and the "until complete" loops below.

"Until complete" loops, all built on a self-rescheduling `timer.scheduleFunction` that stops as soon as the zone changes side:

- `ZoneCommander:UpgradeUntilComplete(onComplete, delaySeconds)`: returns false at once when nothing is damaged or missing; otherwise, starting 1 s later and then every `delaySeconds` (default 2 s), each step either respawns one damaged group (`RespawnZoneRepairTarget`) or, when none is damaged, calls `upgrade(true)` for one missing slot; `onComplete(zone)` is called after the last step (`zc2:50822-50856`).
  Its only caller in the Caucasus setup is the shop item `supplies` ("fully upgrade zone") (`setup:4017-4035`).
- `ScheduleZoneUpgradeUntilComplete(zone, …)` (local): upgrade-only variant (no repair), one silent `upgrade(true)` every 2 s until `built` is as long as the filtered upgrade list; used by `MakeZoneRedAndUpgrade` and the two `AwakenZone…` variants (`zc2:50494-50513`, `zc2:50518`, `zc2:50628`, `zc2:50637`).
- `upgradeRedZones()` / `upgradeBlueZones()` (admin markers `upgradeallred` / `upgradeallblue`): collect every visible, awake zone of the side that needs a repair or a slot, then process them one after the other, 10 s apart, each with its own 2 s repair-or-upgrade loop; a busy flag refuses a second run and "all zones fully upgraded" is printed at the end (`zc2:50858-50975`).

### Reproduction notes

Loss detection is polling, not event-driven: no `S_EVENT_DEAD` handler feeds `built`.
The scan cost is bounded by staggering (0.1 s between zones, 30 s maintenance period spread over ticks) and by skipping suspended zones.
A group is repaired by destroying and respawning it at full strength in its remembered sub-zone, not by reviving units.

## 5. Losing a zone: neutralisation, disabling, critical objects

### Player view

A zone never changes hands directly: it first becomes neutral when its last garrison slot is gone, then someone has to capture it.
Messages on neutralisation (if `GlobalSettings.messages.zonelost`, zone not hidden): the previous owner reads "We have lost <zone>!", the other side "<zone> is now neutral", and everybody hears `ding.ogg` (`zc2:55370-55376`, `l10n:1414-1415`).
The zone circle and labels turn grey (`zc2:55402-55407`).
Some zones "disappear" instead: after loss they are drawn almost black and announce "<zone> has been destroyed" (`zc2:50242-50256`, `l10n:1419`).

### Mechanism — `_neutralizeEmptyBuiltZone` (`zc2:55294-55451`)

Trigger: in `ZoneCommander:update`, `next(self.built) == nil` on an owned active zone (`zc2:55184-55188`).
Effects, in order: difficulty escalation if the loser is the "difficulty coalition" (`zc2:55297-55299`); `side = 0`; all dormancy flags cleared; the Director is told (`Director:recordZoneOwnershipChange`); held advance-capture supplies for that zone are released (`zc2:55337`); triggers `lost` run (`zc2:55341`); `bc:buildConnectionMap(zone, previousSide)`; territory overlay and connection lines of that zone redrawn; zone-status menu and frontline refresh requested (`zc2:55342-55351`); used sub-zones freed (`zc2:55354-55355`); the DCS airbase is set to coalition 0, its slot statics respawned as neutral, its warehouse weapons cleared when warehouse logistics is on (`zc2:55356-55368`); CTLD zones re-evaluated (`addCTLDZonesForBlueControlled`), `SpawnFriendlyAssets(zone)` scheduled 2 s later, CAP spawn buckets rebuilt 5 s later, red difficulty rebalanced (`zc2:55433-55450`).
A carrier zone that becomes neutral with warehouse logistics on is disabled in the Vietnam era, or auto-recaptured by blue after 5 s on maps other than Caucasus (with a Persian Gulf exception) (`zc2:55377-55400`).

### Mechanism — disabling

`ZoneCommander:disableZone(silent)` destroys every built group/static and the critical statics, sets `side = 0` and `active = false`, runs triggers `destroyed`, rebuilds the connection map and redraws (`zc2:50185-50270`).
An inactive zone is skipped by `update()` (`zc2:55147`), cannot be captured (`capture()` requires `active`, `zc2:56559`; a capture attempt prints "<zone> has been destroyed and can no longer be captured", `zc2:56793-56802`), and is drawn dark (`zc2:51402-51405`).
It is called (a) by `checkCriticalObjects` when all `criticalObjects` statics are dead (polled in the maintenance pass, `zc2:55742-55744`, `zc2:51904-51930`), (b) by setup-file `lost` triggers of single-use zones, e.g. the insurgency grids which also pay 500 credits to blue (`setup:2725-2729`).
`checkAndDisableFriendlyZones()` is not a caller of `disableZone`: it is an optional setup-file hook that `capture()` invokes after every capture when the global exists (`zc2:56686-56688`).
In the Caucasus setup it is an empty function (`setup:2048-2049`); other maps use it to turn hidden reserve zones red (`MakeZoneRedAndUpgrade`) or destroy them (`DestroyHiddenZone`) according to which named zones are blue, and also schedule it once 3 to 10 s after start (`COLDWAR_SETUP.lua:2302-2333`, `foothold pg nya v2.lua:1627-1647`, `IRAQ_SETUP.lua:1411-1424`).
`RecaptureBlueZone()` is the reverse of disabling, reachable only from the admin marker `recapture`: on an inactive zone it sets `active = true`, invalidates the CAP SAM-threat cache and, 2 s later, calls `capture(2, true)`; on an active zone it does nothing (`zc2:50977-50992`, `zc2:29149-29155`).
`DestroyHiddenZone()` is the variant for hidden zones: no messages, no drawing (`zc2:50146-50183`).

### Reproduction notes

"Neutral" is a real third state with its own garrison list (empty) and its own airbase coalition; the DCS airbase auto-capture is switched off at init so that DCS never contradicts the script (`zc2:51439`).
Triggers are plain callbacks stored on the zone with an optional run-count limit (`zc2:50064-50084`).

## 6. Capturing a neutral zone — the channels

`ZoneCommander:capture(newside, silent)` only acts when the zone is active and neutral (`zc2:56559`).
Except for admin commands, nobody calls it directly: every channel goes through `startPendingCapture` (section 7), which calls `capture` when its timer ends (`zc2:47081`).

| Channel | Who | Code |
|---|---|---|
| AI supply helicopter or plane lands in a neutral zone | Both sides' AI supply flights, including the ones bought in the shop ("capture mission") | `zc2:67826-67840` (landing path), `zc2:69943-69957` |
| AI ground or ship supply convoy stops inside a neutral zone | Both sides | `zc2:69958-69971`, `zc2:70067-70102` |
| Player CTLD troops deployed in a neutral zone | Blue (and red in PvP) helicopter/transport pilots | `ctld:9263-9290` |
| Player CTLD "zone supply" crate dropped/unloaded in a neutral zone | Blue; red equivalent | `ctld:5316-5349`, `ctldred:2160` |
| Player "internal supplies" unloaded from the logistics menu | Players, both sides | `zc2:98238-98268` |
| Hercules airdrop of a supply container | Players | `zc2:102378-102400` |
| Pre-placed static crate (`crates = {...}`) resting on the ground in the zone | Mission maker / sling-load | `zc2:55206-55235` |
| Blue escort mission ground group reaching a neutral target zone | Mission "Escort" | `zc2:104187-104213` |
| Shop item "capture"/"emergency capture" → `requestCaptureMission` | Blue (or the buying side in PvP) | `zc2:23416-23569` |
| Shop item "advance capture" (pre-positioned supply held until the zone falls) | Blue | section 8 |
| Admin F10 map markers `capture:1`, `capture:2`, aliases | Server admin | `zc2:29172-29202` |
| Carrier auto-recapture | Engine | `zc2:55385-55397` |

`requestCaptureMission(zone, options)` picks the best supply `GroupCommander` for that target (`_selectShopSupplyCommander`), optionally re-bases it on a nearer FARP, forces its state to `preparing` with `urgent = true`, and announces "looking for pilots", a convoy departure or an "emergency capture" message; the flight then captures through the normal AI landing channel (`zc2:23436-23568`).
It refuses a zone that already has a pending capture and a non-neutral zone unless the call is an advance capture on an active, awake red zone (`zc2:23420-23431`).

### What `capture()` does (`zc2:56557-56818`)

- Cancels any pending capture, sets `side`, clears dormancy and surrender state, tells the Director (`zc2:56558-56600`).
- Marks every derived cache dirty: CAP targets, FSM group filter, combat reindex, supply cache, shop selector buckets, hunt bases (`zc2:56603-56606`, `zc2:56671-56672`).
- Records the capture time for the red "reactive" logic when blue captured (`zc2:56611-56616`).
- Recolours the map shape and labels (`zc2:56655-56658`), draws a green dashed outline if blue and an air spawn (`zc2:56750-56753`).
- Schedules `SpawnFriendlyAssets(zone)` (+2 s) and re-evaluates CTLD zones (`zc2:56642-56654`).
- Runs triggers `captured` (`zc2:56659`).
- Rebuilds the connection map, redraws the territory cell and the connection lines of that zone, requests a frontline refresh and an AWACS reposition (+15 s), aborts enemy supply flights still heading to the zone (+10 s) (`zc2:56665-56684`).
- Message to all "<zone> captured by RED|BLUE" if `GlobalSettings.messages.captured` (`zc2:56696-56700`, `l10n:1417`).
- Spawns the first garrison slot with `self:upgrade()`; the rest arrives through supply (`zc2:56702-56707`).
- On blue capture, lets the red Director consider diverting CAS onto the zone (`zc2:56708-56710`).
- For a zone with an airbase: `Airbase:setCoalition(side)`, `RespawnStaticsForAirbase(airbase, side)` (the slot statics), and a synthetic `S_EVENT_BASE_CAPTURED` pushed through `world.onEvent` so that other scripts react (`zc2:56754-56770`).
- On a neutral→blue capture, 1 s later, every landed blue player inside the zone with a pending contribution gets a synthetic `S_EVENT_LAND` so that the reward is cashed without taking off again (`zc2:56713-56748`).
- AI groups based in the zone that are `inhangar`/`dead` get a fresh random start delay (30 s if urgent, else 60 s to `initialDelayVariance` minutes) (`zc2:56775-56785`).
- CAP spawn buckets rebuilt, dynamic control menu refreshed, difficulty decreased if the capturer is the difficulty coalition (`zc2:56786-56791`).

Rewards on capture are paid by the delivery handler of the participant, not by `capture()` (section 7).

## 7. Pending capture (capture takes time)

### Player view

Bringing something that can capture into a neutral zone starts a countdown; the first deliverer's side reads "Capturing <zone>...", the enemy (blue only in PvE) reads "Enemy is capturing <zone>" with `Intel_short.ogg` (`zc2:46781-46795`, `l10n:1375-1376`).
During the countdown the neutral grey fill blends toward the capturing side's colour in 4 steps (20/40/60/80 %) and the zone label is refreshed every second (`zc2:46730-46763`, `zc2:46772-46779`, `zc2:45876-45881`).
The capture succeeds when the timer ends if at least one participant is still alive inside the zone; it is cancelled when all participants are lost.

### Mission-maker view

`ZoneCaptureBuildSeconds = 120` in the Config file; 0 makes capture immediate (`config:1284`, `zc2:45866`, `zc2:47035-47038`).

### Mechanism

State: `zone.pendingCapture = { side, startedAt, completeAt, participants = {name → participant}, nextJoinOrder }` (`zc2:47019-47032`).
A participant is `{kind = 'group'|'static', name, template, position, heading, unitTypes, staticType, country, destroyOnFinish, tombstone, retireAction, delivery = {handler, payload}, joinOrder}` (`zc2:46999-47012`).
`startPendingCapture(side, request)` refuses: an invalid side, a zone not active or not neutral, a zone with a capture being restored from the save, and a participant of the other side while a capture is running ("reserved") (`zc2:46986-46997`).
A second participant of the same side joins the running capture without resetting the timer (`zc2:47030-47050`).
`stopGroup = true` freezes a ground group with `trigger.action.groupStopMoving` (`zc2:47044-47047`).
For AI aircraft, `startPendingCaptureFromAircraft` spawns a small infantry team ("CTLD_TROOPS_ATS" / "CTLD_TROOPS_RED_Squad_8", Normandy variants) 20+ m behind the landed aircraft with `SPAWN:NewWithAlias(...):InitCoalition(side):SpawnFromVec2` and registers that group as the participant; the aircraft is free to leave (`zc2:46797-46846`, `zc2:46765-46770`).
For player-carried supplies and Hercules drops, `startPendingCaptureWithCargoStatic` creates a cargo static (`coalition.addStaticObject`, category `Cargos`, type `ammo_cargo` or `iso_container_small`) and registers it (`zc2:46848-46877`, `zc2:102383-102387`).
`_updatePendingCapture(now)` runs at every zone update (10 s): removes dead or out-of-zone participants (`Utils.someOfGroupInZone` for groups, `Utils.isInZone` for statics), cancels when none is left, completes when `now >= completeAt` (`zc2:47098-47125`, `zc2:46879-46937`).
`_completePendingCapture` calls `capture(side)`, then for each participant in join order: participants after the first apply one extra supply delivery (i.e. an upgrade step), the delivery handler is dispatched with `succeeded`, the participant object is destroyed if `destroyOnFinish`, the AI commander is sent back to hangar, and a "tombstone" entry keeps the name reserved for 900 s (`zc2:47065-47096`, `zc2:46964-46984`, `zc2:45867`).
Delivery handlers are registered by name with `bc:registerPendingCaptureHandler(name, fn)`; the engine's own `zonecommander_capture_delivery` pays `captureFundReward` (default `rewards['Zone capture']` or 200) to the first participant's player or coalition, `upgradeFundReward` (default 100) to joiners, adds warehouse stock, and records career stats (`zc2:24675-24739`, `zc2:98260-98261`, `zc2:30233-30235`).
CTLD registers its own handlers `blue_ctld_capture_delivery` and `blue_ctld_troop_capture` (`ctld:5340`, `ctld:9277`).
Pending captures are saved and restored (`_serializePendingCapture`, `_restorePendingCapture`, `zc2:47127-47199`; format belongs to the persistence theme).

### Reproduction notes

The capture is anchored on a physical object that can be killed, which is what makes a capture contestable.
The check period is the zone tick (10 s), so the effective duration is `ZoneCaptureBuildSeconds` rounded up to the next tick.
Red AI ground convoys wait 60 s before acting when a blue player is within 5 NM of the target (`BlueIsNear`) (`zc2:70080-70087`, `zc2:37149-37151`).

## 8. Advance capture

### Player view

Blue can buy an "advance capture" on a red zone that has been worn down: a supply flight or convoy is sent early, holds near the zone, and is released to capture as soon as the zone turns neutral.
Blue reads "Advance Capture is now available for <zone>." when a zone becomes eligible (`zc2:17631-17647`, `l10n:574`).

### Mission-maker view

`AdvanceCaptureRemainingThreshold` (default 0.50, accepted as a ratio or a percentage, clamped to 0.20–0.60): the zone is eligible when its built/total ratio has fallen to that value or below (`zc2:50106-50110`).
`AdvanceCaptureAbortRemainingThreshold` (default 0.90): if the zone is repaired back above that ratio, held supplies are sent home or cancelled (`zc2:55489-55501`, `zc2:60205-60292`).

### Mechanism

Eligibility (`zc2:50100-50142`): zone active, not suspended, not hidden, red, with no `lost`/`destroyed` trigger other than the mission-complete one, "armed" (its ratio has been seen above the threshold at least once since it became red), ratio > 0 and ≤ threshold.
Recomputed at each maintenance pass (not on Normandy) (`zc2:56027-56029`, `zc2:55453-55488`); a change updates the shop selector bucket `advance_capture_targets` and queues the availability message.
The purchase calls `requestCaptureMission(zone, {advanceCapture = true})`, which sets `_advanceCaptureWaitingForNeutral` on the chosen supply commander (`zc2:23494-23498`); carrier zones are refused (`zc2:23426-23428`).
When the zone is neutralised, `_releaseAdvanceCaptureHeldSupply(zone)` re-routes the holding helicopters/planes/convoys to land or drive in (`zc2:55337`, `zc2:60041-60075`).
### Mechanism — hold, release and abort routes

The hold point is always "80 % of the way, but never closer than a minimum distance to the target": `holdDistance = min(0.8 × L, L − dmin)`, 0 when `L ≤ dmin`, with `dmin` = 25 NM for planes, 10 NM for helicopters, 4 NM of road distance for convoys (`zc2:57939-57955`, `zc2:59785-59801`, `zc2:58616-58624`, `zc2:68909-68918`).
The point is stored in `gc._advanceCaptureHold = {x, z, aglM|altitude}` and persisted, so a restored flight returns to the same hold (`zc2:57996`, `zc2:59849`, `zc2:25485-25492`, `zc2:29759`).

`_assignAdvanceCaptureHoldRoute` dispatches by carrier type (`zc2:59447-59468`):

| Carrier | Hold route | Code |
|---|---|---|
| Plane | Two raw waypoints pushed with `GROUP:Route`: a take-off point, then a fly-over turning point at the hold carrying `ComboTask{ Orbit{pattern = CIRCLE, point, speed = 250 kt IAS converted to TAS, altitude = cruise altitude BARO} }`. | `zc2:57922-58007` |
| Helicopter, no cargo | Current position → the usual supply transit waypoints stopped at the hold → a turning point "Advance Capture Hold" at 200 m AGL carrying an `Orbit` task with `pattern = "Race-Track"`, `speed = 0` (a hover). | `zc2:59776-59850`, `zc2:58083-58097` |
| Helicopter, sling load (`WarehouseLogistics` and `SuppliesCargoTransport` on, not `NotCargo`) | Same, preceded by a waypoint whose task is the cargo pick-up (`ExternalCargoLoad`) of a freshly spawned 600 kg container; release is not allowed before 120 s after the route was set, and is forced after 600 s even if the helicopter never reported reaching the hold. | `zc2:59439-59463`, `zc2:58640-58705` |
| Helicopter, internal cargo | The internal-cargo logistics route (same function as a normal delivery). | `zc2:59451-59454` |
| Ground / ship convoy | The normal supply road route (`dc.GetSupplyConvoyRoute`) is deep-copied and cut at the hold distance measured along its legs; the last point is moved to the hold position and loses its task, so the convoy simply stops there. | `zc2:68871-68954`, `zc2:68974-68979` |

Release, `_releaseAdvanceCaptureHeldSupply(zoneName)`, called from `_neutralizeEmptyBuiltZone` (`zc2:60041-60203`):

- every supply commander with `_advanceCaptureWaitingForNeutral` and that target is re-routed: a plane gets the ordinary `_assignPlaneRoute` to the zone, a helicopter gets its unload-and-land route (sling load, internal cargo) or the plain `_assignHeloRoute`, a convoy gets a fresh road route from its current position (`dc.BuildSupplyConvoyRouteFromPoint`) pushed 1 s after a `controller:popTask()` (`zc2:60129-60196`, `zc2:59503-59527`);
- a sling-load helicopter is released only when `_advanceCaptureExternalCargoCanRelease` is true: the 120 s delay has elapsed **and** the lead unit has been seen within 1 NM of the hold point, or the 600 s fallback has expired; otherwise the release is retried at each in-air update of that group as long as the target is neutral or friendly (`zc2:59995-60025`, `zc2:60142-60163`, `zc2:67623-67652`);
- the same function also turns around supply groups that were already flying home after an abort (`_supplyReturnHome`) and sends them to the zone (`zc2:60045-60127`).

If the zone is already neutral or friendly when the purchase is processed, `_assignAdvanceCaptureOpenRoute` skips the hold and assigns the normal delivery route directly (`zc2:59470-59501`).

Abort, `_abortAdvanceCaptureHeldSupply(zoneName, ratio)`, called when the zone has been repaired above `AdvanceCaptureAbortRemainingThreshold` (`zc2:60205-60292`): an airborne flight is routed back to its own zone with `_supplyReturnHome = true`; a flight still in `takeoff` is destroyed with its cargo and returned to the hangar; a convoy still `preparing` goes back to the hangar; a convoy `enroute` gets a road route home.

## 9. Zone dormancy: distance suspension, idle suspension, wake-up

### Player view

Players do not see dormancy directly: a suspended zone keeps its colour, label and ownership, but its garrison does not exist in the world.
A zone wakes up when an enemy player comes within `proximityWakeNm`, when the front gets close, or when an AI mission targets or overflies it.
The admin map marker `whynot` prints the suspend decision of the zone under it (`zc2:28918-28922`).
`explainSuspendDecision(zoneName, groupId)` prints a 25 s text to the group (or to all) (`zc2:37219-37392`).
With idle suspension enabled and a stored decision record it prints that record: state (`idle` / `normal` / `awake`), age of the decision, nearest-enemy distance against the full and idle limits, and one boolean per hold (`idleCandidate`, `normalSuspend`, `nearbyHold`, `settlingHold`, `attackHold`, `eventHold`, `committed`, `playerObjective`, `incomingSupply`, `canReceive`, `supplierHold`, `playerHold`, `jtacHold`, `farpHold`, `carrierHold`, `neighborHold`, `criticalHold`, `reactiveHold`, `startupRestore`, `sa5Hold`, `noIdleSuspend`) (`zc2:37222-37235`).
Otherwise it recomputes the decision on the spot with the same inputs as `_autoZoneSuspend` (it calls `reindexCombatZones(true, true)` to also get the textual sources) and prints the distance, limit, neighbour flags, neutral-wake test, incoming/receivable supply, the list of the zone's own attack/patrol groups that keep it active as an origin, the lists of groups that make it an active target, and the verdict `=> shouldSuspend=` (`zc2:37244-37391`).

### Settings

| Setting | Default in engine | Caucasus setup | Meaning | Where |
|---|---|---|---|---|
| `GlobalSettings.autoSuspendNmBlue` | 80 | 70 (PvE), 100 (PvP) | A blue zone farther than this from the nearest active enemy zone is suspended. | `zc2:8526`, `setup:6063-6069` |
| `GlobalSettings.autoSuspendNmRed` | 120 | 95 (PvE), 100 (PvP) | Same for red zones. | `zc2:8527`, `setup:6064-6069` |
| `zone.customSuspendNm`, `customSuspendNmRed`, `customSuspendNmBlue` | — | 1000 on two home SAM sites in PvP | Per-zone override of the limit. | `zc2:37520-37523`, `setup:989-992` |
| `GlobalSettings.neutralWakeFactor` | 0.5 | — | Stay awake if a neutral zone lies within limit × factor. | `zc2:8528`, `zc2:37763` |
| `GlobalSettings.proximityWakeNm` | 40 | 50 (PvP) | Enemy player distance that wakes a zone. | `zc2:8524`, `zc2:37103` |
| `GlobalSettings.proximityWakeHoldSeconds` | 600 | — | How long a proximity wake holds. | `zc2:8525`, `zc2:37142` |
| `GlobalSettings.idleZoneSuspendEnabled` | true | — | Enables the second, "idle" level of sleep. | `zc2:8464` |
| `GlobalSettings.idleZoneSuspendFactor` | 0.5 | — | Idle sleep applies beyond limit × factor. | `zc2:8465`, `zc2:37810` |
| `GlobalSettings.idleZoneWakeHoldSec` | 120 | — | Minimum awake time after an idle wake, and timeout of a wake restoration. | `zc2:8466`, `zc2:35709`, `zc2:48011` |
| `zone.noIdleSuspend` | — | true on the same two SAM sites | Never idle-suspend this zone. | `zc2:37804` |
| `GlobalSettings.builtMaintenanceNormalSec` / `SlowSec` / `SlowFactorBlue` / `SlowFactorRed` | 30 / 60 / 0.50 / 0.80 | — | Garrison scan period buckets (below). | `zc2:37527-37531` |

### Mechanism — the decision (`BattleCommander:_autoZoneSuspend`, every 60 s, first run at +1 s)

Scheduled by `SCHEDULER:New(self, …, {}, 1, 60)` in `bc:init()`; `_proximityWakeSuspendedZones` runs on its own 60 s scheduler starting at +10 s (`zc2:30291-30292`).
Hidden zones and carrier zones are never considered (`zc2:37752`).
For each owned active zone it computes (`zc2:37753-37834`):

- `dist`: distance in NM to the nearest enemy zone that is awake or idle-suspended, from the precomputed `ZONE_DISTANCES` matrix (`zc2:37555-37576`); blue zones ignore red "Popup" zones and red zones that can neither spawn nor attack (`zc2:35032-35037`, `zc2:37446-37462`);
- `hasOppositeNeighbor`, `hasNeutralNeighbor`: from the connection graph (`zc2:37662-37689`);
- `neutralHalfWake`: a neutral zone within limit × `neutralWakeFactor` (neutral-at-start zones do not count for red) (`zc2:37577-37591`, `zc2:37763`);
- `combat` / `originActive`: the zone is the target or the origin of a live AI attack/patrol (from `reindexCombatZones`) (`zc2:37463`, `zc2:37764-37765`);
- `incoming`: a live supply group is heading to it; `canReceive`: it has unmet supply demand (`zc2:37699-37721`, `zc2:37617-37645`);
- holds: active JTAC on the zone, player proximity wake still valid, carrier navigation link, a dynamic FARP within 20 NM, critical objects present, red reactive pressure (`zc2:37778-37791`).

`shouldSuspend` = none of the holds, no enemy or neutral neighbour, no combat, no incoming supply, cannot receive supply, and `dist > limit` (`zc2:37802`).

`reindexCombatZones(includeSources, useAutoSuspendEnemyReferences)` rebuilds the two sets used above, `_activeAttackOrPatrol[zoneName]` (zones that are a live target) and `_activeOrigin[zoneName]` (zones that are a live origin), from scratch at each call (`zc2:35040-35228`).
It walks, for every zone, a cached list of its attack/patrol group commanders (`_getReindexCombatCache`) and for each one computes: `live` (state other than `inhangar`/`dead`), `spawnable` (the cached result of the spawn-eligibility gate), `directorReserved` (the Director holds the group for an operation), and `sideValid` (patrol: origin and target on the same side; attack: target owned by the other side and not neutral) (`zc2:35074-35103`).
A record counts when it has a reason (`spawnable`, `live` or `director-reserved`) and is side-valid or live: an attack record marks its origin active and, if the target is active, visible, owned and awake or idle-suspended, its target active; a patrol record marks both only when the patrolled zone is within its own suspend limit of an enemy zone (`zc2:35120-35170`).
Passive Director capabilities (`directorPassiveCombatByOrigin[origin].attack/.patrol`, counts per target) add the same marks without a live group (`zc2:35184-35222`).
Side effects: a group on its way home re-wakes the idle zones of its return footprint, and a committed group re-wakes its target footprint (`_wakeIdleMissionZones`) (`zc2:35105-35118`).
It returns the per-zone nearest-enemy distance cache and the set of "committed" target names, which the idle-suspend test uses (`zc2:35227`).
With `includeSources` it also fills `_activeAttackOrPatrolSources` / `_activeOriginSources` with one text line per contributing group, for the `whynot` explanation (`zc2:35043-35044`, `zc2:35133-35136`).
Otherwise a suspended zone is queued for resume (`zc2:37841-37848`).
Extra wake rules: up to two suspended neighbours of each neutral zone are woken if they have a reason to act (`zc2:37723-37749`); red zones within 12 NM (5 NM on Normandy) of an awake red zone are kept awake together (`zc2:37857-37909`); a zone with a damaged blue GCI radar is always woken (`zc2:37503-37506`, `zc2:37914`).

Idle suspension is a second, shallower level decided in the same pass: a zone that is not due for full suspension but is farther than limit × `idleZoneSuspendFactor`, with no hold, no committed AI target, no player objective (`ActiveCurrentMission`), no supply demand, no SA-5 tracking threat, and not near a busy friendly zone, is put to sleep with `suspend(true)` (`zc2:37804-37818`, `zc2:37923-37943`).
New idle sleeps are deferred until the first pass has completed and saved AI has been restored (`zc2:37486-37488`).
Each zone keeps the full decision record in `_idleSuspendDecision` for the admin explanation (`zc2:37819-37834`, `zc2:37931-37936`).

The same pass sets each awake zone's garrison scan period: 10 s (the update frequency) when under any pressure or not fully built, 60 s when stable and farther than limit × 0.5 (blue) or × 0.8 (red), else 30 s (`zc2:37785-37801`).

### Mechanism — proximity wake (`_proximityWakeSuspendedZones`, every 60 s)

Takes a snapshot of all players of both sides with their position (`getPlayerSnapshot`), and for every owned zone tests the squared 2D distance of each enemy player to the zone centre (`zc2:37071-37139`).
Within `proximityWakeNm`: `_proximityWakeUntil = now + hold` and `resume()` if suspended (`zc2:37141-37147`).
It also sets, for red zones connected to blue territory, `BlueIsNear` (a blue player within 5 NM) and `BluePlaneIsNear` (a blue airplane within 15 NM), used to delay red supply landings and block spawns (`zc2:37104-37154`).
The same loop refreshes `bc.playersState` (lat/long of every player) for the external status export (`zc2:37090-37097`).

### Mechanism — idle wake by AI missions

`_wakeIdleMissionZones(owner, target, routePoints, threatView)` builds a "footprint" for an AI group: the target zone, its same-side neighbours within the near-zone radius, and every zone whose SAM threat circle touches the target or any leg of the route; each is given `_idleWakeUntil = now + 120 s` and resumed if idle-suspended; the function returns true only when all are awake, so launches wait for it (`zc2:35649-35715`).
Callers are the AI route builders and the supply loop (`zc2:35321`, `zc2:35412`, `zc2:37713-37717`).

### Mechanism — `suspend` and `resume`

`ZoneCommander:suspend(idle)` (`zc2:47748-47852`): keeps the AI groups that are currently live in a side list so that they continue to be updated; snapshots the garrison as `remainingUnitsSnapshot[slot] = {unit type names}` (alive units only for an idle suspend) and, for fixed hidden groups, unit names; then destroys every built group with `Group:destroy()` and records its name in `_hibernated`; `built` keeps the slot names; blue GCI/EWR radar groups are never destroyed (`IsSuspensionPersistentRadarTemplateName`).
Statics are not touched.

`ZoneCommander:resume()` (`zc2:47901-48084`) does not spawn immediately: it enqueues a job in a global wake queue served by one worker that performs **one step every 0.1 s**, and one step spawns **one group** (`zc2:47854-47899`, `zc2:47941-48004`).
After the last group: `suspended = false`, then `weedOutRemainingUnits` trims each respawned group down to the snapshot (so losses suffered before sleeping are preserved), caches are dirtied, the label is refreshed (`zc2:48024-48080`).
If some groups failed to spawn the job is retried 2 s later; an idle wake that cannot finish within `idleZoneWakeHoldSec` is abandoned (`zc2:48009-48023`).
A zone restored from a save as suspended starts with `_persistedHibernatedSlots` and is treated the same way (`zc2:51504-51545`, `zc2:47936-47975`).

Effects of being suspended elsewhere: no garrison scan, no crate processing, no restricted-group refresh (`zc2:55169-55174`); in PvE a fully (not idle) suspended blue zone earns no income (`zc2:55160`); `getFilteredUpgrades` returns only the slots present in the snapshot (`zc2:48345-48364`); the zone is not eligible for advance capture (`zc2:50124`).

### Reproduction notes

This is the main performance device of the engine: with 89 zones only those near the front or near players have units in the world.
Hard parts: preserving partial losses across sleep (per-slot unit-type lists and a trim pass after respawn), keeping the same sub-zone placement, keeping radar groups alive for GCI, the many "hold" reasons that must be evaluated consistently, and the spawn queue that spreads a wake-up over several frames.
Distances come from a zone-to-zone matrix built once (`bc:buildZoneDistanceCache()`, `setup:6003`, `zc2:27596`), not from live geometry.
A field `_lastSuspendedAt` is read as a 10 s resume cooldown but is never assigned anywhere in the file (grep), so that cooldown is inert (`zc2:37842`).

## 10. The connection graph

### Mission-maker view

`bc:addConnection(from, to, drawBoth, preserveDirection)` declares an edge between two zones; Caucasus declares 135 of them (`zc2:27025-27031`, `setup:2114-2183`, count by grep).
`drawBoth = true` draws an arrow in each direction; `preserveDirection = true` keeps the arrow pointing `from → to` (`zc2:39037-39040`, `zc2:38121-38123`).
`bc:addHiddenConnection(from, to)` declares an edge that is never drawn and is only part of a second graph, `connectionMapHybridSuspend`, used by the dynamic AI filler (`zc2:27033-27039`, `zc2:27320-27322`, `setup:2252-2269`).
`bc:addConnectionSupply(from, to, method)` (Normandy only) declares supply links, optionally by `'train'`, which replace the ordinary drawing with supply arrows (`zc2:27045-27054`).
`bc:BlockGroundConvoy(a, b)` forbids ground convoys on a pair without removing the edge (`zc2:27172-27180`, `setup:2208-2211`).
Connections can be added at runtime, e.g. when an insurgency grid pops up: `bc:addConnection("Krymsk", "Insurgency Grid DL22")`, `bc:buildConnectionMap()`, `bc:RefreshConnectionsLines("Krymsk")` (`setup:1903-1905`).

### Mechanism

The graph is undirected: `connectionMap[a][b] = connectionMap[b][a] = true` (`zc2:27303-27325`).
`bc:buildConnectionMap(zoneName, previousSide)` maintains derived global tables (`zc2:27350-27535`):

- `ZONE_CONNECTED_TO_BLUE[zone]` and `ZONE_CONNECTED_BLUE_COUNT[zone]`: the zone has at least one blue neighbour (and how many);
- `ZONE_NEAR_BLUE[zone]`: a red zone with a blue zone within `NEAR_BLUE_METERS`;
- `ZONE_NEAREST_BLUE[zone]`: distance to the nearest blue zone.

Called with no argument it rebuilds everything; called with the zone whose side changed it updates the neighbours' counters incrementally (`zc2:27438-27523`).
`bc:buildZoneDistanceCache()` fills `ZONE_DISTANCES[a][b]` once for every pair with `measureDistanceZoneToZone` (`zc2:27596-27638`).

What the graph is used for inside this theme: the "has an enemy/neutral neighbour" holds of the dormancy decision (`zc2:37662-37689`), the wake-up of the neighbours of a neutral zone (`zc2:37723-37749`), `BlueIsNear` (`zc2:37149`), and the map lines.
Outside this theme it drives who may supply or attack whom (AI flights, Director).

### Reproduction notes

Adjacency is declared by hand, not derived from distance; distance is a separate matrix.
A capture updates counters in O(neighbours); a full rebuild happens only when topology changes.

## 11. Frontline

### What it computes (`Frontline.BuildFromZones`, `zc2:9183-9284`)

Input: all active, non-hidden zones with their centroid (circle centre or mean of the quad vertices, `zc2:9142-9163`).
For every red/blue pair closer than `GlobalSettings.frontlineMaxSegmentNm` (120 NM) it records, for each zone, its nearest enemy zone (`zc2:9208-9238`, `zc2:8521`).
Each zone with a nearest enemy yields one "segment" `{A, B, m = midpoint, n = unit normal pointing toward the enemy for blue / toward own side for red}` (`zc2:9260-9272`).
`distToFrontNm` of a zone is the signed projection of (zone centre − midpoint of the nearest segment) on that segment's normal (`zc2:9168-9181`, `zc2:9278-9282`).
It also stores per zone the sorted lists `sameSideNeighbors` and `enemyNeighbors` with distance and bearing; neutral and inactive zones count as "same side" (`zc2:9243-9256`, `zc2:9273-9277`).
`Frontline.ReindexZoneCalcs()` then builds a "zone awareness" table (friendly zones, enemy zones and CAP targets within 160 NM) (`zc2:9600-9612`, `zc2:9494-9530`).

There is no drawn front line; the visible "front" on the map is the territory overlay border (section 14).

### What it is used for

CAP and patrol station placement (`Frontline.PickCapStationFromOrigin`, `PickStationNearZone`, `zc2:61292-61301`, `zc2:67392-67406`), distance-to-front tests in AI group logic and in the Director (`zc2:66255`, `zc2:75771`, `zc2:76673`, `zc2:80640`), supply targeting (`zc2:54473`), AWACS station (`zc2:9618` onwards).
All of these belong to the AI themes.

### Refresh

`bc:requestFrontlineRefresh()` sets a dirty flag and schedules a single rebuild 0.15 s later, so several ownership changes in the same frame cost one rebuild (`zc2:17699-17718`).
It is requested on capture, neutralisation, disabling and un-hiding of a zone (`zc2:56684`, `zc2:55346`, `zc2:50266`, `zc2:50617`), and built once at start (`setup:6010-6011`).

## 12. Map: zone shapes and labels

### Player view

Every visible zone is drawn on the F10 map as its trigger-zone shape (circle or quad), filled and outlined in the owner's colour: red `{1,0,0,0.3}`, blue `{0,0,1,0.3}`, neutral grey `{0.7,0.7,0.7,0.3}`, disabled near-black `{0.1,0.1,0.1,0.3}` (`zc2:51392-51405`, `zc2:4345-4356`).
A blue zone from which aircraft can spawn has a green dashed outline (`zc2:51739-51742`).
A red zone's fill changes with its combat effectiveness (section 4).
A neutral zone being captured blends toward the capturer's colour (section 7).
A blue zone under ground attack gets a dashed outline that blinks red/green once per second for 60 s (blue players only) (`zc2:26879-26919`, `zc2:26857-26877`, trigger in `AIEN.lua:13656-13659`).
A text box sits at the point of largest `z` of the shape (its eastern edge, since `z` points east in DCS) and carries, for the blue label: the zone name with its waypoint number, "[WH]" for a warehouse, built/total garrison when incomplete and the lowest damaged group percentage, supply stock and repair progress lines, "Mission!" or mission tags ("Attack!", "SEAD!", "Capture!"…), warehouse low/empty/repairing/destroyed, and "Capturing: NN%" (`zc2:51419-51432`, `zc2:56098-56263`, `l10n:1373-1374`, `l10n:1388`).
Red players get their own text box with the same logic applied to their side; an enemy zone shows only its name unless zone intel is active (`zc2:56222-56224`, `zc2:56259-56262`).

### Mission-maker view

`WaypointList = { Anapa = ' (1)', … }` in the setup file gives the number appended to zone names in labels and menus (`setup:376-382`, `zc2:56098-56099`).
`PVE_Only` (Config, default false) suppresses the red label updates in PvE (`config:251`, `zc2:56097`).
`GlobalSettings.messages = { grouplost=false, captured=true, upgraded=true, repaired=true, zonelost=true, disabled=true }` switches the zone text messages (`zc2:8556-8563`).

### Mechanism

Mark ids are fixed per zone: `index = 3000 + n` for the shape, `2000 + index` for the blue text, `12000 + index` for the red text (`zc2:26798`, `zc2:51732-51733`).
Shape: `trigger.action.circleToAll(-1, id, point, radius, border, fill, 1)` or `trigger.action.quadToAll(-1, id, v4, v3, v2, v1, border, fill, 1)` (`zc2:4348-4353`).
Texts: `trigger.action.textToAll(coalition, id, point, textColor, {0.7,0.7,0.7,0.8}, 17, true, text)` once at init, one per coalition (`zc2:51731-51733`).
Afterwards nothing is redrawn: ownership changes use `trigger.action.setMarkupColor` / `setMarkupColorFill` / `setMarkupTypeLine` on the existing ids, and text changes use `trigger.action.setMarkupText(labelId, msg)` (`zc2:56655-56658`, `zc2:56751-56752`, `zc2:56263`).
`ZoneCommander:updateLabel(side)` rebuilds the whole text for one coalition and is called from every state change: capture, neutralisation, upgrade/repair, suspend/resume, pending-capture tick (every second), warehouse change, mission tag change (`zc2:56076`, `zc2:56804`, `zc2:55407`, `zc2:56975`, `zc2:48076`, `zc2:46775`).
Hidden zones have no marks (`zc2:51411-51417`, `zc2:56086`); a disabled zone's shape and red label are removed and its blue label emptied (`zc2:56087-56096`).
The attack flash is a separate mark (`UTILS.GetMarkID()`), toggled by one shared 1 Hz `timer.scheduleFunction` that stops itself when no flash is left (`zc2:26897-26917`, `zc2:26857-26877`).

### Reproduction notes

Fixed ids plus in-place `setMarkup*` calls avoid the remove/re-add flicker and the cost of redrawing 89 shapes.
The label text is recomputed from scratch on each call and there is no throttle in `updateLabel` itself; throttling is in the callers (10 s zone tick, 1 s capture tick).
`UTILS._MarkID` is bumped above the reserved ids at `addZone` so that Moose-allocated ids never collide (`zc2:26799`).

## 13. Map: connection lines and supply arrows

### Player view and settings

Each declared connection is drawn between the edges of the two zone shapes.
`ConnectionMapStyle = "line"` (Config default; `"arrow"` is the other value) and `ConnectionMapColor = "dynamic"` (or `"white"`) (`config:402-411`, `zc2:38010-38031`).
Dynamic colour: blue when the origin is blue and the destination is not red, red when the origin is red and the destination is not blue, white otherwise (i.e. across the front or between neutrals) (`zc2:38024-38030`).
In line mode: `trigger.action.lineToAll(-1, id, head, tail, color(alpha 0.85), 4, true)`; in arrow mode: `trigger.action.arrowToAll(-1, id, head, tail, {0,0,0,0.5}, color(alpha 0.5), 0.5)` (`zc2:39012-39023`).
Arrow direction: toward the red zone on a blue/red pair; otherwise as declared, reversed when the campaign was started with `StartNormal == false` unless the target name contains "sam"/"defence" or `preserveDirection` is set (`zc2:38096-38126`).
A connection touching a disabled zone is not drawn (`zc2:39008`).

### Mechanism

End points are computed by `GetConnectionEdgePoint`: centre + radius along the bearing for circles, ray/edge intersection for quads (`zc2:38033-38094`).
`DrawConnectionLines()` removes all connection marks and redraws them all; it runs once 0.1 s after init (`zc2:38985-39046`, `zc2:30269-30276`).
`RefreshConnectionsLines(zoneName)` removes and redraws only the connections that touch one zone, using the map `ConnectionArrowIds["from=>to"]` (`zc2:39048-39110`); called on capture, neutralisation, disabling, repair and un-hiding (`zc2:56675`, `zc2:55351`, `zc2:50262`, `zc2:56969`, `zc2:50605`).
Normandy supply mode: `drawSupplyArrows()` redraws all supply arrows (a train link is skipped when its train group is dead), debounced to one redraw per 60 s by `drawSupplyArrowsDebounced` (`zc2:38192-38292`).

## 14. Map: territory overlays

### Player view

The map is tinted by ownership: each visible zone owns the part of the map closer to it than to any other zone, filled with a translucent colour (red for enemy, green for friendly, white for neutral), and the border between cells of different owners is drawn as a thick line.

### Settings (globals with engine defaults, `zc2:8539-8553`)

`ShowEnemyTerritoryOverlay = true`, `EnemyTerritoryOverlayColor = {1,0,0}`, `EnemyTerritoryOverlayBorderAlpha = 18`, `EnemyTerritoryOverlayFillAlpha = 0.12`, `EnemyTerritoryOverlayBoundsMargin = 70000` (m), `ShowFriendlyTerritoryOverlay = true`, `FriendlyTerritoryOverlayColor = {0,0.8,0}` (alpha 18 / 0.12), `ShowNeutralTerritoryOverlay = true`, `NeutralTerritoryOverlayColor = {1,1,1}` (border 0, fill 0.10), `TerritoryOverlayFrontierOnlyBorders = true`, `TerritoryOverlayOuterDrawPushMeters = 0`.

### Mechanism

It is a Voronoi diagram computed by half-plane clipping.
Sites: the centre of each active, non-hidden zone; a carrier zone may instead contribute several sites named `<Zone>-<n>-edge`, and carrier navigation areas add virtual sites (`zc2:39518-39573`, `zc2:1445-1494`).
Bounds: the bounding box of all sites enlarged by the margin (`zc2:39637` onwards).
Cell of a zone: start from the bounds polygon and clip it successively against the perpendicular bisector with every other site, nearest first (Sutherland–Hodgman against one half-plane); cells under 1000 m² are dropped (`zc2:39751-39779`, `zc2:39233-39275`).
For each cell the set of sites that actually clipped it (`impacts`) is remembered, and the reverse index `_territoryOverlayAffectedBy` (`zc2:39759-39768`, `zc2:39899` onwards).
Drawing: `ZONE_ELASTIC:New(name, polygon):DrawZone(-1, color, borderAlpha, color, fillAlpha, 1, true)` (`zc2:39790-39803`); in Moose, `ZONE_POLYGON_BASE:DrawZone` triangulates the polygon and fills each triangle as its own map mark, then draws border lines (`Moose_2026-10-11.lua:11635-11700`).
The triangulation is done once in `ZONE_POLYGON_BASE:New` by ear clipping: the vertex list is forced clockwise, then recursively the first clockwise corner that contains no other vertex is cut off as a triangle until three points remain, giving n − 2 triangles for an n-gon (`Moose_2026-10-11.lua:11449-11521`).
Each triangle is filled by `_ZONE_TRIANGLE:Fill` → `COORDINATE:MarkupToAllFreeForm({p2, p3}, coalition, nil, nil, fillColor, fillAlpha, 0, nil)`, which ends in `trigger.action.markupToAll(7, coalition, markId, v1, v2, v3, lineColor, fillColor, lineType, readOnly, "")` — shape id 7 is the free-form polygon, here with three vertices, line type 0 (no outline) and a fresh `UTILS.GetMarkID()` per triangle (`Moose_2026-10-11.lua:11419-11425`, `Moose_2026-10-11.lua:19268-19287`).
The border is one `trigger.action.lineToAll` mark per polygon edge (`COORDINATE:LineToAll`) (`Moose_2026-10-11.lua:11682-11705`).
All ids are kept in the zone object's `DrawID` list and removed one by one (`UTILS.RemoveMark`) by `UndrawZone` when a cell is rebuilt (`Moose_2026-10-11.lua:10581-10595`, `zc2:39390`, `zc2:39405`).
With `TerritoryOverlayFrontierOnlyBorders`, cell borders are suppressed and only edges shared with a cell of a different owner are drawn, each as a 250 m wide quad (`trigger.action.quadToAll`) (`zc2:39794-39796`, `zc2:39805-39897`).
A side's overlay is shown only if another side still exists on the map (`_territoryHasOpposition`) (`zc2:39781-39788`).

### Redraw and throttling

`RefreshTerritoryOverlays(force)` computes a state key (config values + name/side/active/hidden of every zone) and does nothing when it is unchanged; otherwise it clears and rebuilds everything (`zc2:40157-40182`, `zc2:39443-39472`).
`RefreshTerritoryOverlayZone(zoneName)` is the incremental path used on every ownership change: a side change with unchanged visibility only recolours that cell; a zone appearing or disappearing rebuilds that cell plus the cells it impacts; frontier segments are rebuilt only for the dirty set; anything unusual (bounds changed, config changed, carrier zone) falls back to the full rebuild (`zc2:40184-40310`).
Called at init, 0.1 s after init, and from capture, neutralisation, disabling and un-hiding (`zc2:30268-30276`, `zc2:56674`, `zc2:55350`, `zc2:50261`, `zc2:50604`).

### Reproduction notes

The geometry is plain Lua and self-contained; the only Moose dependency is the polygon fill (`ZONE_ELASTIC`), i.e. triangulation of a convex polygon and one mark per triangle.
The number of map marks is large (triangles per cell plus frontier quads), which is why the incremental path exists.

## 15. Hidden zones, pop-up zones and scripted zone events

- A hidden zone (`isHidden` or "hidden" in the name) is a full zone without any map presence: it holds garrison groups the mission maker wants managed and persisted, e.g. `HiddenBlueEWR`, or reserve forces `Hidden1…8` (`setup:851-865`).
- `SpawnFriendlyAssets(changedZone)` is a setup-file function called 2 s after every capture/neutralisation/disable; in Caucasus it turns hidden reserve zones red and upgrades them (`MakeZoneRedAndUpgrade`) when exactly one of two named zones is blue, destroys them (`DestroyHiddenZone`) when both are blue, and wakes insurgency grids (`setup:1851-1940`, `zc2:56642-56644`).
- `MakeZoneRedAndUpgrade()` captures a neutral-at-start zone for red silently and upgrades it one slot every 2 s until full (`zc2:50494-50522`).
- `MakeZoneBlue()` destroys every red unit inside the zone and captures it for blue 12 s later (`zc2:50470-50491`).
- Pop-up zones (`Popup = true`, `NeutralAtStart = true`): `normalizePopupAwakenState` keeps them hidden, neutral and inert until `isAwaken`; `AwakenZone()` un-hides the zone, draws its shape and labels for the first time, rebuilds connections, overlay, menus and frontline; `AwakenZoneAndUpgrade()` also makes it red and fills it (`zc2:44581-44598`, `zc2:50543-50631`, `setup:831-834`).
- The Caucasus insurgency grids are pop-up zones woken when a given zone turns blue, announced with a text and `WarningSound.ogg`, connected to the map at that moment, and disabled for good with a 500-credit reward when lost (`setup:1896-1905`, `setup:2725-2729`).
- `income` zones (factories, depots) pay their owner at each 10 s tick (`setup:826-830`, `zc2:55157-55167`).

## 16. F10 radio menu "Intel & Zone status" and the zone status message

### Player view

Per-group menu `Intel & Zone status` → `Red Side` / `Blue Side` → one command per visible, awake (or idle-suspended) zone, labelled "<zone> (<waypoint n>)", sorted by waypoint number descending then by name, paged by 9 under nested `More` sub-menus (`zc2:40326-40467`, `l10n:160-170`).
Selecting a zone prints for 15 s (to the group): "<zone> status", "Controlled by <side>", remaining intel minutes, "upgrades n/total", the list of garrison groups with health % (size / initial size), the flavour text, "irreparably damaged" for a disabled zone, and the zone centre in DDM, DMS, MGRS plus elevation in m and ft (`zc2:50274-50465`).
For an enemy zone the garrison list is shown only while zone intel or JTAC intel is active; otherwise the text says to buy intel or a JTAC (`zc2:50313-50367`).
The same root menu hosts the intel/mission sub-menu of the mission commander (other theme) (`zc2:40333-40342`).

### Mechanism

Menus are created with raw `missionCommands.addSubMenuForGroup` / `addCommandForGroup`; the command callback is `ZoneCommander.displayStatus` with arguments `(zone, groupId, 15, false, viewerSide)` (`zc2:40423-40457`).
A per-group cache of the rows `{zone, handler, label}` lets the builder skip a side's sub-menu when nothing changed; otherwise the whole side sub-menu is removed and rebuilt (`zc2:40317-40324`, `zc2:40408-40466`).
`bc:requestZoneStatusMenuRefresh(groupId, intelOnly)` only sets flags and schedules a flush 0.15 s later; the flush queues every group that has the menu and a worker rebuilds **one group per 0.1 s**, sharing the sorted zone lists across groups of the same pass (`zc2:17272-17317`, `zc2:40469-40499`).
Requested on capture, neutralisation, disable, suspend/resume changes and proximity wakes (`zc2:56618`, `zc2:55345`, `zc2:50264`, `zc2:37975`, `zc2:37161`).

### Reproduction notes

DCS has no "update menu item" call, so a changed list means remove-and-recreate; the row cache and the one-group-per-tick worker are what keep this affordable with many player groups.
The health percentage is group size over initial size, not unit life.

## 17. Admin F10 map-marker commands that act on zones

Handled in the mark-change handler (`event.id == 26`, coalition 1 or 2) of `startMonitorPlayerMarkers` (`zc2:28455-28456`); the admin gating and alias mechanism (`adminAliases`) belong to another theme.
Zone-related commands, each acting on the zone under the marker (`bc:getZoneOfPoint(event.pos)`):

| Marker text (default / alias action) | Effect | Code |
|---|---|---|
| `capture:1`, `capture:2` | `zone:capture(side)` (only if neutral) | `zc2:29172-29184` |
| `blå` / `captureNeutralBlue`, `röd` / `captureNeutralRed` | capture for blue / red | `zc2:29185-29202` |
| `upgradera` / `upgradeZone` | one upgrade step | `zc2:29137` |
| `maxxa` / `fullyUpgradeZone` | `MakeZoneSideAndUpgraded()` | `zc2:29164-29171` |
| `recapture` | `RecaptureBlueZone()` | `zc2:29149-29156` |
| `rensa` / `clearZone` | `zone:killAll()` then `update()` → the zone becomes neutral | `zc2:28886-28895` |
| `upgradeallred`, `upgradeallblue` | upgrade every zone of a side | `zc2:28794-28803` |
| `whynot` | explains the suspend decision of the zone | `zc2:28918-28922` |
| `givemesupplies` | adds 3 expedited supply stock to the zone | `zc2:29157-29163` |
| `status` | The zone status message of section 16 for the zone under the marker, 60 s to the author's group (30 s to the coalition when the mark has no initiator, followed by the zone's local recovery detail if it is friendly); outside any zone the author is told the command needs a zone. | `zc2:28810-28832` |

## 18. Campaign win and lose conditions

### Player view

PvE win: when no visible zone is red any more, everybody reads "Enemy has been defeated. Mission Complete." and blue hears `BH.ogg` 2 s later (`setup:2779-2795`, `l10n:2061-2062`).
With `AutoRestart` the text ends with "Restarting now.." and the mission ends 5 s later; without it a coalition menu `Restart and Reset?` → `Yes` / `No` is added for blue (`setup:2797-2826`, `l10n:167`).
PvE defeat: when no visible zone is blue any more, "Mission failed, Server restarting..." and an unconditional reset and restart (`setup:2768-2811`).
PvP: the side that owns all "victory zones" wins, with "<side> coalition wins!" (`setup:2736-2775`, `setup:2833`).

### Mechanism

`checkMissionComplete(event, sender)` is registered as a zone trigger with id `missioncompleted` on events `lost` and `destroyed` of every zone (and `captured` in PvP on the victory zones), and is also called once from a start-up timer after the save has been applied (`setup:2834-2849`).
PvE: it scans `bc:getZones()`, ignoring zones whose name contains "hidden"; `done` = no zone with `side == 1`; `missionFailed` = no zone with `side == 2`, considered only once the start-up call has set `missionCheckReady` (`setup:2776-2790`).
On completion: `missionCompleted = true`; user flag 180 is set (it mutes other mission sounds and messages across the setup file, e.g. `setup:6202`, and the "ding" on zone loss, `zc2:55374`); the save is wiped by writing an empty `zonePersistance` table and calling `resetSaveFileAndFarp()` when present; `bc._persistenceResetPending = true`; 5 s later user flag 181 is set (`setup:2791-2808`).
Flag 181 is the "end mission" flag: the engine sets it from admin restart commands too (`zc2:28126`, `zc2:28139`, `zc2:29243`), and the `.miz` holds one trigger whose condition is `c_flag_is_true("181")` and whose action is `a_end_mission("blue", …)` (`mission` file of `Foothold_CA_6.5.2_Coldwar-Modern-Vietnam.miz`, trigger 7).
The `missioncompleted` trigger id is explicitly excluded from the "zone disappears when lost" detection (`zc2:50066`, `zc2:50091`).
An admin marker `AvslutaFoothold` / `endMission` calls `forceMissionComplete()` if defined (`zc2:28911-28917`).

### Reproduction notes

The win test is evaluated only on zone events, not on a timer, plus once at start.
"Hidden" zones are excluded by name, so a hidden red reserve does not block victory.
The reset is "write an empty save, then end the mission"; the server is expected to reload the same mission.

## Seen outside this theme

- Regular supply stock, supply efficiency, local recovery (repair/rebuild) jobs and their label lines: `zc2:52059-54106` (logistics theme).
- Warehouse facility static per zone (`_initWarehouseFacility`, `_updateWarehouseFacility`), weapon stock policy: `zc2:46108-46584`, `zc2:51151-51356`.
- AI `GroupCommander` FSM, supply landing/convoy arrival code that feeds capture: `zc2:67800-67850`, `zc2:69925-70120`.
- Director reactions to ownership changes (`recordZoneOwnershipChange`, captured-zone CAS diversion): `zc2:84482-84736`.
- Shop items "capture", "advance capture" and target-zone selector menus: `setup:4639-4746`, `zc2:22553-22620`, `zc2:34146-34329`.
- CTLD zone activation on ownership change (`addCTLDZonesForBlueControlled`), troop/crate capture handlers: `ctld:5300-5350`, `ctld:9245-9290`.
- Zone intel (what the enemy label and status reveal): `_zoneIntelIsActive`, `zc2:5746-6668`.
- Dynamic difficulty (`increaseDifficulty` on zone loss, `_rebalanceRedDifficulty`): `zc2:19253-19260`, `zc2:37031`.
- Carrier navigation areas drawn on the map and their suspend links: `zc2:14200-14344`, `zc2:27056-27167`.
- Dynamic tanker racetrack drawings: `zc2:105815-105965`.
- Admin marker commands in general, `-code:` remote Lua execution from a marker: `zc2:28455-29242`, `zc2:29203-29205`.
- Persistence of zones (suspended snapshots, pending captures, retired statics): `zc2:1169-1204`, `zc2:47127-47298`, `zc2:44601`.
- SAM "hidden on MFD" reveal logic: `zc2:47696-47728`.
- AIEN ground-AI reactions that raise the "zone under attack" message and flash: `AIEN.lua:13640-13662`.
- Player-state export (`bc.playersState`) refreshed in the proximity loop: `zc2:37090-37097`.

