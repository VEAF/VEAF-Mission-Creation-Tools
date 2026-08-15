# 04 — Route and waypoint task editing

Status: ✅ done 2026-08-12 — shipped as `edit_route`; the named task set is seven tasks, each signature read out of a real mission
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

## What `FIX-WAYPOINTS-ETA-LOCKED` concluded, and why it shaped the whole module

The ticket said to check before touching a timing field. It concluded something stronger than
"delicate": **DCS refuses to save a mission whose route has no waypoint with a locked time**, with the
error *"Route has no waypoints with locked time!"*, and its own repair is to lock the first waypoint.

That turns route editing from a list operation into surgery, because **removing or reordering can take
out the only locked waypoint** — and the failure surfaces in the editor, on a different day, naming the
route rather than the edit. So every operation restores the invariant and says so when it had to. The
lock is *at least one*, not *the first*: an authored lock further down the route survives.

## The task set, and the three traps measured inside it

Seven tasks, chosen from what real missions actually carry (counted across the fixtures: `Orbit` 169,
`Land` 184, `EngageTargets` 152, `EngageTargetsInZone` 109, `GoToWaypoint` 82, `Escort` 23,
`Bombing` 13): **orbit, land, attack_group, bombing, engage_targets_in_zone, set_frequency,
switch_waypoint**. An unknown name is refused naming the set — the escape hatch starts closed, exactly
as the ticket asked.

Three signatures are traps a generic writer walks into:

- **`SetFrequency` takes hertz** — `31000000` for 31 MHz — while a *group's* frequency (ticket 03) is
  in MHz. Two units for the same notion in one file. The action takes MHz and converts.
- **`EngageTargetsInZone` stores its target list twice**: a `targetTypes` array *and* a serialised
  `value` string (`"Air;Cruise missiles;"`). Writing only the array leaves the mission carrying two
  versions of the same decision, so both come from the one list the caller gave.
- **`SetFrequency` and `SwitchWaypoint` are not tasks but *actions***, carried inside a `WrappedAction`
  envelope. Written as bare tasks, DCS ignores them in silence.

Two more things measurement added that the ticket did not foresee: a waypoint's `type` and `action` are
a **pair** (`Land` goes with `Landing`), so setting one alone produces a point the editor shows and DCS
does not fly; and an added waypoint must **inherit** its neighbour's altitude and speed, or it lands at
altitude 0 and the flight dives to reach it.

## Tasks

- [x] Route-level operations on waypoints: add, insert at index, remove, reorder. Removing the **last**
      waypoint is refused — a route with none is not a route.
- [x] Altitude, speed, waypoint type, with the units in the **parameter names** (`altitude_ft`,
      `speed_kt`) rather than only in the description, and both unit systems in the result.
- [x] A named set of waypoint tasks, each validated; an unknown task name is refused naming the set,
      and a missing required parameter is refused naming the parameter.
- [x] Read the current route back — the result carries the resulting route, so an agent sees what it
      just did without a second call.
- [x] Checked what `FIX-WAYPOINTS-ETA-LOCKED` concluded, and made its invariant the module's spine.
- [x] Mission-maker catalogue doc updated in this ticket, plus the developer reference.

## Acceptance criteria

- [ ] 🧑 Round trip through the DCS Mission Editor with no complaint; a flight with an added attack-task
      waypoint **flies it** in game, since the editor accepting a task table is not proof DCS runs it.
      David's to do — no DCS here. Listed in `DCS-SESSION-TODO.md`.
- [x] Tests: each operation, each task, plus the refusal path for an unknown task — 43 cases.
- [x] `ruff` / `mypy` / `pytest` green over the whole tree; coverage gate bumped per the ratchet.
