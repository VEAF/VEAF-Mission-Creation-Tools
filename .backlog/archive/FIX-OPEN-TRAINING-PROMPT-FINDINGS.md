# FIX-OPEN-TRAINING-PROMPT-FINDINGS — what applying the 28/09 Open Training prompt to a mission found

Status: ✅ done — opened and closed 2026-09-28, PR #1022. · archived 2026-10-02

## Origin

On 2026-09-28 the Open Training prompt gained the rules learnt from the hand-made Caucasus v5
Open Training (`4fdb8ab6`): a player-versus-player arena and sanctuaries, a carrier group, laser
drones, a non-combat helicopter zone with radio beacons, draw tags on the zones. An agent applied
them to `VEAF-Open-Training-Mission-GermanyCW-v6` the same day
(VEAF/VEAF-Open-Training-Mission-GermanyCW-v6#1), with the `veaf-mission-mcp` actions of
`develop` and `veaf-tools` 6.25.0.3.

Several pieces had no action and were written by script on the Lua table, as the prompt tells the
agent to do and to report. This lot is that report. Every figure was measured on that mission or
on `develop` at `8bc1a1fe`.

## The findings

| # | Defect | Measured |
|---|--------|----------|
| 01 | `add_air_group` and `add_player_slot` build aircraft with no chaff, no flare, no callsign, and tail numbers that repeat from one group to the next | `aircraft_payload.py:48` writes `"flare": 0, "chaff": 0`; 92 arena slots fixed by script |
| 02 | Nothing places a working carrier: no ATC tasks on a ship, no deck slot, no ship warehouse | the CSG-74 Stennis group, 6 deck slots and its warehouse copied from the Caucasus v5 by script |
| 03 | The build opens a carrier's deck to every dynamic template of its side | 51 types on the Stennis, B-52H and CH-47 included; the unit data has no carrier-capability field |
| 04 | No action makes a unit transmit a sound, or embeds the sound in the mission | three beacons and an SOS copied from the v5 "Mountain Hike", `mapResource` written by hand |
| 05 | The mission is named by five different parameters across the catalogue | 42 of 47 actions: `miz_path` 17, `target` 9, `mission_yaml_path` 6, `folder_path` 6, `mission_path` 4 |
| 06 | The prompt says sanctuary vertices are late-activated units; nobody has checked DCS gives their position | `veaf.getPolygonFromUnits` reads `Unit.getByName(...):getPosition()`; the v5 used active ships |

Tickets 01 and 02 change what players fly: 01 puts pilots in a fight with no countermeasures, 02
is a whole feature the prompt asks for and the tools cannot build.

## Dismissed

- **The ammo dump a `-farp` spawns is not a CTLD logistic point.** Suspected because CTLD looks
  for `logisticUnitTypes` once, at `ctld.initialize()`, before the interpreter spawns the FARP
  (`veafInterpreter.DelayForStartup = 1`). Refuted by the code: `veafGrass` registers every FARP
  it builds with `CTLDZoneManager:registerFOBAsLogistic` (`veafGrass.lua`, "add FARP to CTLD FOBs
  and logistic units"). The prompt's advice to place a `FARP Ammo Dump Coating` beside a FARP is
  therefore only needed for an editor-placed FARP (`add_farp`), not for one spawned by `-farp`.

## One lot, one PR

One lot, as David prefers. 01, 02 and 04 live in `veaf_mission_mcp`, 03 in
`warehouses_injector` and the unit data, 05 across the catalogue. 06 is a measurement in DCS, and
may end in a one-line change to the prompt.

## Out of scope

- The briefing generator of the GermanyCW-v6 mission (`gather.py`, `gen_readme.py`): mission-side
  tooling, outside this repository.
- Carrier operations at runtime (`veafCarrierOperations`): not exercised yet, the mission has not
  flown; a defect found in game gets its own ticket.

## Definition of Done

- Every ticket closed, or measured and closed with its answer.
- The GermanyCW-v6 mission's scripts that stood in for a missing action can be replaced by the new
  actions, and a rebuild produces the same mission.

## Tickets, in full

## 01 — Aircraft built with no chaff, no flare, no callsign, and repeating tail numbers

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/aircraft_payload.py`, `add_air_group.py`,
`player_slot.py`, `set_unit_properties.py`, the unit data, tests

### Origin

GermanyCW-v6, 2026-09-28: the player-versus-player arena, 23 flights of four client slots in air
start, built with `add_air_group` (`skill: "Client"`, `start: "air"`, a loadout).

### Measured

1. **No countermeasures.** `build_aircraft_payload` starts every payload from
   `{"flare": 0, "chaff": 0, "gun": 100, "pylons": {}}` (`aircraft_payload.py:48`). An air-start
   client cannot rearm: every arena pilot went into a missile fight with an empty dispenser. The
   figures the Caucasus v5 arena carried, and the ones the dynamic-slot templates carry: F-14B
   140 / 60, F-16C 60 / 60, F/A-18C 60 / 30, M-2000C 112 / 16, Su-27 and J-11A 96 / 96, Su-33
   48 / 48, MiG-29 30 / 30, JF-17 36 / 32, MiG-21bis 32 / 32, Mirage F1EE 30 / 15.
2. **No action sets them afterwards.** `set_unit_properties` takes skill, livery, heading, callsign,
   onboard number, pylons, name and position — not chaff, flare or gun.
3. **No callsign.** Neither `add_air_group` nor `player_slot` writes `callsign`: the 56 western
   arena aircraft came out with none (`describe_units` → `"callsign": null`), where the editor
   gives every western aircraft a family / flight / number.
4. **Tail numbers repeat.** `add_air_group.py:483` numbers a flight `10 + i`, restarting at 10 in
   every group: the E-3A Overlord 1, the KC-135 Arco 1 and the first arena F-14B all carried `10`.

Worked around by one script on the table (the 92 arena units): chaff and flare per type, a callsign
per type and fox level, tail numbers 701 onwards.

### Done when

- A new aircraft carries its type's default chaff and flare. The source is a choice to make and to
  write down: the DCS unit database (`passivCounterm` defaults, captured by `update-dcs-data`) or
  the mission's own dynamic-slot template of that type. No hard-coded table.
- `add_air_group` and `add_player_slot` take `chaff` / `flare` to override, and so does
  `set_unit_properties`.
- A western aircraft gets a callsign (family, flight, number, spoken name); an eastern one its
  numeric callsign.
- Tail numbers are unique across the mission's aircraft.
- Tests on each point, and the AI catalogue doc says it.

### Done — 2026-09-28

- **Source of the defaults: the DCS unit database**, not the mission's templates — a mission need not
  have a template of the type, and the editor's default is what a mission maker placing the aircraft
  by hand gets. `update-dcs-data --units` now captures `passivCounterm`'s `chaff` / `flare` defaults
  into `dcsUnits.yaml` (F-14B 140 / 60, FA-18C_hornet 60 / 60, UH-1H 0 / 60; absent on the 42 types
  with no dispenser, which keep 0). `build_aircraft_payload` reads them; `add_air_group`,
  `add_player_slot` and `set_unit_properties` take `chaff` / `flare`.
- **Callsigns and tail numbers**: `veaf_mission_mcp/aircraft_identity.py`, called by `add_air_group`,
  `add_player_slot` and the composites. The editor's family table is compiled into the game and not in
  the datamine, so it was measured on 377 distinct missions under `D:\dev\_VEAF`: Russia, USSR,
  Ukraine, China and Abkhazia carry a number; the family follows the task — Texaco / Arco / Shell for
  `Refueling` (807 of 807), Overlord / Magic / Wizard / Focus / Darkstar for `AWACS`, Enfield …
  Pontiac otherwise. A new flight takes the first family nobody uses yet; tail numbers continue after
  the highest in the mission (3 digits).
- Tests: `test_aircraft_identity.py`, `test_aircraft_payload.py`, `test_set_unit_properties.py`,
  `test_dcs_data_units.py`. Documented in `AI_ASSISTANT_CATALOG` (FR/EN).

## 02 — Nothing places a working carrier group

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (a new action, or `add_group` / `add_air_group` /
`edit_route` extended), tests, `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

### Origin

The Open Training prompt (§4.3) asks for a friendly carrier group when the map has sea: TACAN, ICLS
and Link 4, a recovery tanker, a rescue helicopter, module `CARRIER`, "and what the MCP cannot do,
report it". GermanyCW-v6, 2026-09-28: nothing of it could be done with the actions.

### Measured

1. **No ATC task on a ship.** `edit_route`'s task set is closed (orbit, land, attack_group, bombing,
   engage_targets_in_zone, set_frequency, switch_waypoint, tanker, awacs, set_unlimited_fuel, eplrs,
   activate_beacon, escort). `activate_beacon` is an aircraft TACAN; there is no ship TACAN, no
   `ActivateICLS`, `ActivateLink4` or `ActivateACLS`. No action of `develop` mentions them.
2. **No deck slot.** `add_air_group` starts on an airfield's parking, a runway or in the air;
   `add_player_slot` needs `airdrome_id`. A deck start needs `linkUnit` / `helipadId` set to the
   ship's unit id on the first point, which nothing writes.
3. **No ship warehouse.** A carrier needs a `warehouses.warehouses[<unitId>]` entry (fuel, weapons,
   aircraft). `add_farp` writes one for a FARP; nothing does it for a ship. Without it the build
   said « 0 navires/FARP » and the carrier had none.
4. **Two traps met on the way,** both worth a test in whatever action this becomes:
   - `veafCarrierOperations` reads the ATC tasks from the group's `tasks` table
     (`veaf.findInTable(carrierData, "tasks")`), where the v5 stored them; DCS runs the ones on the
     first route point. The copy puts them in both. Which one DCS needs is to be checked in game.
   - The v5 deck slots carried an `EPLRS` task naming stale group ids (9 and 17, for groups whose ids
     were 702 and higher): an id remap must cover `groupId` inside tasks too.

Worked around by copying the Caucasus v5 `CSG-74 Stennis` group (4 ships), its `Pedro` and
`S3B-Tanker`, six deck slots and the warehouse entry, ids remapped, by script.

### Done when

- One action places a carrier group ready to use: the ships, the ATC tasks (TACAN channel and
  callsign, ICLS channel, Link 4 and tower frequencies), the `<carrier unit> Pedro` and
  `<carrier unit> S3B-Tanker` groups `veafCarrierOperations` looks for, the ship warehouse.
- Deck slots can be added to a named carrier (cold or hot start), numbered on the deck.
- Tested; the prompt's §4.3 no longer needs a "report it".

### Done — 2026-09-28

- `add_carrier_group` (`veaf_mission_mcp/carrier.py`): ships under way, tower frequency on the carrier
  unit, `ActivateBeacon` / `ActivateICLS` / `ActivateLink4` / `ActivateACLS` (Link 4 and ACLS only on
  an arrested-landing deck), `<carrier> S3B-Tanker` (Tanker task + TACAN Y) and `<carrier> Pedro`,
  the ship's warehouse entry.
- Deck slots: `add_air_group` `start: deck-cold | deck-hot` with `carrier`, linked by `linkUnit` =
  `helipadId`, spots numbered on; an aircraft that cannot use that deck is refused.
- **Trap 1 answered by measurement, not in game**: of 218 carrier groups under `D:\dev\_VEAF`, 120
  keep their ATC tasks on the group's `tasks`, 55 on the first route point, 43 in both. The action
  writes both, as the copy did: `veafCarrierOperations` reads the group, the editor writes the route.
  Which of the two DCS runs is still unmeasured, and harmless while both are written.
- **Trap 2** does not arise: the action allocates fresh ids and names its tasks' units by the id it
  just allocated; no copy, so no stale `groupId` to remap.
- The prompt's §4.3 no longer asks the agent to report the carrier group; it names the actions.
- Tests: `test_carrier.py`.

## 03 — The build opens a carrier's deck to every dynamic template of its side

Status: ✅ done
Type: fix + data
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`, the unit data
(`veaf_libs/data/dcsUnits.yaml`, `update-dcs-data`), tests

### Origin

GermanyCW-v6, 2026-09-28, once the carrier had a warehouse (ticket 02): the default
`warehouses.yaml` (no `ships:` key) applies the coalition defaults to every ship of the side.

### Measured

- The build log went from « 12 aéroports configurés, 0 navires/FARP, 612 liens de modèle » to
  « … 1 navire/FARP, 663 liens » — 51 more links, all on the Stennis: every blue template,
  B-52H and CH-47 included.
- The filter is by the **ship's** type only: "`AircraftCarrier` takes planes and helicopters"
  (module docstring). Nothing asks whether the **aircraft** can use a deck.
- The unit data cannot answer: `dcsUnits.yaml` carries `AircraftCarrier With Catapult` / `With
  Arresting Gear` / `With Tramplin` as ship attributes (23 occurrences), and no aircraft entry
  says which deck it can use. DCS does: an aircraft's `LandRWCategories`.

Worked around with a `ships: { CVN-74 Stennis: { aircrafts: {…} } }` list of five types (F/A-18C,
F-14B, AV-8B, UH-1H, AH-64D).

### Done when

- `update-dcs-data` captures each aircraft's `LandRWCategories` into the unit data.
- The injector stocks a carrier only with the aircraft whose categories match the ship's
  (catapult / arresting gear / ski-jump / helicopters), the way it already filters an airfield by
  its parking.
- An explicit `aircrafts:` list is still obeyed. Tested on a catapult carrier and on a LHA.

### Done — 2026-09-28

- `update-dcs-data --units` captures `TakeOffRWCategories` and `LandRWCategories` into
  `dcsUnits.yaml` (`takeoff_categories` / `landing_categories`).
- The injector stocks a ship's **default** list only with the templates whose aircraft can both take
  off from and land on it (one category of each among the ship's attributes), and removes the other
  types an earlier build left there. An F-14B (catapult take-off) goes on the Stennis, not on the
  Tarawa; a Su-33 (ski-jump take-off) not on the Stennis. A type the database does not know is kept
  off a deck. An explicit `aircrafts:` list is obeyed as written.
- Tests: `test_carrier_deck_filter.py` (a CVN, an LHA, a frigate, a stale stock, an explicit list).

## 04 — No action makes a unit transmit a sound, or embeds the sound

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (`edit_route` task set or a new action, the
mission folder writer), tests, AI catalogue doc

### Origin

The Open Training prompt (§4.6) proposes a non-combat helicopter zone: "des balises radio sur
l'itinéraire (sons joués en boucle, fréquences FM données au briefing) et un signal de détresse sur
le lieu … Les sons doivent exister dans la mission." GermanyCW-v6, 2026-09-28.

### Measured

- The v5 "Mountain Hike" does it with a ground unit whose first route point carries
  `SetFrequency` (31 / 32 / 33 / 34 MHz FM) and `TransmitMessage` (`file` = a `ResKey`, `loop =
  true`, a `DictKey` subtitle). It transmits from its position, so a helicopter can home on it with
  its direction finder, and only while the combat zone that owns it is active.
- `edit_route` has `set_frequency` but no `transmit_message`.
- Nothing puts a sound file in `src/mission/l10n/DEFAULT/` and declares it in `mapResource`
  (`add_startup_script_trigger` touches `mapResource` for scripts only).

Worked around by copying the v5 groups and their four `.ogg` files, and writing `mapResource` and
`dictionary` by hand.

### Done when

- `edit_route` takes `transmit_message` (sound, loop, subtitle), validated against the sounds the
  mission holds.
- An action adds a sound to the mission folder (copied into `l10n/DEFAULT`, declared in
  `mapResource`) and returns the key to use.
- Tested; the prompt's beacon zone can be built without a script.

### Done — 2026-09-28

- `add_sound`: copies a `.ogg` / `.wav` into `l10n/DEFAULT` and declares it in `mapResource` as
  `MCP_Sound_<stem>` (never `VEAF_MapKey…`, which the build removes); the same file again reuses its
  key.
- `edit_route` `transmit_message`: a wrapped `TransmitMessage` whose shape is that of the 80
  transmissions of 55 missions under `D:\dev\_VEAF` (`file` = the key, `loop`, `duration` 5 or 20 s,
  `subtitle` as a dictionary key). Refused when the mission does not hold the sound.
- The prompt's §4.6 names the two actions and the `set_frequency` → `transmit_message` order.
- Tests: `test_add_sound.py`, `test_edit_route.py::TestTransmitMessage`.

## 05 — The mission is named by five different parameters across the catalogue

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/catalog.py` and the action schemas, tests, AI
catalogue doc

### Origin

`FIX-SCRATCH-MISSION-FINDINGS` ticket 19 (point 7) made a misnamed parameter answer with the
expected names instead of a bare error. It left the names themselves alone. GermanyCW-v6,
2026-09-28: running actions in batches, four calls failed on the name alone (`geocode` and
`resolve_coordinates` given `miz_path`, `set_briefing` given `mission_path`, `describe_module`
given `mission_path` and `module`), each costing a retry.

### Measured

On `develop` at `8bc1a1fe`, 42 of the 47 actions take the mission, under five names:

| Name | Actions |
|---|---|
| `miz_path` | 17 (`describe_units`, `edit_route`, `add_map_drawing`, `set_unit_properties`, …) |
| `target` | 9 (`add_group`, `add_air_group`, `set_briefing`, `set_bullseye`, …) |
| `mission_yaml_path` | 6 (`set_mission_module`, `describe_module`, …) |
| `folder_path` | 6 (`validate_mission`, `build_mission`, `create_qra`, …) |
| `mission_path` | 4 (`geocode`, `resolve_coordinates`, `describe_map`, `list_airfields`) |

Most of them accept the same thing (a mission folder or a `.miz`); only `mission_yaml_path` names a
different file.

### Done when

- One name for "the mission folder or `.miz`" across the catalogue; the old names accepted as
  aliases, so no caller breaks.
- `mission_yaml_path` either kept (it is a different file) or derived from the folder, decided and
  written.
- A catalogue test that fails when a new action introduces another name.

### Done — 2026-09-28

- **One name: `mission_path`.** The catalogue publishes it for every action that took `miz_path`,
  `target` or `folder_path`, and translates it back to the handler's own key at `run_action`, so no
  handler changed; the three former names stay accepted as aliases, and two different values under
  two names are refused.
- **`mission_yaml_path` is kept** — it names a different file — but a `mission_path` given in its
  place is read as the folder's `mission.yaml`, which is the `describe_module` failure the report met.
- `test_catalog.py::test_no_shipped_action_introduces_another_name_for_the_mission` fails on a sixth
  name. Developer doc updated (FR/EN).

## 06 — Measure whether late-activated sanctuary vertices give DCS a position

Status: ✅ done — measured 2026-09-28, nothing to change
Type: measure (DCS), possibly doc
Files: none until measured; then `.prompts/new-open-training-mission.*.md` or
`src/scripts/veaf/veaf.lua` (`veaf.getPolygonFromUnits`)

### Origin

The Open Training prompt (§4.1): "Le polygone est tracé par des unités en activation différée
(`polygon_units`), jamais activées." GermanyCW-v6 (2026-09-28) followed it for its four sanctuaries
(23 vertices).

### Measured, on paper only

- `veaf.getPolygonFromUnits` takes `Unit.getByName(name)`, else `Group.getByName(name):getUnit(1)`,
  reads `unit:getPosition().p` and destroys the unit (`veaf.lua`).
- The demo mission does as the prompt says: its 16 `Sanctuary_Kutaisi_Polygon` groups are all
  `lateActivation = true`.
- The Caucasus v5, whose sanctuary the prompt's rule comes from, does not: its `BlueSanctuary`
  vertices are **active** ships, destroyed by the script at start.
- Whether DCS returns a unit, and its position, for a group that was never activated has not been
  checked. If it does not, every vertex is skipped and the sanctuary has no polygon, with no error.

### Done when

- Measured in DCS (dcs-bridge): `Unit.getByName` and `getPosition()` on a never-activated vertex,
  and the polygon a sanctuary actually builds from them.
- If it works: nothing to change, the answer written here. If not: the prompt says active units,
  or `getPolygonFromUnits` reads the position from the mission data (`env.mission`) instead.

### Answer — measured in DCS on 2026-09-28

Measured in single-player on `test/veaf-tools/demo-mission/veaf-demo-mission.miz`, through the fiddle
hook (mission environment), after 30 s of mission time:

- **The sanctuary builds its polygon**: `Kutaisi Sanctuary` holds **16 vertices**, one per
  `Sanctuary_Kutaisi_Polygon #0xx` group, all 16 `lateActivation = true`.
- **Raw DCS behaviour**, on the 3 late-activated groups the sanctuary did not consume (19 in the
  mission): `Group.getByName` finds them, `getUnit(1)` returns the unit, `getPosition()` answers.
  The never-activated unit reports `isExist() = true`, `isActive() = false`, and its position equals
  the mission table's exactly (`(-273213, 614091)` on both sides).

So the prompt's rule holds: late-activated vertices give `veaf.getPolygonFromUnits` their position.
Nothing changed, in the prompt or in `veaf.lua`. Consistent with the known trap that a late-activated
group answers `isExist()` true (`docs/agents/dcs-runtime-traps.md`).
