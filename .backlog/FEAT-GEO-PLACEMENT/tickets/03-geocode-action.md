# FEAT-GEO-PLACEMENT-003 — `geocode` MCP action

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_mission_mcp/`, `test/python/veaf_mission_mcp/`

## What to build

A read-only MCP action turning a real-world description into DCS coordinates for the mission's
theatre:

- Input: `query` (place name), `mission_path` (theatre source), optional `bearing`/`distance_km`.
- Flow: geocoder (001) → `{lat,lon}` → optional offset (002) → `coordinates.latlon_to_xy` → `{x,y}`.
- Output: `{lat, lon, xy: {x, y}, display_name, in_theatre_bounds}`.
- **Warns, never fails**, when the hit is outside the theatre bounds (004) or the theatre is
  unsupported by the projection — surfaces it for the caller to sanity-check.

TDD mocks the geocoder; asserts the compose (name → xy), the offset path, and the out-of-bounds warning.

## Acceptance criteria

- [ ] Registered in the catalog; `describe_action` returns its schema.
- [ ] name → xy for a supported theatre (geocoder mocked).
- [ ] `bearing`+`distance_km` shifts the result correctly.
- [ ] Out-of-theatre hit → result with a warning, not an error.

## Blocked by

FEAT-GEO-PLACEMENT-001, 002 (and 004 for the bounds warning).
