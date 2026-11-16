# 15 — Demolition team: sappers who blow up a factory

Status: ⬜ ready

PRD row "Demolition team"; analysis note 07 §10. Needs ticket 11: only a factory has buildings to blow up.

## What

- A CTLD 2 troop template, `dynamic.demolition.troops` ("Sappers"), deployed by the players' side, walks to the nearest enemy factory with a building standing within `demolition.range` (5 km) of where it was dropped.
- When it reaches the buildings (within 200 m of their cluster) it **plants its charges** on every standing building of the zone, is told so, and walks back to its drop point.
- After `demolition.fuse` (120 s) the charges blow: an explosion on each building, strong enough for its life. A team killed before planting plants nothing; once planted, the charges blow anyway.
- Each building destroyed this way pays `economy.demolition` (50) credits, and the factory produces less (ticket 12).
- No enemy factory in range: the team says so and stays where it is, as the spy team does.

## Simplified from Foothold

Foothold's team walks from building to building and plans an escape route out of each blast. Here the factory's buildings stand in one cluster 60 m apart (ticket 11), the team plants on reaching it and is 600 m away when the fuse ends (120 s at 5 m/s), which is what keeps it out of the blasts. To be checked in game.

## Done when

Lua tests: the team is sent to the nearest factory in range and no further; plants on arrival, walks back; the charges blow after the fuse; the credits per building; no target told.
