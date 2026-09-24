# 19 — More actions the agent had to replace with scripts on the Lua table

Status: ⬜ ready
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
