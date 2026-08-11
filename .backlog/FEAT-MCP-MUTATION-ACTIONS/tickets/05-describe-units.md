# 05 — Read the units, loadouts and routes

Status: ⬜ ready
Type: feat
Files: `veaf_mission_mcp/describe_mission.py` (or a sibling), `actions.py`, the catalogue doc, tests

## Why this is first, ahead of its own number

The [triage](../PRD.md) went looking for what needs a read action to be usable and found that **the
agent cannot see a unit at all**. `describe_mission` returns groups (name, coalition, country, category)
and zones (name, x, y, radius) — nothing else. No units, no loadout, no skill, no livery, no route, no
waypoint, no task.

So tickets 02 and 04 are not merely more convenient with this: they are **blind without it**. "Give
Colt flight an air-to-ground loadout" needs the current loadout and the pylon layout; "add a waypoint
after the third" needs the route. An agent that mutates without reading produces a mission that opens
in the editor and flies wrong, which is the failure mode nothing here catches.

It also answers **18 of the 126 verbs** in one action — `unit-get/list/payload`, `group-get/list`,
`route-get/list`, `waypoint-get/list-tasks/describe-task`, `zone-get/list`, `airbase-get/list`,
`drawing-get/list`, `trigger-get/list` — which no setter comes close to.

## Behaviour

One read action, shaped by what a mission maker asks: *"what is in this mission — who flies what, with
which loadout, on what route?"*

- Per **unit**: name, type, skill, livery, callsign, onboard number, position, heading, altitude, fuel,
  and the **loadout** (pylon → weapon, plus the pylon layout so a setter can be written against it).
- Per **group**: what `describe_mission` already gives, plus late activation, uncontrolled, frequency,
  country, hidden flags, and the group task.
- Per **group**: the **route** — waypoints in order with type, action, position, altitude, speed, and
  each waypoint's tasks.

Decide before writing:

- **Extend `describe_mission` or add an action?** Extending risks a wall of JSON for a mission with
  three hundred groups, and `describe_mission` is documented as situational awareness before a write.
  A separate action with a **filter** (by group name, by coalition, by category) is probably right —
  but check how the existing callers use `describe_mission` before splitting.
- **Verbosity has a cost the caller pays.** A full Foothold mission has thousands of units; returning
  everything unfiltered would blow an agent's context and make the action unusable for the very missions
  that need it most. Whatever the shape, a caller must be able to ask for one flight.

## Tasks

- [ ] Decide and record: extend `describe_mission`, or a new filtered action.
- [ ] Read units with their loadout and pylon layout, from the mission table (no DCS needed).
- [ ] Read each group's route with per-waypoint tasks.
- [ ] Filtering, so one flight can be asked for without the other 299 groups.
- [ ] Catalogue doc updated in the same ticket (lockstep — an action missing from it is invisible).
- [ ] Tests over a fixture `.miz` holding at least: a multi-unit air group with a loadout, a group with
      a route and a waypoint task, and a late-activated group.

## Acceptance criteria

- [ ] Every field tickets 02 and 04 need to mutate can be **read** first.
- [ ] A single flight can be described without dumping the mission.
- [ ] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.
