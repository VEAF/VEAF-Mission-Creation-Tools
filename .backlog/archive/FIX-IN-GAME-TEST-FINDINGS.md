# FIX-IN-GAME-TEST-FINDINGS — what the first in-game test of an MCP-built mission found

Status: ✅ done — all five tickets fixed 2026-09-29; verified in game 2026-10-03 (R17) except ticket 03's case of an unguided weapon near a sanctuary, which was not flown — covered by unit tests only · archived 2026-11-24

## Origin

On the evening of 2026-09-28 David loaded `VEAF-Open-Training-Mission-GermanyCW-v6`, built with
`veaf-tools` from `develop` at `5c6f8fec`, as game master in single player, with the dcs-bridge
trigger injected. An agent measured it through `/api/exec` and `dcs.log`, activating combat
zones one by one. It was the first time a mission authored from scratch with the
`veaf-mission-mcp` actions was run in DCS rather than checked in its files.

Most of it held: sanctuaries, carrier operations, CTLD logistic points, draw tags, laser drones.
Two defects did not, and neither can be seen in the mission files. Three more showed once the mission
ran on the private1 server with several players.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| [01](FIX-IN-GAME-TEST-FINDINGS.md) | A static placed by `add_group` / `create_combat_zone` carries no `shape_name`, and DCS refuses some types without one | 4 of the mission's objectives never existed: `unknown static shape_name, category Fortification, type: .Command Center` (and `.Ammunition depot`) at mission load |
| [02](FIX-IN-GAME-TEST-FINDINGS.md) | Every combat zone is initialized twice | each zone's startup lines logged twice; Torgau reports « 8 element(s) » for 4 |
| [03](FIX-IN-GAME-TEST-FINDINGS.md) | The sanctuary's weapon check raises on a weapon with no target, or already gone | on private1: `…:58320: attempt to index local 'target'` after a CBU-105 and two AGM-88C, `…:58303: Weapon doesn't exist` after an AI 57 mm round |
| [04](FIX-IN-GAME-TEST-FINDINGS.md) | Every scaffolded mission starts with CTLD's sample `extract` and `logistic` names | 25 + 10 « not found » warnings at start; none of the names exists |
| [05](FIX-IN-GAME-TEST-FINDINGS.md) | `veafNamedPoints` has no cities for GermanyCW, nor the other recent theatres | `no cities in veafNamedPoints for theatre GermanyCW`; six theatres have a list |

01 is the one players meet: a strike zone whose main target is absent, with nothing in the
mission, the build or the validation to say so.

## One lot, one PR

01 lives in `veaf_mission_mcp` and the unit data, 02 in the combat-zone runtime or its generator, 03
in the sanctuary runtime, 04 in `ctld_config.py`, 05 in `veafNamedPoints` and its data.

## Out of scope

- The drones' height: CTLD re-routes a JTAC drone to `JTAC_droneAltitude` (3 000 m AGL) whatever
  the mission says. That is CTLD doing what its setting asks; the mission's texts were corrected.

## Definition of Done

- The five tickets closed; the GermanyCW-v6 statics placed by the MCP spawn in DCS without the
  hand-written `shape_name` the mission now carries.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

GermanyCW-v6 from `develop`, the four shapes rewritten by `repair_static_shapes`: no
`unknown static shape_name`, one initialisation of Torgau, Torgau activating with 6 elements (the six
groups the mission now declares), no script error. The unguided weapon near a sanctuary was not run.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**what the first in-game test of an MCP-built mission found.** Opened 2026-09-28 on GermanyCW-v6: statics placed without a `shape_name`, which DCS refuses for some types (four objectives never existed), every combat zone initialized twice, the sanctuary's weapon check raising on a weapon with no target or already gone, CTLD's sample `extract` / `logistic` names in every mission, and no cities for GermanyCW. All five fixed 2026-09-29; the in-game reading is R17 of `DCS-SESSION-TODO.md`

## Tickets, in full

## 01 — Statics placed without a `shape_name`, some of which DCS refuses

Status: ✅ done — 2026-09-29
Type: fix + data
Files: `src/python/veaf-tools/veaf_mission_mcp/add_group.py` (`_build_static_group`), the unit data
(`veaf_libs/data/dcsUnits.yaml`, `update-dcs-data`), `validate_mission`, tests

### Origin

In-game test of GermanyCW-v6, 2026-09-28. Wünsdorf's command centre did not spawn when its zone was
activated; it was not even one of the zone's elements.

### Measured

- At mission load, `dcs.log`:
  `ERROR APP (Main): unknown static shape_name, category Fortification, type: .Command Center` and
  the same for `category Warehouse, type: .Ammunition depot`. DCS does not create the object; the
  combat zone never sees it.
- Four objectives affected in the mission, all placed by the MCP on 2026-09-24: Wünsdorf's
  `.Command Center`, Torgau's two and Wittenberg's one `.Ammunition depot`. Torgau's draw
  (`#spawncount=4` of 5) had only 3 elements to draw from.
