# 13 — The supply network: hop by hop, depots at half time

Status: 🧑 waiting-human — built and tested outside DCS in #1282 (2026-11-16); the in-game check of the test mission is David's

PRD row "Resources for the AI", supply network (David, 2026-11-16); analysis note 07 §26–§28.

## What

A side's factories feed its zones along the campaign's connections, hop by hop, each hop taking time.

- **Every zone relays** (David, 2026-11-16), but only through zones of the same side: an enemy or neutral zone cuts the path.
- **A segment takes `network.hop_seconds`** (600 s, T); **a segment that touches a depot takes T/2**: factory → base → base is 2T, factory → depot → base is T/2 + T/2 = T.
- **Sources**: a factory of the side with a building standing; a depot of the side with something in its **store**. A depot's store holds `network.depot_store` (4) deliveries; it is full again whenever a factory of the side reaches it, and each delivery that starts from it takes one. So a depot cut from its factories keeps feeding the zones around it for a while — it "stores part of the production" — and runs dry.
- **A zone's supply delay** is the shortest time from any source (several sources at once, Dijkstra over ≤ 100 zones, recomputed when a zone changes hands).
- **Reinforcement by the network**, for the sides listed in `supply` (the enemy by default, as V1's AI helicopters): a damaged zone of the side, with no delivery already on its way, orders one; its first damaged group's dead units are paid from the side's resources (ticket 12) at the order, and come back after the zone's delay. `network.max_deliveries` (3) per side on their way at once. A zone that changed hands meanwhile receives nothing (the points are lost on the road).
- **Cut off**: a zone no source reaches is still fed, from the side's background production, after `network.isolated_seconds` (3600 s). So a side that has lost every factory can just about defend a base (PRD), and a detour is later, so less: one delivery at a time per zone.

Decided here: the players' side is not reinforced by the network unless `supply` lists it — it reinforces its zones with its crates, troops and helicopters, which an automatic repair would make pointless.
Interpretation to confirm with David: the PRD says a depot "stores part of the production"; with one stock of points per side, the store is read as the number of deliveries a depot can still start once cut from its factories.

## Seen by the players

Campaign → Logistics → Supply network: each zone of the side, with its delay in minutes or "cut off", and what is on its way.
Admins: the resources of both sides and the deliveries under way, in the self-check.

## Done when

Lua tests: delays on a chain with and without a depot (2T, T); an enemy zone cuts the path, the detour is taken; a depot's store feeds, empties, refills; a delivery ordered, paid, applied after its delay, lost if the zone changed hands; the cap; the cut-off delay.
