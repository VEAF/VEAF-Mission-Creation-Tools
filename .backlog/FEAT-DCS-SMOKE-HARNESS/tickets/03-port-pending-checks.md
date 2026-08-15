# 03 — Port the four pending in-game checks

Status: ✅ done — 2026-08-15 (questions 1 & 2 answered in game; 3 & 4 left as stated open questions)
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

## Run in game — 2026-08-15 (Syria)

Questions 1 and 2 are **answered by the harness**, and the `[]`-drift the ticket body warned about is
resolved:

- **Question 1 — `Disposition`.** Signature measured: `getSimpleZones(centre_vec3, radius_m, arg3, count)`
  → array of `{x, y, course}` 2D points. **Avoidance measured**: centred on the airbase Abu al-Duhur
  (369 scenery objects within 2 km), all 30 returned points were 0 within 10 m of scenery and all on a
  `land` surface. It **returns fewer than requested when clear space is scarce** (150 m → 2, 500 m → 10,
  2000 m/req 50 → 50; desert → 30), so tier 1's fallback is necessary. Cost ~43 ms/call. `arg3` and
  WWII-map presence remain unmeasured. A new **regression check `disposition-avoids-scenery`** encodes
  this (0 of 30 near scenery in a scenery-bearing area) and **passes live**. Note: `FEAT-SCENERY-AWARE-SPAWN`
  had already run its probe on 2026-08-06 (it is archived ✅), but ADR 0018 and TUM-EXPLOIT.md were left
  saying "asserted, not measured" — today reconciles that stale wording with the measurement and adds the
  harness **regression check** the archived probe never left behind.
- **Question 2 — coalition-scoped submenu.** Re-confirmed live (`created`); `FEAT-COMBATZONE-MENU-COALITION`
  was already closed on this.

## Tasks

- [x] Assertions added for 1 and 2 — the two lots actually blocked. (`disposition-avoids-scenery` added;
      the submenu check already existed.)
- [x] `Disposition` probe covers the load-bearing questions — existence, signature, avoidance, short-count
      fallback, cost. (`arg3` meaning and WWII-map presence explicitly left unmeasured.)
- [x] Run them; measurements written into `docs/exploration/TUM-EXPLOIT.md`.
- [x] Update ADR 0018 from "asserted" to measured.
- [x] Reconcile the stale docs — `FEAT-SCENERY-AWARE-SPAWN` was already ✅ (probe 2026-08-06), but
      ADR 0018 / TUM-EXPLOIT still said "asserted"; now measured, with a regression check.
- [ ] 3 (Foothold staggered loading, read `dcs.log`) and 4 (checklists as a regression check) — **not
      done today**; left as open questions rather than pretended covered. Both need a specific mission
      loaded (built Foothold; an assisted cockpit) — a follow-up session.

## Acceptance criteria

- [x] At least the `Disposition` question is answered **by the harness**, not by a person.
- [x] Every measurement recorded in the exploration note and the ADR, not only in a PR description.
- [x] No lot left claiming a status the facts contradict.
