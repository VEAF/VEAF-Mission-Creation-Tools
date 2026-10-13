# 06 — A convoy between two places, on the roads

Status: ⬜ ready — the action itself needs the bridge

Files: a new MCP action; the road query through dcs-bridge; `doc/developer/mission-editing-mcp.md` and `.en.md`.

## What happened

Report finding 11: the Falklands convoys' routes came from `land.findPathOnRoads` (`tools/roads.py`) and were reshaped by hand (`tools/fix_convoys_on_road.py`).
An action « convoy on the road between A and B » would do it in one call.

## Done when

- **If the bridge is launched** (`dcs-serve` running), an action takes two places or points and a group, asks `land.findPathOnRoads` and writes an `On Road` route at the convoy speed measured in ticket 04.
- **Otherwise, at least**: the MCP catalogue and `mission-editing-mcp` (both languages) say how the route is obtained today — the bridge call, then `edit_route` — so the workaround stops being a private script.
