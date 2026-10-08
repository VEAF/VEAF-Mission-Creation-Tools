# 03 — An airfield garrison keeps off the runways

Status: ⬜ ready
Type: fix

## Found

David, 2026-10-08, during the flight: a Patriot on the runway at Batumi (blue), and ground units on the runway at Senaki (red) too.
The Batumi Patriot ECS was blue's only loss of the evening, most likely hit by an aircraft using the runway.

Both garrisons were drawn in game by mission 1 (`drawGarrison`, 19:23:22 UTC: Batumi 55 units, Senaki 45), with the CAS generators, inside the zone's circle around the airfield.

## To do

- Read how `drawGarrison` places a garrison on an airfield zone, and what keeps the CAS generators' groups off a runway elsewhere, if anything.
- Keep every unit of an airfield garrison off the runways and taxiways — DCS gives the runways of an airbase (`Airbase:getRunways()`); a margin either side of the centreline, measured on a real field, not guessed.
- Lua tests on a zone whose circle covers a runway.
- A garrison is drawn once and then reappears from the state file at its recorded positions: decide what a campaign that already holds a unit on a runway does with it (move it at the next mission, or leave it).
- Add the measurement to `known-limitations.yaml` if DCS surprises.

## Done when

No unit of a freshly drawn airfield garrison stands on a runway or a taxiway, checked on Batumi and Senaki.