- The other static types seen spawning in game did so without a `shape_name` (Warehouse, Bunker,
  Barracks 2, Fuel tank, Tank, MiG-29S and Su-27 statics), so DCS resolves many types itself — not all.
  Only these two types were refused at load (`dcs.log` logs one line per refused type).
- `_build_static_group` writes type, name and `category`, never `shape_name`; only `add_farp`
  writes one (`_SHAPES`, per heliport type).
- `dcsUnits.yaml` has no shape name for these types. VEAF's own spawner has the table:
  `veafDcsSpawner.lua` (`[".Command Center"] = "ComCenter"`, `[".Ammunition depot"] = "SkladC"`,
  about a hundred more), and `mist.lua` carries the same pairs.

Worked around in the mission by writing `ComCenter` / `SkladC` on the four statics.

### Done when

- The unit data carries each static type's `shape_name` (captured by `update-dcs-data`, or taken
  from the same source the spawner uses — one source, not a second copy of the table).
- `add_group` (category `static`) and `create_combat_zone` write it.
- `validate_mission` warns on an existing static whose type needs a `shape_name` and has none, so
  the missions already built are caught.
- Tests; the four GermanyCW-v6 statics rebuilt through the action carry the shape without the
  mission's workaround.

### Done — 2026-09-29

- The datamine carries `ShapeName` on the statics' files (228 fortifications, 5 warehouses, 24
  cargos…); `veaf_build/dcs_data/units.py` reads it for kind `static` only, and `dcsUnits.yaml`
  gains `shape_name` on 278 types (`ComCenter`, `SkladC`, `Tank` → `bak`). One source: the spawner's
  table and the YAML now come from the same DCS files, and the YAML is CI-guarded.
- `veaf_libs.dcs_units_data.get_unit_shape_name`; `_build_static_group` writes it, which covers
  `add_group` and `create_combat_zone` (both go through `insert_group_into_content`).
- `validate` warns, one line per unit, on a static without its shape
  (`validate.static_without_shape`, catalogued in `build-messages/missing-references`). Not in
  the build's end summary, whose header counts missing `mission.yaml` references.
- A `known-limitations.yaml` entry (`static-without-shape-name-is-refused`, kind `dcs`).
- Not done here: rebuilding the four GermanyCW-v6 statics through the action. That is R17.

## 02 — Every combat zone is initialized twice

Status: ✅ done — 2026-09-29
Type: fix
Files: `src/scripts/veaf/veafCombatZone.lua` and/or `src/python/veaf-tools/veaf_libs/lua_config_generator.py`,
tests (Lua and generator)

### Origin

In-game test of GermanyCW-v6, 2026-09-28, with `veaf.Diagnostics = true`.

### Measured

- Each zone's startup lines appear twice in `dcs.log`, a few milliseconds apart:
  `reportGroupsExcludedByName` and `DIAG|zone combatZone_Torgau: deactivated, destroying 0
  group(s)` alike, for all 26 zones.
- Torgau, activated in game: `DIAG|zone combatZone_Torgau: activating (8 element(s), …)` for 4 real
  elements; Wünsdorf's element list, read through the bridge, holds each of its 7 elements twice.
- No double spawn was seen (counts came out right: Baumholder 3 of 5, Parchim 5 of 7), so the
  harm is noise in the log and doubled work at start — but a draw over doubled elements is one
  change away from spawning twice.

### Where it comes from

- The generated `veaf-config.lua` ends each zone's builder chain with `:initialize()`
  (`lua_config_generator.py`, 26 times in this mission).
- `veafCombatZone.AddZone(zone)` then calls `zone:initialize()` again (`veafCombatZone.lua:2821`).
- `VeafCombatZone:initialize()` sets `self.initialized = true` on entry and never returns early
  when it is already set.

### Done when

- A zone is initialized once: either the generator stops emitting `:initialize()`, or
  `initialize()` returns when already initialized — decided and written, with the other callers
  of `AddZone` (hand-written `mission-script.lua` in older missions) in mind.
