# FEAT-GEO-PLACEMENT-001 — Pluggable geocoder (OSM default, Google optional)

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_libs/geocoding.py`, `pyproject.toml` (only if a dep is needed), `test/python/veaf_libs/test_geocoding.py`

## What to build

A geocoder abstraction resolving a real place name to coordinates, backend-swappable:

- `Geocoder` protocol/base with `geocode(query, *, bounds=None) -> GeocodeResult | None`
  (`{lat, lon, display_name}`).
- **OSM Nominatim** backend (default): HTTP via `requests`, honouring the usage policy — descriptive
  `User-Agent`, timeout, optional `viewbox`+`bounded` from a theatre bounding box to disambiguate.
- **Google Maps** backend: used when an API key is configured (env/config); same interface.
- A factory picking the backend from config (default OSM).

Network sits behind one seam; TDD mocks the HTTP call (no live network in tests). Cover: a hit, a
miss (None), bounds passed through, backend selection by config.

## Acceptance criteria

- [ ] OSM backend builds the right request (query, format, User-Agent, viewbox when bounds given).
- [ ] Google backend used only when a key is present; OSM otherwise.
- [ ] Miss → None (no exception); HTTP error surfaced clearly.
- [ ] ruff + mypy clean (new module typed).
