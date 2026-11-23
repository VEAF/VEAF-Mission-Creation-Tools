# 04 — AI helicopters capture and resupply zones

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

David, 2026-11-15: as in Foothold, rather than convoys only — convoys would be too slow.
The DCS traps on scripted landings are known (`docs/agents/dcs-runtime-traps.md`: a `Land` waypoint goes to the nearest airfield's parking, a helicopter sent into a forest hovers at its edge); the decision is to try, and to find another way if it does not work.

## How

- `veafAircraftSpawn`'s `transport` job is the one read in game (R24–R28): a `Land` **task** after an approach point, the landing point moved to the nearest clearing. The supply helicopter uses it; nothing is re-implemented.
- Every `dynamic.supply_seconds` (600 s) each side with `dynamic.supply` on looks for a target: first a neutral zone connected to one of its zones, then its most damaged zone.
  The helicopter (`dynamic.helicopter.<side>`, a Mi-8MT for red and a UH-1H for blue by default) starts hot from the source zone — the nearest own zone, its centre's clearing — and lands in the target.
- Landed in a neutral zone, it holds the ground like any landed helicopter: the capture runs, and on completion the helicopter is consumed (removed) and the garrison drawn.
- Landed in a friendly zone, it reinforces it once (ticket 03) and is removed 30 s later.
- At most `dynamic.max_helicopters` (2) per side in flight; one that has not landed after `dynamic.helicopter_timeout` (1 200 s) is removed and counted as failed, so a stuck one does not block the side for ever.
- Each start and each arrival is logged with the distance between the landing point and the zone's centre, the measure the in-game check reads.

## Done when

Lua tests: target choice (neutral first, then damaged), cap, consumed on capture, reinforcement on a friendly landing, timeout.
In game (the decisive test): a red Mi-8 lands in a neutral zone and captures it; a damaged red zone is reinforced by one. If they hover or go to the parking, record the measure in `known-limitations.yaml` and fall back on a convoy for that leg.
