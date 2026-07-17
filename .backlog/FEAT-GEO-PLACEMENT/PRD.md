# Lot FEAT-GEO-PLACEMENT — place things by real-world geography

Status: ⬜ ready

Branch: `feature/geo-placement` → PR → `feature/mcp-mission-editor` (builds on wave-10 `coordinates.py`)

## Context

DCS theatres **are the real world projected** (Caucasus = Georgia/Caucasus, Syria = real Syria, …),
and wave 10's `veaf_libs.coordinates` already bridges DCS `x/y ↔ real-world lat/lon (WGS84)`. So the
missing capability for natural-language placement ("near Batumi", "10 km north of Kobuleti", "the
port of Poti") is a **geocoder**: real place name → lat/lon → (via `coordinates`) DCS `x/y`.

Proven working: real coords of Batumi/Kobuleti/Poti fed through `latlon_to_xy("Caucasus", …)` land
at sane in-map Caucasus coordinates.

**Decision (with David)**: geographic placement is important; use a geocoding API, **pluggable, OSM
Nominatim by default** (free, no key, worldwide towns/POIs; ~1 req/s + attribution), Google Maps
Geocoding optional via an API key. Design a geocoder abstraction so the backend is swappable.

## Scope / honest limits

- **Named places / POIs** (towns, airfields, ports, named features) → supported.
- **Relative** ("N km / bearing from X") → supported via a geodesic offset helper.
- **Vague unnamed terrain** ("the woods", "the valley") → only if the geocoder has a named entity;
  otherwise unsupported — not promised.
- **Precision is approximate**: DCS terrain approximates reality (and some maps are period —
  Normandy 44, Syria pre-war). Good for "near X"; confirm visually. Placement returns the resolved
  coordinates for the caller to sanity-check, never silently.

## Goal

An LLM (or CLI user) can turn a real-world description into DCS coordinates: `geocode("Batumi")` →
`{lat, lon, xy}`, optionally offset by bearing/distance, then place with the existing actions.

## Tickets

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FEAT-GEO-PLACEMENT-001 | **Pluggable geocoder** — `veaf_libs/geocoding.py`: a `Geocoder` abstraction with an **OSM Nominatim** backend (HTTP, honouring the usage policy: descriptive User-Agent, timeout; optional per-theatre bounding box to disambiguate) and a **Google Maps** backend used when an API key is configured. Returns `{lat, lon, display_name}`. Network isolated behind one seam; TDD mocks HTTP. | `veaf_libs/geocoding.py`, `pyproject.toml` (if a dep is added), `test/python/` | feat | ⬜ |
| FEAT-GEO-PLACEMENT-002 | **Geodesic offset helper** — in `veaf_libs/coordinates.py` (or a sibling): `offset_latlon(lat, lon, bearing_deg, distance_m)` (direct geodesic / great-circle destination) so "10 km north of X" resolves. TDD against known bearings/distances. | `veaf_libs/coordinates.py`, `test/python/` | feat | ⬜ |
| FEAT-GEO-PLACEMENT-003 | **`geocode` MCP action** — name (+ mission path for the theatre, optional `bearing`/`distance_km`) → `{lat, lon, xy: {x, y}, display_name, in_theatre_bounds?}`. Composes geocoder + `coordinates` + offset. Warns (does not fail) when the hit falls outside the theatre's rough bounds. Read-only. | `veaf_mission_mcp/`, `test/python/` | feat | ⬜ |
| FEAT-GEO-PLACEMENT-004 | **Theatre bounding boxes (data)** — per-theatre lat/lon bounds under `veaf_libs/data/` to bias/validate geocoder results (avoid the wrong "Batumi" worldwide) and power the `in_theatre_bounds` warning. Seed the supported theatres. | `veaf_libs/data/theatre-bounds.yaml`, `veaf_libs/`, `test/python/` | feat | ⬜ |
| FEAT-GEO-PLACEMENT-005 | **Doc + catalogue + skill + config** — document the geocoder (backends, OSM policy/attribution, how to set a Google key), the `geocode` action, the approximate/confirm-visually caveat and the vague-terrain limit; CHANGELOG; bump. | `doc/`, `plugin/skills/`, `CHANGELOG.md`, `pyproject.toml` | docs | ⬜ |

## Out of Scope

- Placement actions taking a raw `{lat,lon}` (the deferred wave-10 ticket 33) — `geocode`/
  `resolve_coordinates` return `xy` the existing actions already take; no need to touch every action.
- Vague/unnamed terrain features with no geocodable name.
- Metre-accurate fidelity to DCS terrain (results are approximate, caller confirms).
- Offline geocoding / bundling a gazetteer (network call at authoring time is acceptable).

## Open points

- **Which HTTP client / dep**: reuse `requests` (already a dep). Nominatim needs no key; Google
  needs a key read from config/env — decide the config surface in 001/005.
- **Nominatim usage policy**: single low-volume authoring calls are fine; document attribution and
  the User-Agent requirement. Consider a small on-disk cache if usage grows (later).