- A test builds a zone through the generated chain and `AddZone`, and counts one initialization and
  unique elements.

### Done — 2026-09-29

Decided: `VeafCombatZone:initialize()` returns when the zone is already initialized. The generator
keeps its `:initialize()`: the hand-written `mission-script.lua` of older missions do the same, and
so does `VeafCombatOperation:initialize()` for its tasking zones, so only a guard in the runtime
covers every caller. `VeafCombatOperation:initialize()` gets the same guard (it deactivated
twice). Tests: the generated chain plus `AddZone` reports once, for a zone and for an operation
(red before: 2 each).

## 03 — The sanctuary's weapon check raises on a weapon with no target, or already gone

Status: ✅ done — 2026-09-29
Type: fix
Files: `src/scripts/veaf/veafSanctuary.lua` (`VeafSanctuaryZone:handleWeapon`), Lua tests

### Origin

GermanyCW-v6 on the private1 server, 2026-09-28 evening, `protect_from_missiles: true` on its four
sanctuaries; `dcs.log` watched while several players flew it.

### Measured

- Every `S_EVENT_SHOT`, from anyone, schedules `handleWeapon` in **every** sanctuary zone,
  `DESTROY_WEAPONS_AFTER` (2 s) later (`veafSanctuary.lua:813`).
- 19:52:14, 2 s after David's A-10 released a CBU-105:
  `VEAF-SCHEDULER|E|6393: error in scheduled function: … veaf-scripts.lua"]:58320: attempt to index
  local 'target' (a nil value)`. Again at 19:53:03 and 19:53:06, each 2 s after an AGM-88C fired by
  one of two other players' F-16Cs. Source line 602: `Unit.getByName(target:getName())`, right after
  `local target = weapon:getTarget()` (601). `getTarget()` returned `nil` for those weapons — presumably released
  with no target object designated (a CBU-105 on coordinates, a HARM with no lock: not checked); the check assumes a target whenever
  the shooter is a human of the other coalition, which any blue pilot is for the three red
  sanctuaries.
- 20:18:53: `…:58303: Weapon doesn't exist`, 2 s after a 57 mm round from an AI S-60. Source line
  585: `weapon:getLauncher()` is called before anything checks the weapon still exists, and before
  the "is the shooter a human" test — so AI fire raises it too, whenever the weapon is gone after
  two seconds.
- The code dates from 2021 (`cace38a7`); any mission with `protect_from_missiles` has been logging
  these. Nothing is lost in play — a weapon with no target threatens no defender, and one already
  gone cannot be destroyed — but each shot can raise one error per sanctuary, which buries real
  errors in the log: the GermanyCW watch had to exclude both lines to stay readable.

### Done when

- `handleWeapon` returns quietly when the weapon no longer exists (`weapon:isExist()`) and when
  `getTarget()` is `nil`.
- Lua tests for both cases, and for the guided case still reaching the in-zone check.

### Done — 2026-09-29

`handleWeapon` returns when `weapon:isExist()` is false (before `getLauncher`), when `getTarget()`
is `nil`, and when the target no longer exists — the last one not measured, the same failure one
step further. Four Lua tests; the two measured errors reproduced word for word before the fix.

## 04 — Every scaffolded mission starts with CTLD's sample `extract` and `logistic` names

Status: ✅ done — 2026-09-29
Type: fix (chore)
Files: `src/python/veaf-tools/veaf_libs/ctld_config.py` (`VEAF_CONFIG_OVERRIDES`,
`apply_veaf_overrides`, `merge_veaf_logistics`), tests

### Origin

private1's `dcs.log`, GermanyCW-v6, 2026-09-28. `FEAT-CTLD-AIRBASE-LOGISTICS` already recorded the
`logistic` half as out of scope, "it wants a chore of its own"; nobody opened it, and the `extract`
half was not mentioned.

### Measured

- At mission start: 25 × `CTLDCoreManager: INIT-E - extractableGroup 'extract#' not found, skipped`
  and 10 × `CTLDZoneManager: logisticUnits 'logistic#' not found in mission`.
- The names come from CTLD's own catalogue (`CTLD.lua`, `extractableGroups: extract1 … extract25`
  and `logisticUnits: logistic1 … logistic10`), which `ctld_config.py` copies whole into a new
  mission's `ctld-config.yaml`; `VEAF_CONFIG_OVERRIDES` touches neither list. No VEAF mission names
  a group `extract1` or a unit `logistic1`.
