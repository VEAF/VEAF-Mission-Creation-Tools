# 03 — Port the four pending in-game checks

Status: 🔄 in-progress
Type: feat
Files: the assertion list from 02, plus status updates on the four lots

Depends on: 02

## Why this ticket is the point of the lot

A harness with no assertions is a framework, not evidence. These four are already written down as
open questions on real lots, and each is currently waiting for a person:

**1. `Disposition` — `FEAT-SCENERY-AWARE-SPAWN` ticket 01 (🧑)**
The richest one, and the reason that lot is not closed. Assertions: does the singleton exist; what is
its exact signature; do the points it returns actually avoid buildings and forests when centred on a
village and on a forest; what does it return centred on dense city with a small radius (the fallback
branch depends on the answer); is it present on a WWII map; what does one call cost.
Outcome either closes ticket 01 or deletes tier 1 of `veaf.findSpawnPoint` — and ADR 0018 stops
saying "asserted, not measured".

**2. Coalition-scoped submenus — `FEAT-COMBATZONE-MENU-COALITION` (🧑 since July)**
Does DCS accept `addSubMenuForCoalition` **under a global parent**? The unit tests pin which API is
called with which arguments; they cannot pin DCS's reaction. A negative answer has a known fallback
(scope the `COMBAT ZONES` parent too), so this is a decision waiting on one fact.

**3. Staggered script loading — `FEAT-CUSTOM-SCRIPT-LOAD-DELAY`'s open question**
Upstream Foothold loads in four waves, the last at 12 s; our build fires all fourteen scripts in one
`triggerStart`. Assertion: load the built Foothold and check `dcs.log` for AIEN / CTLD initialisation
errors. Nothing broken → the lot is a fidelity nicety; something broken → it is a correctness bug for
every adopted mission and jumps the queue.

**4. Guided checklists — `FEAT-ASSIST-CHECKLISTS`**
Already validated, but **by hand, in flight**. Porting even a subset turns a one-off human sign-off
into a regression guard, which matters because that engine reads live cockpit state through
`net.dostring_in` and a DCS patch could break it silently.

## Written 2026-08-05, none of them run

Six checks in `CHECKS`, covering two of the four questions:

- **`Disposition`** (3 checks): does the singleton exist, does `getSimpleZones` exist, and what
  does it return when called. The avoidance itself is not among them — that needs a mission
  placed beside a village, which is ticket 01's outstanding half.
- **Coalition-scoped submenu** (1 check): does DCS accept `addSubMenuForCoalition` under a global
  parent. This is the whole of what `FEAT-COMBATZONE-MENU-COALITION` has been waiting on.
- **Two sanity checks**: that `veaf` and `veaf.findSpawnPoint` are actually loaded, so a stale
  script bundle cannot make every other check vacuously pass.

Writing them surfaced a bug worth recording: the snippets return truthy **sentinel strings**
(`veaf-absent`, `no-singleton`) rather than raising, so an expectation written as a plain
truthiness test passed in exactly the case it existed to catch. A test now sweeps every check
against every sentinel.

**Not done: running them.** Foothold's staggered loading and the guided checklists have no checks
yet either.

## Tasks

- [ ] Assertions added for 1 and 2 — the two lots actually blocked.
- [ ] `Disposition` probe covers all six questions from `FEAT-SCENERY-AWARE-SPAWN` ticket 01, not
      just "does it exist".
- [ ] Run them; **write the measurements into
      [`docs/exploration/TUM-EXPLOIT.md`](../../../docs/exploration/TUM-EXPLOIT.md)**, including
      anything that turns out false. That note has already been corrected once for claiming things
      nobody had measured.
- [ ] Update ADR 0018 from "asserted" to measured, or record the dead end.
- [ ] Move the two 🧑 lots off waiting-human, in whichever direction the facts point.
- [ ] 3 and 4 added if cheap once the runner exists; if not, say so and leave them as open questions
      rather than pretending they are covered.

## Acceptance criteria

- [ ] At least the `Disposition` question is answered **by the harness**, not by a person — that is
      the proof this lot works.
- [ ] Every measurement recorded in the exploration note or the ADR, not only in a PR description.
- [ ] No lot left claiming a status the facts contradict.
