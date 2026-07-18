# FEAT-GEO-PLACEMENT-004 — Theatre bounding boxes (data)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/theatre-bounds.yaml`, `src/python/veaf-tools/veaf_libs/`, `test/python/`

## What to build

Per-theatre lat/lon bounding boxes (`min_lat/max_lat/min_lon/max_lon`) as bundled data, to:

1. bias/disambiguate geocoder results (pass as Nominatim `viewbox`), avoiding the wrong "Batumi"
   elsewhere in the world;
2. power the `in_theatre_bounds` warning in the `geocode` action.

Seed the supported theatres (caucasus, syria, persiangulf, marianaislands …). A small accessor
`theatre_bounds(name)` (case-insensitive).

## Acceptance criteria

- [ ] `theatre_bounds("caucasus")` returns a sane box containing Batumi/Poti.
- [ ] Unknown theatre → None (caller degrades gracefully, no bounds bias).
- [ ] ruff + mypy clean.
