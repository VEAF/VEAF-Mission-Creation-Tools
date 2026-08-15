# 03 — A heading set on a flying aircraft does not survive the editor

Status: ⬜ ready
Type: docs
Files: `src/python/veaf-tools/veaf_mission_mcp/unit_properties.py` (the result's warnings), the
mission-maker action catalogue (both languages), tests

## The measurement

`set_unit_properties(heading_deg=275)` on an airborne F-14B wrote `4.7996554` rad, correctly. After a
save in the editor the unit carries `-1.8224863` rad — which is **exactly** `atan2(Δy, Δx)` of its
route's first leg, to the seventh decimal.

So DCS is not corrupting the value: it recomputes an airborne aircraft's heading from where its route
sends it. The write was never wrong; it was irrelevant.

## Not a bug, and that is the point

This is why it is a docs ticket rather than a fix. Refusing the parameter would be wrong — heading is
meaningful on a parked aircraft, on a ground unit, on a ship. What is wrong is a result that says
`heading: from … to 275°` with no hint that the value has a lifetime of one save.

Note the interaction that made this visible: the same round-trip **removed a waypoint**, changing the
first leg. An unchanged route would have left the recomputed heading equal to the original, and the
overwrite would have gone unnoticed.

## What to do

Warn from the action when the heading is set on a unit that is **airborne with a route of two or more
waypoints** — the case where the recalculation applies. Name the reason: the route's first leg
decides, so set the route, not the heading.

Not measured, and therefore not claimed: whether a parked aircraft with a `TakeOffParking` waypoint is
also recomputed. State the warning's scope as what was measured, and leave the rest to a session that
measures it.

## TDD

- The warning fires for an airborne unit whose group has 2+ waypoints.
- It does **not** fire for a ground unit, nor for a single-waypoint group.
- The heading is still written in every case: the warning informs, it does not refuse.

## Acceptance criteria

- [ ] The warning ships, in both locales, scoped to what was measured.
- [ ] The catalogue page says a route beats a heading for an airborne unit.
- [ ] Full Python gate green; coverage ratchet respected.
