# FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE — every mission from the template ships a bullseye 483 km off

Status: ⬜ ready

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

## Definition of done

- [ ] The default template no longer injects a waypoint that claims to be a bullseye it is not
- [ ] Which option was taken, recorded here
- [ ] The three mission folders carrying the example brought in line
- [ ] A test that the shipped default template does not declare a `BULLSEYE` with hardcoded coordinates
      — the failure mode is silent, so it needs a gate rather than a fixed file
- [ ] `poetry run pytest` green
