# FEAT-GEO-PLACEMENT-002 — Geodesic offset helper

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_libs/coordinates.py`, `test/python/veaf_libs/test_coordinates.py`

## What to build

`offset_latlon(lat, lon, bearing_deg, distance_m) -> (lat, lon)` — the direct-geodesic (great-circle
destination) computation, so "10 km north of X" resolves: geocode X → offset → `latlon_to_xy`.

## Acceptance criteria

- [ ] Due-north / due-east offsets land at the expected lat/lon within a tight tolerance.
- [ ] Round-trips sensibly (offset then reverse bearing ≈ origin).
- [ ] ruff + mypy clean.
