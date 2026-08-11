# 05 — Read the units, loadouts and routes

Status: ✅ done
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

- [x] Decide and record: extend `describe_mission`, or a new filtered action.
- [x] Read units with their loadout and pylon layout, from the mission table (no DCS needed).
- [x] Read each group's route with per-waypoint tasks.
- [x] Filtering, so one flight can be asked for without the other 299 groups.
- [x] Catalogue doc updated in the same ticket (lockstep — an action missing from it is invisible).
- [x] Tests over a fixture `.miz` holding at least: a multi-unit air group with a loadout, a group with
      a route and a waypoint task, and a late-activated group.

## Acceptance criteria

- [x] Every field tickets 02 and 04 need to mutate can be **read** first.
- [x] A single flight can be described without dumping the mission.
- [x] `ruff` / `mypy` / `pytest` green; coverage gate bumped per the ratchet.

## Delivered — 2026-08-11

`describe_units`, a **new action** rather than a bigger `describe_mission`. The decision the ticket
asked for, taken on evidence: `describe_mission` has exactly one caller (the catalogue) and no internal
consumer depends on its shape, but it is *documented* as a light look before a write — and a Foothold
mission is megabytes of detail, so folding this into it would have made both unusable on the missions
that need them most.

### Three shapes, each measured rather than assumed

All three came out of a real mission (Foothold Caucasus 4.4.1, 357 armed units), read before writing
any code.

**1. `pylons` is keyed by pylon number, never positional.** DCS numbers stations and the numbers are
**not contiguous** — a real FA-18C carries 1, 4, 5, 6 and 9. Measured: **170 of 357** armed units have a
gapped layout, and the Lua parser hands *those* back as a dict while it flattens the contiguous ones
into a list. So a reader treating pylons as an ordered list is right about half the time and silently
wrong the rest, which is precisely how the setter in ticket 02 would have hung a weapon on the wrong
station. Two tests pin the gap explicitly (stations 2 and 3 absent, the GBU still on 4).

**2. The editor's auto options are flagged and stripped.** A waypoint task is a `ComboTask` whose
`params.tasks` mixes the authored task with the options the editor writes itself (ROE, radar, formation),
all `auto = true`. Measured across the mission: **1093 automatic entries against 189 authored**. Both are
reported — hiding them would misrepresent the mission — but only authored ones carry their `params`,
because forty option bodies bury the one entry someone put there on purpose.

**3. A cap the caller is told about.** The whole mission is **1.9 MB** of JSON; a single 62-waypoint
group is **18 KB**. Hence `group_name` (matching a fragment, since a mission maker says "Colt"),
`coalition`, `category`, a 50-group default with `matched` and `truncated` in the answer, and
`include_route: false` — which **omits the key** rather than returning `[]`, because "not asked for" is a
different fact from "this group has no route". `include_route` was added *after* measuring the 18 KB, not
guessed up front.

Booleans are returned as booleans: DCS **omits** a key that is false, and a caller reading `null` cannot
tell "off" from "the reader did not look". Same reasoning as the callsign, reported by its readable name
rather than as the index table DCS stores.

### Verified against the real mission, not only the fixture

Run over Foothold Caucasus it reports 189 plane groups, truncation flagged, pylons numbered 1-10 on an
F-14A, callsign `Ford11`, a 62-waypoint route — and the auto/authored split behaves as measured. The
fixture in the test file was then built to hold each of those shapes, including a gapped loadout and an
authored `Bombing` task among the editor's options.

### Lockstep

Catalogued in **both** places the gate names: the mission-maker catalogue (FR + EN, inserted as row 2
beside its sibling with every later row renumbered) and the developer reference (FR + EN). `docs-check`
found the second one — the developer page is enforced against the code, which is how an action stops
being invisible.

32 tests. Coverage 80.81 % against a 79 gate, so the ratchet does not move. Version 6.13.91.

## What this unblocks

Tickets **02** (unit setters) and **04** (route editing) are no longer blind: every field they mutate can
now be read first. The pylon numbering in particular is the contract 02 should be written against —
a setter taking a station number, not a list position.