- CTLD reads the snapshot with no merge ("a missing list is an intentional removal"), so an empty
  list in the mission is honoured. Its YAML parser reads `[]` as an empty table
  (`CTLDConfig.scalar`) but does **not** strip a trailing comment: `key: []   # note` is read as the
  string `"[]   # note"`. Measured on GermanyCW-v6 by running the parser on the generated
  `CTLD_userConfig.lua`.

Worked around in the mission by emptying both lists, the comment on its own line.

### Done when

- A scaffolded mission gets `extractableGroups: []` and `logisticUnits: []`, through the VEAF
  overrides, without disturbing what `merge_veaf_logistics` adds when `manage_logistics` is on.
- No comment written by the tools ever sits at the end of a value line in `ctld-config.yaml`.
- `validate_mission` warns on an `extractableGroups` / `logisticUnits` name the mission does not
  hold, so existing missions are caught.
- Tests.

### Done — 2026-09-29

- `ctld_config.VEAF_EMPTIED_LISTS`, applied by `apply_veaf_overrides` only: kept apart from
  `VEAF_CONFIG_OVERRIDES` because the build **merges** that one into a mission's lists, and a
  maker's own `extractableGroups` must survive. Tested against the vendored `CTLD.lua`, through the
  scaffold and the build's merge.
- The tools write no comment into `ctld-config.yaml`: the `[] # note` read as a string came from
  the hand-written workaround. The test asserts no `#` on either line.
- `validate` warns on a name in either list that the mission holds as neither a group nor a unit
  (`validate.ctld_name_not_in_mission`, catalogued in `build-messages/modules`).

## 05 — `veafNamedPoints` has no cities for GermanyCW, nor for the other recent theatres

Status: ✅ done — 2026-09-29
Type: fix + data
Files: `src/scripts/veaf/veafNamedPoints.lua` (`addCities`, the `_cities*` tables), the tool that
produces them, tests

### Origin

private1's `dcs.log`, GermanyCW-v6, 2026-09-28:
`VEAF|W|addCities|…: no cities in veafNamedPoints for theatre GermanyCW`.

### Measured

- `veafNamedPoints.addCities()` knows six theatres: Caucasus, Persian Gulf, The Channel, Syria,
  Mariana Islands, Falklands (`_citiesCaucasus` … `_citiesFalklands`). Any other theatre gets an
  empty list and that warning — GermanyCW here; Sinai, Kola, Afghanistan, Iraq and Normandy are
  not in the list either, and VEAF runs missions on several of them.
- The cities are added as **hidden** named points (`point.hidden = true`). Which features look
  them up — marker commands taking a place name, the named-points radio menu, the interpreter —
  is **not checked** yet; that is what says how much a mission on these theatres loses.

### Done when

- What uses the city points is established and written here.
- Each theatre VEAF supports has a city list, produced from one source (DCS's own terrain town
  data, or whatever produced the six existing lists), not typed by hand.
- The warning names the theatre and says what will not work without cities.

### Done — 2026-09-29

**What uses the city points** (hidden, so not in the named-points list): `getPoint` by name — a
shortcut's position (`-sa6 Kutaisi`), a convoy's destination (`veafSpawnGround`, `veaf.lua`), a
transport mission's start — and `getNearestPoint`, behind the weather at the closest point. Without
cities, a town name does none of this and the weather only knows the airbases; the warning now says
so.

**One source.** `veaf-build update-dcs-data --cities --dcs-path <install>` reads each terrain's
`Map/towns.lua` under the name its `entry.lua` declares (`self_ID`), merges into
`veaf_build/dcs_data/cities.yaml` (a theatre the install lacks is kept), and renders
`src/scripts/veaf/veafCities.lua`; the 5 277 typed lines left `veafNamedPoints.lua`. Run on
DAVID-BUREAU's install and on the server's (`dcs.veaf.org`, read-only copy of three terrains):

| Theatre | Before | Now |
|---|---:|---:|
| Afghanistan | — | 1 197 |
| Caucasus | 1 691 | 1 691 |
| Falklands | 1 323 | 1 323 (carried: no reachable install has it) |
| GermanyCW | — | 127 |
| MarianaIslands | 67 | 77 |
| MarianaIslandsWWII | — | 22 |
| Normandy | — | 1 282 |
| PersianGulf | 385 | 385 |
| SinaiMap | — | 703 |
| Syria | 213 | 1 151 |
| TheChannel | 1 311 | 1 311 |

No town of the old lists was lost. **Kola and Iraq** are installed nowhere reachable and have no list
yet: the next run on an install that has them fills them.
