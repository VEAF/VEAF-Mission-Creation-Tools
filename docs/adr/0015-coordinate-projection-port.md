---
status: accepted
---

# Design-time DCS coordinate projection: pure-Python TM, constants vendored from VEAF/dcs-maps

The mission-editing MCP and `veaf-tools` place things by DCS local coordinates (`x`/`y`, metres in
each theatre's own projection), but a Mission Maker thinks in lat/long off a map. To accept human
coordinates design-time (wave 10 of [FEAT-MCP-MISSION-EDITOR](../../.backlog/archive/FEAT-MCP-MISSION-EDITOR.md)),
we need `lat/lon ↔ x/y` **without a running DCS** — the DCS `coord.*` conversions live only in the
in-game Lua runtime, and the repo had no Python projection.

Each theatre uses its own Transverse Mercator (WGS84) projection: a central meridian plus false
easting/northing offsets. Deriving and validating those constants from scratch is error-prone.

**Decision.** Keep a **thin pure-Python** Transverse Mercator forward/inverse in
`veaf_libs/coordinates.py` (WGS84 series; maths lineage from `bfr-claude-plugins`' `projection.lua`,
MIT), and **source the per-theatre constants from data**: vendor the export of
[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps) (**MIT**, VEAF-maintained) as
`veaf_libs/data/dcs-maps.yaml`, read at load time for `lon_0`/`x_0`/`y_0`. That export covers **all
DCS theatres** (Caucasus, Syria, PersianGulf, Marianas(+WWII), Normandy, Nevada, SinaiMap,
GermanyCW, Kola, TheChannel, Falklands, Afghanistan, Iraq) with the exact DCS theatre-string keys.
We validated it against the original four (dcs-maps ≡ `projection.lua` to the micron) and reuse the
`projection.lua` reference cases as regression tests.

Data, not code: the valuable, stable part is the per-theatre table, which dcs-maps publishes for
consumption. A light drift note lets us re-sync when Mitch updates it. A short alias map covers
alternate spellings some tooling emits (`Sinai`→`SinaiMap`, `GermanyColdWar`→`GermanyCW`).

**Alternatives rejected.** Depending on / adopting the `dcs-maps-coordinates` **package** — it
pulls `pyproj` + `mgrs` (native C libraries): not on PyPI (git-dep fragility), and `pyproj` is
costly/risky to bundle in our PyInstaller exe, for a gain (MGRS/UTM/PROJ-exactness) we don't need
(our pure-Python matches its lat/lon↔x/y exactly for the placement use case). Also rejected:
hand-maintaining the constants ourselves, or scraping `pydcs` — the VEAF export is the authoritative,
maintained source.

**Accuracy.** Reproduces the reference cases within `< 5e-6°` on lat/lon and `< 0.5 m` on the
`x → lat/lon → x` round-trip.

**Out of scope.** MGRS/UTM (available in dcs-maps if ever wanted); per-theatre bounding boxes
(geocoding bias) stay a separate hand-approximated dataset — a theatre without a box simply gets no
bias.
