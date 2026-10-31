# 01 — The wind model as a veaf-tools brick

Status: ⬜ ready

`veaf_libs/dcs_wind.py` carries DCS's static-weather wind model (PRD D1), ported from the whitepaper's `dcs_wind.py`, typed, Google docstrings, `-> ReturnType` everywhere:

- a. **The base wind at a point**: `base_wind(setting, altitude_msl, height_agl) -> WindVector` — the three levels (0, 2,000, 8,000 m), the `exp(−s⁴)` blend, the ground factor `(h / 500)^p` with its polynomial in altitude.
  `setting` is the `.miz`'s `weather.wind` table (`dir` = where the wind blows **to**); the result converts to "from" degrees true and knots, the way a METAR says it, in one function the other tickets share.
- b. **The profile above a place**: `wind_profile(setting, ground_msl, heights_agl) -> list[LayerWind]`, and the strongest wind between two heights above the ground with the height it occurs at (ticket 04's helicopter rule, ticket 06's ATIS line computed the same way).
- c. **The inversion** (PRD D2, D3): `setting_for_surface_wind(wanted_from_deg, wanted_knots, ground_msl, *, at2000_ratio=2.2, veer_deg=20, at8000_offset_mps=3) -> setting` returns the three layers whose simulated wind at 10 m above `ground_msl` is the wanted one.
  With `at2000` a fixed multiple of `atGround`, rotated by a fixed angle, the 10 m wind is `atGround` multiplied by a constant complex factor: the inversion divides by it, no iteration.
  It refuses a veer outside 0-30° and a ratio under 2.141 (`45^0.2`) with a `ValueError` naming the jet or the dip it would make; explicit layers go through `base_wind`, not through this function.
- d. **Airfield altitudes**: the inversion needs the reference airfield's altitude, and `data/airdrome-positions.yaml` has only `name`, `id`, `lat`, `lon`.
  Add `elevation` (m) to it from the same sources (`veaf-build update-dcs-data --airdromes`: the `dcs-world-schema` database, or `Airbase:getPoint().y` from the runtime dump for a theatre the schema lacks), and expose it through `airfields_for_theatre`.
  Check first that the schema carries it; if it does not, the runtime dump does, for every theatre the dumps cover.
- e. **The model's version** is a constant (`MODEL_DCS_VERSION = "2.9.31.29434"`) quoted by every report that uses the model, so a reader knows which DCS the figures hold for.

Done when:

- the five runs of `docs/whitepapers/dcs-wind-model/data/` replay through `base_wind` within **0.001 m/s** on every point (the whitepaper got 0.0003; the runs are rounded to 10⁻⁵), read in place by the tests — this needs [VEAF/VEAF-Mission-Creation-Tools#1227](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1227) merged into `develop` first;
- the inversion round-trips: for a sample of altitudes (0, 262, 1,000, 2,000 m), speeds and veers, `base_wind` of the returned setting at 10 m gives back the wanted wind within 0.1 kt;
- the Rosh Pina figures of the PRD come out (ground 5 m/s, `at2000` 7 then 11 m/s: 13 / 20 / 19 / 16 then 13 / 20 / 21 / 21 kt);
- `airfields_for_theatre("Syria")` gives Rosh Pina at about 262 m;
- mypy, ruff and the coverage gate pass (the gate is bumped per CLAUDE.md §3).
