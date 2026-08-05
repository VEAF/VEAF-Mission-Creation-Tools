# Lot FEAT-GEO-PLACEMENT — place things by real-world geography

Status: ✅ done (001-005 implemented; geocode action + pluggable geocoder OSM/Google + offset + theatre bounds + doc. Pending PR.)

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
| FEAT-GEO-PLACEMENT-001 | **Pluggable geocoder** — `veaf_libs/geocoding.py`: a `Geocoder` abstraction with an **OSM Nominatim** backend (HTTP, honouring the usage policy: descriptive User-Agent, timeout; optional per-theatre bounding box to disambiguate) and a **Google Maps** backend used when an API key is configured. Returns `{lat, lon, display_name}`. Network isolated behind one seam; TDD mocks HTTP. | `veaf_libs/geocoding.py`, `pyproject.toml` (if a dep is added), `test/python/` | feat | ✅ |
| FEAT-GEO-PLACEMENT-002 | **Geodesic offset helper** — in `veaf_libs/coordinates.py` (or a sibling): `offset_latlon(lat, lon, bearing_deg, distance_m)` (direct geodesic / great-circle destination) so "10 km north of X" resolves. TDD against known bearings/distances. | `veaf_libs/coordinates.py`, `test/python/` | feat | ✅ |
| FEAT-GEO-PLACEMENT-003 | **`geocode` MCP action** — name (+ mission path for the theatre, optional `bearing`/`distance_km`) → `{lat, lon, xy: {x, y}, display_name, in_theatre_bounds?}`. Composes geocoder + `coordinates` + offset. Warns (does not fail) when the hit falls outside the theatre's rough bounds. Read-only. | `veaf_mission_mcp/`, `test/python/` | feat | ✅ |
| FEAT-GEO-PLACEMENT-004 | **Theatre bounding boxes (data)** — per-theatre lat/lon bounds under `veaf_libs/data/` to bias/validate geocoder results (avoid the wrong "Batumi" worldwide) and power the `in_theatre_bounds` warning. Seed the supported theatres. | `veaf_libs/data/theatre-bounds.yaml`, `veaf_libs/`, `test/python/` | feat | ✅ |
| FEAT-GEO-PLACEMENT-005 | **Doc + catalogue + skill + config** — document the geocoder (backends, OSM policy/attribution, how to set a Google key), the `geocode` action, the approximate/confirm-visually caveat and the vague-terrain limit; CHANGELOG; bump. | `doc/`, `plugin/skills/`, `CHANGELOG.md`, `pyproject.toml` | docs | ✅ |

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

---

## FEAT-GEO-PLACEMENT-001 — Pluggable geocoder (OSM default, Google optional)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/geocoding.py`, `pyproject.toml` (only if a dep is needed), `test/python/veaf_libs/test_geocoding.py`

### What to build

A geocoder abstraction resolving a real place name to coordinates, backend-swappable:

- `Geocoder` protocol/base with `geocode(query, *, bounds=None) -> GeocodeResult | None`
  (`{lat, lon, display_name}`).
- **OSM Nominatim** backend (default): HTTP via `requests`, honouring the usage policy — descriptive
  `User-Agent`, timeout, optional `viewbox`+`bounded` from a theatre bounding box to disambiguate.
- **Google Maps** backend: used when an API key is configured (env/config); same interface.
- A factory picking the backend from config (default OSM).

Network sits behind one seam; TDD mocks the HTTP call (no live network in tests). Cover: a hit, a
miss (None), bounds passed through, backend selection by config.

### Acceptance criteria

- [ ] OSM backend builds the right request (query, format, User-Agent, viewbox when bounds given).
- [ ] Google backend used only when a key is present; OSM otherwise.
- [ ] Miss → None (no exception); HTTP error surfaced clearly.
- [ ] ruff + mypy clean (new module typed).

---

## FEAT-GEO-PLACEMENT-002 — Geodesic offset helper

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/coordinates.py`, `test/python/veaf_libs/test_coordinates.py`

### What to build

`offset_latlon(lat, lon, bearing_deg, distance_m) -> (lat, lon)` — the direct-geodesic (great-circle
destination) computation, so "10 km north of X" resolves: geocode X → offset → `latlon_to_xy`.

### Acceptance criteria

- [ ] Due-north / due-east offsets land at the expected lat/lon within a tight tolerance.
- [ ] Round-trips sensibly (offset then reverse bearing ≈ origin).
- [ ] ruff + mypy clean.

---

## FEAT-GEO-PLACEMENT-003 — `geocode` MCP action

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/veaf_mission_mcp/`

### What to build

A read-only MCP action turning a real-world description into DCS coordinates for the mission's
theatre:

- Input: `query` (place name), `mission_path` (theatre source), optional `bearing`/`distance_km`.
- Flow: geocoder (001) → `{lat,lon}` → optional offset (002) → `coordinates.latlon_to_xy` → `{x,y}`.
- Output: `{lat, lon, xy: {x, y}, display_name, in_theatre_bounds}`.
- **Warns, never fails**, when the hit is outside the theatre bounds (004) or the theatre is
  unsupported by the projection — surfaces it for the caller to sanity-check.

TDD mocks the geocoder; asserts the compose (name → xy), the offset path, and the out-of-bounds warning.

### Acceptance criteria

- [ ] Registered in the catalog; `describe_action` returns its schema.
- [ ] name → xy for a supported theatre (geocoder mocked).
- [ ] `bearing`+`distance_km` shifts the result correctly.
- [ ] Out-of-theatre hit → result with a warning, not an error.

### Blocked by

FEAT-GEO-PLACEMENT-001, 002 (and 004 for the bounds warning).

---

## FEAT-GEO-PLACEMENT-004 — Theatre bounding boxes (data)

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/theatre-bounds.yaml`, `src/python/veaf-tools/veaf_libs/`, `test/python/`

### What to build

Per-theatre lat/lon bounding boxes (`min_lat/max_lat/min_lon/max_lon`) as bundled data, to:

1. bias/disambiguate geocoder results (pass as Nominatim `viewbox`), avoiding the wrong "Batumi"
   elsewhere in the world;
2. power the `in_theatre_bounds` warning in the `geocode` action.

Seed the supported theatres (caucasus, syria, persiangulf, marianaislands …). A small accessor
`theatre_bounds(name)` (case-insensitive).

### Acceptance criteria

- [ ] `theatre_bounds("caucasus")` returns a sane box containing Batumi/Poti.
- [ ] Unknown theatre → None (caller degrades gracefully, no bounds bias).
- [ ] ruff + mypy clean.

---

## FEAT-GEO-PLACEMENT-005 — Doc + catalogue + skill + config

Status: ✅ done
Type: docs
Files: `doc/`, `plugin/skills/veaf-mission-authoring/SKILL.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (+ `.en.md`), `CHANGELOG.md`, `pyproject.toml`

### What to build

- Document the geocoder: backends (OSM default, Google via key), the **OSM usage policy +
  attribution**, and how to configure a Google API key.
- Catalogue + developer doc: the `geocode` action, place-by-name usage, and the **honest caveats**
  (approximate/confirm-visually; vague unnamed terrain not covered).
- Skill: when the user gives a real-world description, use `geocode` (with bearing/distance for
  "N km from X"), then place with the resulting `xy`; always surface the resolved point.
- CHANGELOG; version bump.

### Acceptance criteria

- [ ] FR + EN docs in sync; attribution + key-config documented.
- [ ] Skill guides place-by-name and surfacing the resolved coordinates.
- [ ] CHANGELOG entry; version bumped.

### Blocked by

FEAT-GEO-PLACEMENT-001..004.
