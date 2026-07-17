# Lot FEAT-ALL-THEATRE-COORDS — all DCS theatres for coordinate conversion (source: VEAF/dcs-maps)

Status: ✅ done (implemented; coordinates.py now data-driven over the vendored dcs-maps export — all DCS theatres; pure-Python TM kept, no pyproj. Pending PR.)

Branch: `feature/all-theatre-coords` → PR → `feature/mcp-mission-editor`

## Context

Wave-10 `veaf_libs.coordinates` (used by `geocode` / `resolve_coordinates` / `describe_map`) only
carried **4 theatres** (the constants in `bfr-claude-plugins`' `projection.lua`). David asked to
cover **all DCS theatres**. The blocker was data (per-theatre TM constants), which must not be
fabricated.

David pointed to **[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps)** (Mitch, MIT): a VEAF-
maintained, calibrated source of DCS map projections with a single `exports/maps.yaml` (all
theatres: `lon_0`/`x_0`/`y_0`/`k_0` + proj4, keyed by the exact DCS theatre string). Its Caucasus
constants match ours to the micron.

## Decision (with David)

**Vendor the data, not the code.** Copy `exports/maps.yaml` → `veaf_libs/data/dcs-maps.yaml` and
drive `coordinates.py` from it, keeping our thin pure-Python TM. Rejected depending on / adopting
the `dcs-maps-coordinates` package — it pulls `pyproj`+`mgrs` (native C), isn't on PyPI, and would
bloat/risk our PyInstaller exe, for a gain (MGRS/UTM/PROJ-exactness) we don't need (see [ADR 0015](../../docs/adr/0015-coordinate-projection-port.md)).

## Tickets

| # | Ticket | Type | Status |
|---|--------|------|--------|
| FEAT-ALL-THEATRE-COORDS-001 | **Vendor + data-drive**: vendor `dcs-maps.yaml`; make `coordinates.py` load `lon_0/x_0/y_0` per theatre from it (cached), keyed by the DCS theatre string (lowercased) with a small alias map (`Sinai`→`SinaiMap`, `GermanyColdWar`→`GermanyCW`); keep the pure-Python TM + `offset_latlon`. Tests: the 5 reference cases still pass, `supported_theatres()` ≥ 14, aliases resolve, unknown theatre raises. | feat | ✅ |
| FEAT-ALL-THEATRE-COORDS-002 | **Doc + ADR + provenance**: amend ADR 0015 (source = vendored VEAF/dcs-maps; pyproj-package adoption rejected); note all-theatre coverage in the MCP map/coordinates doc; CHANGELOG; bump. Provenance: the vendored file keeps its upstream header; coordinates.py docstring credits VEAF/dcs-maps (MIT). | docs | ✅ |

## Out of Scope

- MGRS / UTM (available in dcs-maps if ever wanted; still "osef").
- Per-theatre bounding boxes for the new theatres (geocoding bias) — `theatre-bounds.yaml` stays the
  4 hand-approximated boxes; a theatre without a box just gets no viewbox bias / no out-of-bounds
  warning. Extend opportunistically.
- Blank-mission (`theatre-defaults.yaml`) for new theatres — needs real bullseye/map centre, not in
  the projection export; separate follow-up.
