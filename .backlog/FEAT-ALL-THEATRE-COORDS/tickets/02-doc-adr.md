# FEAT-ALL-THEATRE-COORDS-002 — Doc + ADR 0015 + provenance

Status: ✅ done
Type: docs
Files: `docs/adr/0015-coordinate-projection-port.md`, `doc/developer/mission-editing-mcp.md` (+ `.en.md`), `CHANGELOG.md`, `pyproject.toml`

## What was built

- Amended ADR 0015: source is now the vendored VEAF/dcs-maps export; adopting the
  `dcs-maps-coordinates` package (pyproj/mgrs, not on PyPI, PyInstaller-hostile) is rejected.
- MCP developer doc (FR/EN): coordinates/geocode now cover all DCS theatres via VEAF/dcs-maps.
- CHANGELOG entry; version bump. Provenance kept in the vendored file header + coordinates.py docstring.

## Blocked by

FEAT-ALL-THEATRE-COORDS-001.
