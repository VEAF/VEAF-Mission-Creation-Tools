# 02 — add_farp can clear the scenery around its pad

Status: 🚫 wontfix

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

## Measured in DCS, single player, 2026-10-12: nothing is removed

**`clear_scenery_radius` as merged (#1125) does not work.** The trees stay; the option must be fixed or taken out before the next release.

- Marianas (`veaf-test-farp-clear.miz`, FARP Merizo, radius 80): the small Disposition query finds **0 of 24** free points on every ring from 20 to 150 m, inside the zone as outside; the known clear spot 1.2 km away (-23450, -12150) answers 10 of 10, so the probe works. David's screenshot (F12, top view): jungle right up to the edge of the FARP's own grass square.
- Caucasus (`veaf-test-farp-clear-caucasus.miz`, three FARPs in catalogued woods near Batumi, Sukhumi and Mineralnye Vody, radius 80, no building within 80 m): **0 of 48** free points at 40–70 m inside each zone, 0–1 of 48 at a control point 300 m away. David's F12 screenshot of FARP Batumi: the forest touches the FARP square to the north and east. So it is not a Marianas quirk.
- `dcs.log`: no error after the mission start.
- Not known yet: whether the trigger fires at all. Next step: read `mission.trig.func[<index>]` in the server environment through the fiddle hook (`net.dostring_in`, `veaf_libs/dcs_fiddle_client.py`) after the first second — nil means it fired. Then, either way, save the same trigger from the Mission Editor (zone + ONCE + TIME MORE 1 + SCENERY REMOVE OBJECTS ZONE, TREES ONLY) and diff the two `.miz`: the editor's own file is the reference, not the v5's, which nobody has shown to work.

## Measured again, 2026-10-12 afternoon, and decided

- The trigger **does fire**: read through the fiddle hook in the server's mission environment, `mission.trig.func[2..4]` are nil after the first second (the entry clears itself when it runs), and `a_remove_scene_objects` is a function there.
- The zone is right: `trigger.misc.getZone` gives the FARP's centre and 80 m.
- Called directly near Batumi, `a_remove_scene_objects(<zoneId>, 0)` (« ALL ») and `a_remove_scene_objects("<zone name>", 0)` both return without error and leave the forest standing (F12 view, before and after).
- The small Disposition query is **not** a measure of trees: near Sukhumi it found 0 of 48 free points around a pad standing in open grass (F12 view). The probe figures above prove nothing on their own; the screenshots do.

**Decision (David, 2026-10-12): take the option out before any release, record both measurements as known limitations** (`scenery-remove-objects-zone-leaves-the-forest`, `disposition-small-query-blocks-open-grass`), **and say in `farp-spot`'s documentation that a spot it leaves out is not necessarily wooded.** Done in the follow-up pull request; the multiplayer measurement is moot.
