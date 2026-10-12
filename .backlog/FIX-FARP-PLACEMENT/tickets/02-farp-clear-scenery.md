# 02 — add_farp can clear the scenery around its pad

Status: 🔄 in-progress

Files: `veaf_mission_mcp/add_farp.py`, the trigger writer `add_startup_script_trigger` uses (or a sibling for a DCS action), `veaf_mission_mcp/actions.py`, the authoring skill, tests.

## What happened

Nothing in VMCT removes scenery. The Marianas v5 cleared the trees of its Tinian FARP by hand: trigger zones `RemoveTreeTinian-1/-2/-3` (radius 20–25 m) and a once-trigger at mission start whose action is `a_remove_scene_objects` on each zone. On a jungle map, the clear spot for a FARP can be more than a kilometre away (Merizo: 1.2 km); clearing the trees where the FARP is wanted is the other way out.

## Unknown, to measure in DCS before the code is final

- What `a_remove_scene_objects` removes (trees only, or buildings too; is there an objects-type parameter in the editor's action), read from a mission saved by the editor with that action.
- Whether every client sees the scenery removed in multiplayer, including a client joining later.

## Done when

- `add_farp` takes `clear_scenery_radius` (metres, default none): it writes a circular trigger zone `<FARP> - Clear` at the pad and a mission-start once-trigger removing the scene objects in it, in the editor's own shape.
- The written trigger loads in the Mission Editor and the trees are gone in game around the pad (screenshot), in single player and on a multiplayer client.
- Tests: the zone and the trigger are written, in the editor's shape; without the option nothing is added.
