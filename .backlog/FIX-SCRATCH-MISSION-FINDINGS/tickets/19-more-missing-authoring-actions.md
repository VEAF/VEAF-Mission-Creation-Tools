# 19 — More actions the agent had to replace with scripts on the Lua table

Status: ✅ done
Type: feat + fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (actions, `catalog.py`, `server.py`), tests,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

## Origin

GermanyCW-v6 rebuild of 2026-09-24. Ticket 07 closed the first list; building the mission again with
the MCP on develop found the next one. Same rule as `FIX-MCP-AUTHORING-GAPS`: an action that does not
exist is an invitation to patch the mission file by hand.

## Measured, and where it stands in develop

1. **A complete FARP** (helipad, frequency, warehouse entry). `add_group` in category `static` places
   the object alone. Worked around with `#veafInterpreter["-farp <name>"]`.
2. **The base mission's weather.** The blank mission has `clouds.preset = "Preset1"` with `base = 0`.
   No action writes `weather` (the action list in `actions.py` has none; `set_mission_setting` writes
   `mission.yaml` `settings.<key>`, not the mission table).
3. **Renaming or moving a single unit.** `set_unit_properties` takes skill, livery, heading, callsign,
   onboard number and pylons — no name, no position; `set_group_properties` moves and renames the
   group only ("Unit names are never renamed with the group").
4. **`build_mission` takes no profile.** Its schema is `folder_path` only (`actions.py`,
   `build_mission`), so `LOCAL_TEST` cannot be built through the MCP.
5. **No action lists a theatre's airfields** (names, ids, positions). The session read
   `veaf_build/dcs_data/airbase_dumps/GermanyCW.json` directly.
6. **`resolve_coordinates` takes one position per call** (`position` is a single object).
7. **A misnamed parameter fails with no message.** Reproduced on develop the same day:
   `run_action("describe_map", {"miz_path": ...})` → `Error executing tool run_action`, nothing else.
   `Catalog.run_action` forwards `params` to the handler as-is (`catalog.py:61-78`), never checks them
   against `parameters_schema`; the handler's `p["mission_path"]` raises a bare `KeyError`. The trap is
   made likelier by the names themselves: the path is `mission_path` (`describe_map`,
   `resolve_coordinates`), `miz_path` (`set_unit_properties`, `set_group_properties`), `folder_path`
   (`build_mission`, `set_airbase_coalition`) or `target` (`add_group`) depending on the action.

## Done when

- Points 1-6: each an action (or a parameter of an existing one), validated, in the catalogue and the
  AI catalogue doc, tested
- Point 7: `run_action` validates `params` against the action's schema and answers with the missing
  or unknown parameter's name; test with a misnamed parameter

## Outcome

1. `add_farp`: the heliport static in the editor's shape (`shape_name` per type, measured on 372
   heliports), its frequency and callsign, and the `warehouses.warehouses[<unitId>]` entry stocked
   like the editor's default. `warehouses.yaml`'s `farps:` then configures it at build.
2. `set_weather`: the base mission's weather through the converter the weather variants use, same
   vocabulary as `versions[].weather`, a METAR accepted; drops the `atmosphere` table of ticket 01.
3. `set_unit_properties` takes `new_name` (refused on a duplicate: DCS unit names are unique across
   the mission) and `position`; an aircraft gets a warning that its route places it.
4. `build_mission` takes `profile` → `--profile`.
5. `list_airfields`: name, id, lat/lon and x/y. The positions were only in `veaf_build`'s runtime
   dumps, not shipped: `update-dcs-data --airdromes` now writes `airdrome-positions.yaml` beside
   `airdromes.yaml`, bundled in the exe (810 airbases, 14 theatres).
6. `resolve_coordinates` takes `positions` (a list), one read of the mission.
7. **Wider than the ticket.** Since the move to `mcp` 2.x (1216ba58, 2026-08-10) the SDK hands the
   client only `Error executing tool run_action` for any exception but its own `ToolError` — so
   *every* refusal an action words for the agent arrived as that one line, not only a misnamed
   parameter. `run_action` now re-raises as `ToolError` with the type and message (tested through
   `mcp.call_tool`), and `Catalog.run_action` checks the parameters against the action's schema,
   naming the missing and the unknown ones with the expected ones. Every one of the 43 handlers reads
   only keys its schema declares (checked by reading their source), so refusing unknown keys is safe.
