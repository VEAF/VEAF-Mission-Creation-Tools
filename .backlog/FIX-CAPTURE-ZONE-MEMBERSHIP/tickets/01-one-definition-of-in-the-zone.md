# 01 — One definition of "in the zone" for the capture and the absorption

Status: ⬜ ready

- The units that took the zone become its garrison: `absorbConvoy` takes the convoy's units among those the capture's own search found, rather than re-measuring with another rule — or both go through one function. Whatever the choice, the capture and the absorption can no longer disagree on a unit.
- Decide, and say in the code, whether "in the zone" keeps `searchObjects`' slack or filters it to the exact radius; if filtered, ticket 02 must bring the convoy inside, or a convoy at the edge would never take the zone.
- Lua tests: a convoy whose units the search returns at 2036–2077 m of a 2000 m zone is absorbed (no `drawGarrison`, no reserve spent); the existing absorption and capture tests still pass.
- `CAMPAIGN.md` / `.en.md` if what "in the zone" means for a capture changes.
