# 02 — An action that says which aircraft types an airfield can offer

Status: ⬜ ready
Type: feature
Files: `src/python/veaf-tools/veaf_mission_mcp/` (new action and its catalogue entry), the guide's recipe, `doc/developer/mission-editing-mcp.md` and `.en.md`, tests

Add an action that returns, for an airfield, the aircraft types a warehouse can hold, with the exact DCS names the build validates (`F-16C_50`, `AV8BNA`). Source: the data the build already uses for `warehouses.yaml` (see `mission_builder/warehouses_bootstrap.py`, `dynamic_settings.py`) — find it, do not duplicate a table.
The compact recipe then tells the model to call it instead of editing `src/warehouses.yaml` by hand. The standard profile keeps working unchanged.
Mind the layers rule: logic in the tool brick, the action only maps arguments. Update the MCP action catalogue documentation in the same change.
Tests: known airfield → names the build accepts; unknown airfield → clear error; the names returned pass the warehouse validation; the recipe names the action; the compact chain budget still holds.
