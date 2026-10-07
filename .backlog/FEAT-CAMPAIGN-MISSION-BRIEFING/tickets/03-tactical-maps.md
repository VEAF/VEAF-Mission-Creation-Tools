# 03 — The tactical map and one zoom per objective

Status: ⬜ ready

On the OpenStreetMap base of `veaf_libs/map_tiles.py`:

- **tactical map**: zones in their owner's colour, axes, QRA zones dashed, the carrier, the AWACS orbit, the tanker track, the bullseye, a scale in nm, the credit; framed to hold the support orbits;
- **one zoom per objective** of the coming mission (the zones its tasks name, or the campaign's objectives): the zone at its radius, a scale in km;
- **labels never overlap** each other or a symbol: the prototype needed two rounds to move the QRA label and the bullseye label off Poti's. Share the de-cluttering with [`FEAT-BRIEFING-MAP`](../../FEAT-BRIEFING-MAP/PRD.md).
- Nothing the intelligence does not know: no garrison unit.

## Done when

Tests render from cached tiles: symbols at the right pixels, no two label boxes intersecting on the fixture campaign, offline rendering still works.
