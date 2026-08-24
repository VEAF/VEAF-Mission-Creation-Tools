# FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE — every mission from the template ships a bullseye 483 km off

Status: ✅ done

Found on 2026-08-24 while establishing the open questions of
[`FEAT-WAYPOINT-BULLSEYE`](../FEAT-WAYPOINT-BULLSEYE/PRD.md).

## The defect, measured

`src/defaults/mission-folder/src/waypoints.yaml` declares an example waypoint named `BULLSEYE` at fixed
coordinates:

```yaml
  BULLSEYE:
    x: 75869
    y: 48674
```

That file is copied into **every** mission folder `veaf-tools mission prepare` creates, and the waypoints
injector runs as a normal `mission build` step whenever the file is present
(`veaf_tools/commands/build.py:312-320`). So the waypoint is not a dormant example — it is injected.

Measured on the built `test/veaf-tools/smoke-test-mission/missions/SmokeTest_noon.miz`, a **Syria**
mission, by reading the archive rather than the yaml:

| | northing | easting | distance from the injected waypoint |
|---|---|---|---|
| the injected `BULLSEYE` | 75 869 | 48 674 | — |
| the mission's **blue** bullseye | −379 712 | −111 473 | **483 km** |
| the mission's **red** bullseye | −130 663 | 111 865 | 216 km |

The built mission contains exactly **one** waypoint named `BULLSEYE`, and it is the template's. So a
pilot flying it gets a steerpoint labelled BULLSEYE pointing at open country, 483 km from the thing it
claims to be.

Three of the four mission folders in this repository ship the example verbatim —
`smoke-test-mission`, `verify-mission-a`, `verify-mission-c`. Only `demo-mission` trimmed it.

## Why it is worth fixing on its own

[`FEAT-WAYPOINT-BULLSEYE`](../FEAT-WAYPOINT-BULLSEYE/PRD.md) would fix it properly, by injecting the
mission's real bullseye per coalition. But that lot has open design work (where the step sits in the
pipeline, a sub-flag, the #304 coalition rule), and meanwhile the template keeps handing every new
mission a waypoint that lies. This one is a few lines and needs no design.

A waypoint named `BULLSEYE` at arbitrary coordinates is worse than no waypoint: a pilot has no reason to
distrust it, and it is exactly the kind of error nobody reports because it reads as *the mission maker
put it there*.

## Scope

The example must stop being injected while remaining useful as an example. Options, to pick and record:

1. **Comment the block out** and say in the comment that a bullseye must come from the mission (or from
   `FEAT-WAYPOINT-BULLSEYE` once it ships). Cheapest, keeps the shape visible.
2. **Rename it** to something that is not a claim — `EXAMPLE_POINT` — so an injected leftover is
   self-evidently an example rather than a navigation fix.
3. Leave the name and correct the coordinates: **rejected**, there is no correct value for a template
   that does not know its theatre. Recording it so it is not proposed again.

The three mission folders in this repository that carry the example need the same treatment, since two of
them are the missions David flies to verify releases.

## Delivered — 2026-08-24

**Option 2, renamed rather than commented out.** The example teaches the file's shape and is worth
keeping; what had to go was the *claim*. `INITIAL_POINT` and `TARGET` beside it are per-mission choices
and no value for them is wrong — a bullseye is a property the mission already carries, with one correct
value, so naming an example after it asserts something the template cannot know. It is now
`HOLDING_POINT`, which keeps the tutorial's story (hold, run in, target) and claims nothing. The comment
above it says why, so nobody renames it back.

**All four mission folders carried it, not three.** The lot said `demo-mission` had trimmed the example;
reading its file showed the same waypoint at the same coordinates in a shorter shape. All four are
fixed — the three that were byte-identical to the template are back in sync with it, and the demo
mission's own variant renamed in place.

**A guard rather than a corrected file** (`test_default_waypoints_template.py`). The failure was silent
by construction: a pilot has no reason to distrust a steerpoint labelled BULLSEYE, and a mission maker
reads it as something he put there. Four checks — the files parse, no waypoint key or `name:` claims a
bullseye, no flight plan references one, and every plan reference resolves. That last one guards the
rename's own failure mode, which is also silent: a plan pointing at a waypoint that no longer exists
injects nothing and says nothing. Reintroducing the old name fails two of the four.

## Found while fixing it, and fixed here because it is the same lie in the same file

The template's usage notes described a matching priority — *aircraft type first, then category, then
coalition* — that **is not implemented**. `WaypointsManager.get_flight_plan_for` returns the first plan
whose stated criteria all match, so declaration order decides. Its own docstring made the same claim.

The consequence was shipped as an illustration: `all_blue_planes` is declared before `f16_flight_plan`,
a blue F-16C matches both, so the F-16 plan is **dead configuration** in the default template. Both
descriptions now say what the code does, with that example spelled out as the warning.

Whether the priority *should* exist is a behaviour question and not this lot's:
[`FIX-WAYPOINTS-PLAN-PRIORITY`](../FIX-WAYPOINTS-PLAN-PRIORITY/PRD.md).

## Not rebuilt to confirm, and why that is enough

The injected waypoint carried this file's name **and** its exact coordinates, and the file no longer
declares either. A rebuild would restate that; the guard test enforces it on every run. Where a rebuild
*would* be needed is `FEAT-WAYPOINT-BULLSEYE`, which has to prove a *correct* bullseye reaches a flight
plan — that is an assertion about produced content rather than about an absence.

## Definition of done

- [x] The default template no longer injects a waypoint that claims to be a bullseye it is not
- [x] Which option was taken, recorded here — renamed, not commented out
- [x] The mission folders carrying the example brought in line — **four**, not three: the demo mission
      carried it too, in a shorter shape
- [x] A test that the shipped default template does not declare a `BULLSEYE` with hardcoded coordinates
      — the failure mode is silent, so it needs a gate rather than a fixed file
- [x] `poetry run pytest` green
