# 17 — `create_cap_mission` makes a CAP with no engage task

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/veaf_mission_mcp/add_air_group.py`, `composites.py`, `edit_route.py`,
tests, `doc/mission-maker/AI_ASSISTANT_CATALOG*.md`

## Origin

GermanyCW-v6 rebuild of 2026-09-24: on-demand CAPs made with `create_cap_mission`, read back with
`describe_units`.

## Measured

Waypoint 1 of the template carries a single `Orbit` task — no `EngageTargets`. Choosing the CAP task
in the DCS Mission Editor adds "Engage Targets" on its own. To get it, the session had to run
`edit_route clear_tasks`, then `engage_targets_in_zone`, then `orbit`, to put the engagement **before**
the endless orbit.

## Cause

- `insert_air_group_into_content` with a `route` writes `{"tasks": {1: orbit}}` on the first point and
  nothing else (`add_air_group.py:281-284`); `create_cap_mission` passes `task="CAP"`
  (`composites.py:309`) but that only sets the group's main task. Without a `route`, there is no task
  at all ("without, it orbits nowhere", `composites.py:277-278`).
- `edit_route add_task` **appends** (`edit_route.py:423-427`, `number = len(tasks) + 1`): an
  engagement added after an orbit with no stop condition comes after a task that never ends.

## What it is not

Not verified in game yet: that a CAP without `EngageTargets` does not engage, and that a task placed
after an endless orbit is never read, are expected from the editor's own task order, not measured.
Measure both before and after the fix (see `docs/agents/dcs-runtime-traps.md`, and add the result
through `known-limitations.yaml`).

## Done when

- A CAP template from `create_cap_mission` carries an engage task placed before its orbit, like the
  editor's CAP task
- `edit_route add_task` can insert at a position (or document that it appends, and how to order tasks)
- Test: the built template's first point has the engage task numbered before the orbit
- Checked in DCS: the template engages an intruder in its zone
