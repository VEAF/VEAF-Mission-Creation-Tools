# 02 — No action removes a group, so removal is done by hand

Status: ✅ done — 2026-08-19. `remove_group` ships in `veaf_mission_mcp/remove_group.py`: exact name
only, survivors re-keyed `1..n`, and the `group` key dropped rather than left empty. The three
reference checks all landed, and the `Escort` one had to walk **into** a `ComboTask` — that is how DCS
actually nests the task, so a flat read would have found nothing and reported no reference at all. The
`ASSETS` check needs `mission.yaml`, so it only runs on a folder target; a `.miz` gets the two
mission-table checks and no false reassurance about the third.
Type: feat
Files: a new action under `src/python/veaf-tools/veaf_mission_mcp/`, the mission-maker action
catalogue (both languages), tests

Related: [`FIX-GROUP-CONTAINER-SHAPE`](../../FIX-GROUP-CONTAINER-SHAPE/PRD.md) owns the other half —
making the build survive a container that a hand edit left dict-shaped. **This ticket does not
duplicate it**: it removes the reason to hand-edit in the first place.

## What is missing

The catalogue can add a group (`add_group`, `add_air_group`, `add_player_slot`), move it, rename it
and reconfigure it — but not **remove** it. `edit_zone` has `remove: true`, `edit_map_drawing` has
`remove: true`; groups have nothing.

## What that cost, measured

Building `verify-mission-c` on 2026-08-18 needed three removals: an air-start slot inherited from the
forked mission, and twice a player slot that had to be recreated elsewhere. Each was a hand-deleted
Lua block, and each left the enclosing list numbered `1,3,4` — three corrupted builds, each dying on
`AttributeError: 'int' object has no attribute 'get'` at a line pointing nowhere near the edit.

The repair made it worse before it made it better: a renumbering regex keyed on indentation alone also
matched `units` and `route.points` entries, renumbering a one-element `units` list to `[3]` and a
single waypoint to `[2]`. That evidence is written up in `FIX-GROUP-CONTAINER-SHAPE`, since it widens
that lot's scope beyond group containers.

## What ships

A **`remove_group`** action addressing a group by its exact name — refusing a fragment, the way
`set_group_properties` does — that:

- removes the entry and **renumbers the siblings it leaves behind**, so the container stays `1..n`
- removes the `group` key entirely when it takes the last one, rather than leaving an empty container
  (the shape `FIX-GROUP-CONTAINER-SHAPE` opens on)
- **names what it breaks**: a group captured by a combat zone through its name prefix, one named in
  `ASSETS.linked`, or one an `Escort` task points at by group id. Today all three break in silence
- accepts a folder target as well as a `.miz`, per [03](03-folder-targets-for-editors.md)

## Done when

- `remove_group` removes and renumbers; a test asserts the surviving indices are `1..n`
- Removing the last group of a category removes the key instead of leaving `{}`
- Removing a referenced group warns, naming the reference and where it lives
- A test covers the three real removals this ticket came from: a player slot, an air-start slot, and
  the last group of its category
