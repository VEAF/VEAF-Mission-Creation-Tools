# CHORE-AIRCRAFT-STAND-TYPES — two stand tables that disagree, and nobody knows which is right

Status: ✅ done

## Outcome — the narrow set was one mission's sample, and it is now widened

Reading 2 was right. `AIRCRAFT_STAND_TYPES` becomes `{68, 72, 104}` — DCS's own `FighterAircraft`
mask (244), *"effectively all spots usable by fixed wing aircraft"*. `100` (SmallSizeFighter) stays
out, deliberately and with the reason recorded.

**Stand census** (3 bundled captures, 6521 stands, 276 airfields): 104 ×3113, 40 ×1010, 72 ×982,
68 ×809, 16 ×324, 100 ×283. **Seven plane-capable airfields carry `72` and no `68`/`104`**, so the
tool refused to place anything on them: Bandar Lengeh, Tunb Island AFB, Tunb Kochak, Bandar-e-Jask,
Lavan Island, Jiroft (Persian Gulf) and Tha'lah (Syria, 16 OpenMed stands). Widening unlocks all
seven and takes usable stands from 3922 to 4904 (+25%).

**Real usage** (VEAF Foothold Caucasus / Syria / Persian Gulf + Open Training Syria, each parked
unit's `parking` resolved against the captures and **confirmed by position**): of 105 parked planes,
104 ×41 (39%), 68 ×35 (33%), **72 ×29 (28%)** — 24 distinct airframes on OpenMed, A-10C, AV8BNA,
F-15ESE and F-14 among them. The original measurement missed this because Caucasus has 46 OpenMed
stands against 850 of 68/104, and because Persian Gulf — where 72 dominates — has **no `68` at all**,
so `{68, 104}` there meant "104 only".

**`100` excluded**: documented by DCS as a tight spot for small airframes, present on 11 Syrian
airfields that *all* already have 68/104 (so it unlocks **zero** airfields), and carrying no
confirmed parked unit in any measured mission. Including it would take an airframe-shaped risk for no
capacity gain. `PLANE_STAND_TYPES` keeps it, because *"can this field park a plane?"* is a different
question from *"may this tool seat one here?"* — the two constants now say so explicitly.

**On the broken probe**: a parked flight is `route.points[0].airdromeId` plus a per-unit `parking`.
Carrier flights carry `helipadId` + `linkUnit` instead and must be excluded — 45 of the 46 parked
groups in the Open Training mission are carrier-based, which is what the earlier "0 parked groups"
probe was tripping over. The probe was then validated by distance: a correctly resolved stand puts
the unit within 0.0 m of its captured position. That check also caught **8 Syria units naming a stand
over 100 m from where they sit** (a stale `parking` after a hand move), which would otherwise have
been reported as three planes parked on helipads.

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

- [x] The measurement is done and **written down with its numbers**, in the module beside the
      constants — the next person must not have to redo it
- [x] A decision: widen, keep, or make it airframe-dependent. Keeping it is a perfectly good
      outcome **provided the reason is recorded** — right now the two tables merely look
      contradictory
- [x] If it changes, the tests that pin unit placement change with it, and the PR says which
      airfields start behaving differently
- [x] If it does not change, the comment on `AIRCRAFT_STAND_TYPES` explains why it is narrower
      than `PLANE_STAND_TYPES`, so the discrepancy stops reading as an oversight

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Measure, then decide](tickets/01-measure-then-decide.md) | chore |

## Out of scope

- `HELICOPTER_STAND_TYPES`. The consistency check run during `FIX-DYNSLOT-PARKING` found **no**
  airbase anywhere in the bundled dumps lacking a helicopter-capable stand, so that half of the
  table has never yet made a difference.
