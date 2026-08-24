# FIX-WAYPOINTS-PLAN-PRIORITY — the flight-plan matching has no priority, and said it did

Status: ⬜ ready

Found on 2026-08-24 while scoping [`FEAT-WAYPOINT-BULLSEYE`](../FEAT-WAYPOINT-BULLSEYE/PRD.md).

## What the code does

`WaypointsManager.get_flight_plan_for` returns the **first** flight plan whose stated criteria all
match, treating the criteria a plan omits as wildcards. Declaration order decides; specificity does not
enter into it.

Its own docstring claimed otherwise — *"Tries to find a plan matching: aircraft_type > category >
coalition > all"* — and so did the shipped template's usage notes. Both are corrected as part of
`FIX-DEFAULT-WAYPOINTS-BOGUS-BULLSEYE`, so what is left here is the behaviour question, not the
description.

## Why it is not merely cosmetic

The shipped default template demonstrated the consequence and nobody noticed:

```yaml
settings:
  all_blue_planes:      # category: plane, coalition: blue
  f16_flight_plan:      # category: plane, coalition: blue, type: F-16C_50
```

A blue F-16C matches both, `all_blue_planes` is declared first, so `f16_flight_plan` is **dead
configuration** — shipped as an illustration of a feature that does not work. Any mission maker who
copies that shape to give one airframe its own plan gets the broad plan instead, silently.

## The decision this lot exists to take

Two defensible answers, and the choice is a product one rather than a technical one:

1. **Implement the priority the docstring promised.** Score each candidate plan by how many criteria it
   states, and take the most specific. Matches what a reader expects and makes `f16_flight_plan` work
   without anyone reordering anything. Changes the behaviour of every existing `waypoints.yaml` whose
   plans overlap — which is the risk, and it is not measurable from here: mission folders live outside
   this repository.
2. **Keep first-match-wins and make it loud.** Warn at build time when a plan can never be reached
   because an earlier one subsumes it. No behaviour change, and the mission maker learns about the
   ordering rule from a message rather than from a flight plan that is missing a waypoint.

Option 2 is the safe one and answers the actual complaint (silence). Option 1 is what the documentation
promised for years. Worth asking David rather than picking.

## Definition of done

- [ ] The choice above taken and recorded here, with its reasoning
- [ ] Whichever it is, a mission whose plans overlap gets a defined and documented outcome
- [ ] `f16_flight_plan` in the shipped template either works or is removed — it may not stay as a dead
      illustration
- [ ] Unit tests for the overlap case, both orders of declaration
- [ ] Documented, both languages
