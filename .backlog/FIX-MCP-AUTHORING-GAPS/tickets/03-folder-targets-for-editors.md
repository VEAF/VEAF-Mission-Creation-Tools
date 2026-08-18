# 03 — The editing actions refuse a mission folder, so durable edits get hand-written

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/actions.py` (parameter plumbing), the affected action
modules, the mission-maker action catalogue (both languages), tests

## The inconsistency

`add_group`, `add_air_group` and `add_player_slot` take a `target` that is **either** a mission folder
(durable, written into `src/mission/`, survives a rebuild) **or** a `.miz` (transient). Every editing
action next to them — `edit_route`, `set_group_properties`, `set_unit_properties`, `edit_zone`,
`add_trigger_zone`, `add_map_drawing`, `edit_map_drawing` — takes only `miz_path`.

So a group can be *created* durably but not *edited* durably. Pointing `edit_route` at the exploded
folder fails on the filesystem, not with a helpful refusal:

```
[Errno 13] Permission denied: '…/verify-mission-c/src/mission'
```

## What that cost

`verify-mission-c` needed a tanker with a 3-waypoint track (`veafMove._getTankerRouteData` refuses a
shorter route) and an escort whose last waypoint carries an enabled `Escort` task
(`veafMove.teleportEscort` gives up without one). `add_air_group` created both groups durably;
`edit_route` could not touch them. Both routes were therefore hand-written into
`src/mission/mission` — including a task the action set does not model at all — which is how the
mission ended up needing the repairs described in [02](02-remove-group.md).

## Scope, and what is deliberately not in it

**In:** accept a folder wherever a `.miz` is accepted, resolving to `src/mission/mission`, with the
same backup-first behaviour. The actions already write that file through the same helpers the `add_*`
actions use, so this is plumbing, not new semantics.

**Not in:** adding `Escort` to `edit_route`'s closed task set. That deserves its own measurement —
the task carries a `groupId` DCS assigns and a relative `pos`, and the closed set exists precisely so
a made-up task table is refused rather than silently ignored. Worth a ticket of its own once someone
has a real mission to read the layout from.

## Done when

- Each editing action accepts a folder target, documented in its description the way `add_group`
  documents the trade-off between the two
- A folder path that is not a mission folder is refused with a message that says so, not an `Errno 13`
- A test edits a route through a folder target and asserts the change landed in `src/mission/mission`
  and survives a rebuild
