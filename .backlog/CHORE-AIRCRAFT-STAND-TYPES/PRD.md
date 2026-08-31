# CHORE-AIRCRAFT-STAND-TYPES — two stand tables that disagree, and nobody knows which is right

Status: ⬜ ready

Origin: noticed while delivering `FIX-DYNSLOT-PARKING` (PR #860), which added the second table.

## The situation

`veaf_libs/dcs_parking.py` now holds two sets that answer neighbouring questions and do not agree:

| Constant | Values | Question it answers | Where it comes from |
|---|---|---|---|
| `AIRCRAFT_STAND_TYPES` | `68`, `104` | which stands this tool is willing to **seat** a unit on | measured on Caucasus: `test.miz`'s parked flights sit on 104 (×71) and 68 (×13), and on nothing else |
| `PLANE_STAND_TYPES` | `68`, `72`, `100`, `104` | which stands a fixed-wing aircraft **can use** | DCS's `Airbase.TerminalType`, sourced from two independent references that agree value for value |

So `72` (OpenMed) and `100` (SmallSizeFighter) are documented as fixed-wing stands, and the tool
refuses to place a unit on them.

## The question, and why it is open

Two readings, and this lot exists to decide between them rather than assume:

1. **The narrow set is right.** It reflects where DCS and mission makers actually park aircraft;
   72 and 100 may be usable in principle but unsuitable in practice (too tight for most airframes,
   awkward taxi routes), and widening would place units where they get stuck or clip.
2. **The narrow set is too narrow.** It came from *one* mission on *one* theatre. Airfields whose
   stands are mostly 72/100 would be unusable for placement today, for no reason.

**Neither is established.** An attempt to settle it by walking real missions for parked aircraft
and resolving their `parking` index against the stand table returned nothing — the probe failed to
identify parked groups at all, so it measured nothing rather than measuring zero. Do not take that
as evidence; build the measurement properly.

## What would settle it

- Across the three bundled theatres: how many stands of each type exist, and **how many airfields
  would gain or lose** placement capacity if the set were widened. An airfield with no 68/104 at
  all is the case that proves the narrow set harmful.
- In real missions (the VEAF Foothold repositories under `D:\dev\_VEAF\VEAF-Foothold-*` and
  `D:\dev\_VEAF\tmp\VEAF-Open-Training-Mission-Syria`, **read-only**): where are parked aircraft
  actually placed? Resolve each parked unit's `parking` against the bundled stand table.
- If widening looks right, whether it should apply to every aircraft or depend on the airframe —
  `SmallSizeFighter` is named for a reason, and a C-130 on a small fighter stand is a defect.

## Definition of done

- [ ] The measurement is done and **written down with its numbers**, in the module beside the
      constants — the next person must not have to redo it
- [ ] A decision: widen, keep, or make it airframe-dependent. Keeping it is a perfectly good
      outcome **provided the reason is recorded** — right now the two tables merely look
      contradictory
- [ ] If it changes, the tests that pin unit placement change with it, and the PR says which
      airfields start behaving differently
- [ ] If it does not change, the comment on `AIRCRAFT_STAND_TYPES` explains why it is narrower
      than `PLANE_STAND_TYPES`, so the discrepancy stops reading as an oversight

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Measure, then decide](tickets/01-measure-then-decide.md) | chore |

## Out of scope

- `HELICOPTER_STAND_TYPES`. The consistency check run during `FIX-DYNSLOT-PARKING` found **no**
  airbase anywhere in the bundled dumps lacking a helicopter-capable stand, so that half of the
  table has never yet made a difference.
