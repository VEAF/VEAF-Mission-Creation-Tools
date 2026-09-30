# 02 — Nothing places a working carrier group

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/` (a new action, or `add_group` / `add_air_group` /
`edit_route` extended), tests, `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

## Origin

The Open Training prompt (§4.3) asks for a friendly carrier group when the map has sea: TACAN, ICLS
and Link 4, a recovery tanker, a rescue helicopter, module `CARRIER`, "and what the MCP cannot do,
report it". GermanyCW-v6, 2026-09-28: nothing of it could be done with the actions.

## Measured

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

## Done when

- One action places a carrier group ready to use: the ships, the ATC tasks (TACAN channel and
  callsign, ICLS channel, Link 4 and tower frequencies), the `<carrier unit> Pedro` and
  `<carrier unit> S3B-Tanker` groups `veafCarrierOperations` looks for, the ship warehouse.
- Deck slots can be added to a named carrier (cold or hot start), numbered on the deck.
- Tested; the prompt's §4.3 no longer needs a "report it".

## Done — 2026-09-28

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
