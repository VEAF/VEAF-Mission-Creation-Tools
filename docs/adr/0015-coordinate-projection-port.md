---
status: accepted
---

# Design-time DCS coordinate projection: copy `projection.lua` into Python

The mission-editing MCP and `veaf-tools` place things by DCS local coordinates (`x`/`y`, metres in
each theatre's own projection), but a Mission Maker thinks in lat/long off a map. To accept human
coordinates design-time (wave 10 of [FEAT-MCP-MISSION-EDITOR](../../.backlog/FEAT-MCP-MISSION-EDITOR/PRD.md)),
we need `lat/lon ↔ x/y` **without a running DCS** — the DCS `coord.*` conversions live only in the
in-game Lua runtime, and the repo had no Python projection.

Each theatre uses its own Transverse Mercator (WGS84) projection: a central meridian plus false
easting/northing offsets. Deriving and validating those constants from scratch is error-prone.

**Decision.** We **copy** an existing, tested implementation into Python
(`veaf_libs/coordinates.py`) rather than derive our own or add a heavy dependency: the
`projection.lua` from
`bfr-claude-plugins/plugins/dcs-mission-tools/tools/src/lib/projection.lua` (**MIT**, BFR code —
not itself a third-party port). It carries the hard part — the WGS84 TM forward/inverse **and** the
per-theatre origin tables for **caucasus, syria, persiangulf, marianaislands** — and ships five
reference cases `(theatre, x, y, lat, lon)` we reuse verbatim as Python tests.

VEAF is Apache-2.0; MIT is compatible. We keep a short attribution header on the copied module (no
separate NOTICE — the header is the attribution). This is a **copy**, not a shared upstream: no
drift-tracking, no vendoring machinery. New theatres are added as pure data (their origin
constants) as they are captured — never fabricated.

**Alternatives rejected.** Depending on `pydcs` (a large mission-manipulation library whose model
overlaps our own) just for its projections; and deriving the TM constants ourselves (needless risk
when a tested, license-compatible implementation exists in the family of projects).

**Accuracy.** The port reproduces the source's reference cases within its tolerances — `< 5e-6°`
on lat/lon and `< 0.5 m` on the `x → lat/lon → x` round-trip.
