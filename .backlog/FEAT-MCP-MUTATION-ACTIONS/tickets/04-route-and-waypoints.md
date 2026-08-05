# 04 — Route and waypoint task editing

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, mission-maker catalogue doc, `test/python/`

Depends on: 01 for scope, 03 for the move semantics it shares.

## The use case

> *"Add a waypoint with an attack task."*

The third the exploration note names, and the largest of the three: dcs-sms spends **25 verbs** here,
more than on units. That is a signal about where mission-editing effort actually goes.

## Behaviour

Two layers, and the second is where the value is:

**The route** — add, insert, move, remove a waypoint; set its altitude, speed, and type. Mechanical,
and mostly a list operation on `route.points`.

**The waypoint's tasks** — what a waypoint *does*: attack a group, orbit, land, refuel, set a
frequency, switch a flag. This is a nested structure of `task` / `params` whose shape depends on the
task id, so the same trap as their trigger predicates applies: hardcoding each shape means rotting
the day ED adds one.

Prefer **a small named set of tasks a mission maker asks for**, each with a validated signature, over
a generic "write this task table" action. A generic action is a foot-gun: an agent produces a
plausible task table, DCS ignores it silently, and the mission maker discovers the flight does
nothing an hour into testing. If 01's triage finds the named set too limiting, an escape hatch can
come later — but it starts closed.

`ETA locked` deserves a mention: `FIX-WAYPOINTS-ETA-LOCKED` exists as a branch name in this repo's
history, so the interaction between an edited waypoint and its ETA is known to be delicate. Check
what that work concluded before touching timing fields.

## Tasks

- [ ] Route-level operations on waypoints: add, insert at index, remove, reorder.
- [ ] Altitude, speed, waypoint type, with the units stated in the action's description (the mission
      table is metres and m/s, mission makers think feet and knots — state which the action takes).
- [ ] A named set of waypoint tasks, each validated; an unknown task name is refused naming the set.
- [ ] Read the current route back, so an agent can see what it is editing.
- [ ] Check what `FIX-WAYPOINTS-ETA-LOCKED` concluded before writing any timing field.
- [ ] Mission-maker catalogue doc updated in this ticket.

## Acceptance criteria

- [ ] Round trip through the DCS Mission Editor with no complaint; a flight with an added attack-task
      waypoint **flies it** in game, since the editor accepting a task table is not proof DCS runs it.
- [ ] Tests: each operation, each task, plus the refusal path for an unknown task.
- [ ] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
