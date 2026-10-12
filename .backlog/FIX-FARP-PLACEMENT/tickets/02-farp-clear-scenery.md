# 02 — add_farp can clear the scenery around its pad

Status: 🧑 waiting-human

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

## Done so far (2026-10-12, #1125)

- Coded and tested: `clear_scenery_radius`, zone `<FARP> - Clear`, a `triggerOnce` gated on `c_time_after(1)` with `a_remove_scene_objects(zone, 1)`, dispatched from `func` and clearing its own entry — the Marianas v5 shape. On a folder that already holds triggers, it takes the next free index (measured).
- First unknown answered from the editor's source, not guessed: `objects_mask` is a combo in `MissionEditor\modules\me_trigrules.lua` — 0 « ALL », 1 « TREES ONLY », 2 « OBJECTS ONLY ». The v5 and DCS's own mission generator (`MissionEditor\data\MissionGenerator\FormatTemplates\removeTreesRule.mt`) both write 1. The option removes trees only: a building on the pad stays.

## Left: the measurement in DCS

- Test mission: `Saved Games\DCS\Missions\veaf-test-farp-clear.miz` — blank MarianaIslands, the bridge, FARP Merizo at its first position (-22300, -12450) with `clear_scenery_radius: 80`, an A-10C II air start 4 km north heading for it at 1 500 ft, a game master slot. Built from `add_farp` itself.
- Single player: load it, take the A-10 slot; a probe through the bridge counts a free 5 m spot within 20 m on rings of 20–150 m around the pad, and the scenery objects left within 80 m. Expected: rings inside 80 m free apart from the pad itself, rings outside as blocked as the 2026-10-12 baseline (0 of 12 free at 30 m, 3–6 of 12 at 60–120 m). A screenshot from the cockpit for the eye.
- Multiplayer client, including one joining late: needs a server and a second client — dcs.veaf.org or two machines; not doable on one workstation.
