# 18 — `create_combat_zone` takes no route for its groups

Status: ✅ done (#1000)
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/composites.py`, `actions.py`, tests,
`doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

## Origin

GermanyCW-v6 rebuild of 2026-09-24: a moving convoy in a combat zone (a native group with "On Road"
waypoints).

## Measured

The session had to create the zone with no group, then the convoy with `add_group` (which takes a
`route`) and `for_combat_zone`. Two calls and a naming convention to get right by hand, where one
composite call was meant to do it.

## Cause

`create_combat_zone` documents its groups as `[{"name", "units": [{"type","count"}], "position"?}]`
(`composites.py:50`) and calls `insert_group_into_content` with `name`, `position` and `units` only
(`composites.py:77-86`) — no `route`, no `patrol`, although `insert_group_into_content` accepts both
(`add_group.py:186-193`).

## Done when

- A group of `create_combat_zone` accepts `route` (and `patrol`) with the same shape as `add_group`
- Test: a zone with a routed group gets its waypoints; a group without keeps today's behaviour

## Outcome

`create_combat_zone` groups take `route` and `patrol`, with `add_group`'s shape, passed straight to
`insert_group_into_content`; a group without a route keeps today's single point.
