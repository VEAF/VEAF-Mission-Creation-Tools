# 04 — Falling back behind cover

Status: ⬜ ready

- The destination: the nearest blue-held place — a campaign zone it owns, a friendly airbase, a friendly combat zone — reachable by road or off road.
- The route: candidate points sampled away from the threat, kept when `land.isVisible` says terrain masks them from the threat's position, or when a town of `veafCities` lies between; the cheapest masked chain wins, otherwise the shortest way out of the threat's weapons range.
- Bounded work per check, sized from ticket 01's timing.
- Tests on the mocks with a stubbed `land.isVisible`: a ridge on one side makes the route go behind it; no friendly place leaves the convoy out of range and holding.
