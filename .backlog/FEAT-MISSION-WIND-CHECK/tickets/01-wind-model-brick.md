# 01 — The wind model as a veaf-tools brick, shared with the servers

Status: ⬜ ready

`veaf_libs/dcs_wind.py` carries DCS's static-weather wind model (PRD D1), ported from the whitepaper's `dcs_wind.py`, typed, Google docstrings, `-> ReturnType` everywhere.

It is also the module the VEAF fork of DCSServerBot copies as `extensions/realweather/dcs_wind.py`, to rewrite the `atGround` that DCS Real Weather writes (agreed on 2026-10-31 with the session that studied the servers' real weather; that work lives in the fork, not in this lot).
Hence a contract on the file itself:

- **standard library only** (`math`, `cmath`, `dataclasses`): no veaf logger, no import from the rest of veaf-tools, no YAML; Python 3.10 or later (the fork requires 3.11, the server runs 3.13);
- **no I/O and no logging**: a doubtful result comes back as data (an indicator, a weight), never as a log line;
- **the reference altitude is an argument**: the caller knows its place (the fork, the airfield's true elevation; VMCT, item e);
- the METAR's wind group and any cap (`clearsky` here, 15 m/s on the servers) stay with the caller.

What it holds:

- a. **The base wind at a point**: `base_wind(setting, altitude_msl, height_agl) -> WindVector` — the three levels (0, 2,000, 8,000 m), the `exp(−s⁴)` blend, the ground factor `(h / 500)^p` with its polynomial in altitude.
  `setting` is the `.miz`'s `weather.wind` table (`dir` = where the wind blows **to**); the result converts to "from" degrees true and knots, the way a METAR says it, in one function the other tickets share.
- b. **The profile above a place**: `wind_profile(setting, ground_msl, heights_agl) -> list[LayerWind]`, the strongest wind between two heights above the ground with the height it occurs at (ticket 04's helicopter rule, ticket 06's ATIS line computed the same way), and `surface_wind(setting, ground_msl)`, the wind at 10 m above the ground (`base_wind` at `ground_msl + 10`, height 10), which is what a METAR or an ATIS reports and what the round trip of the inversions checks.
- c. **Two exact inversions**, each one complex division, no iteration.
  The 10 m wind is `W = F · (2.141 · G · (1 − w) + A · w)`, with `G` the `atGround` vector, `A` the `at2000` vector, `w` the blend weight and `F` the ground factor at `ground_msl + 10`:
  - `setting_for_surface_wind(wanted_from_deg, wanted_knots, ground_msl, *, at2000_ratio=2.2, veer_deg=20, at8000_offset_mps=3)`: `at2000` a fixed multiple of `atGround`, rotated (PRD D3) — VMCT's default when no real wind aloft is known; it refuses a veer outside 0-30° and a ratio under 2.141 (`45^0.2`) with a `ValueError` naming the jet or the dip it would make;
  - `ground_setting_for_surface_wind(wanted_from_deg, wanted_knots, ground_msl, at2000)`: `at2000` given — the real wind aloft the servers take from open-meteo, or one the author set — solved as `G = (W / F − A · w) / (2.141 · (1 − w))`.
  Both return the setting **and** the weight `1 − w` of the 0 m level at the reference point.
- d. **The guard on `1 − w`**: at 2,000 m MSL and above, the 0 m level weighs nothing and no `atGround` can give the wanted wind: `ValueError`.
  Between about 1,170 m (`1 − w` = 0.5) and 2,000 m, the inversion with a given `at2000` amplifies any gap between `at2000` and the wanted wind (16 times at 1,500 m, where `1 − w` ≈ 0.06) and can give an absurd `atGround`, even an opposed one: the result carries `reliable = False` below a threshold of `1 − w`, a named constant (0.5 by default), and the caller decides — VMCT warns (ticket 03), the servers keep Real Weather's value.
  Every VEAF airfield of the servers' real-weather missions lies under 500 m (`w` < 0.007); Kabul and Bagram are the cases this guard is for.
- d2. **The cap on a band of heights**: `cap_setting_for_band(setting, ground_msl, max_knots, top_agl)` returns the setting reduced so that the strongest wind between 10 m and `top_agl` above `ground_msl` (b) does not exceed `max_knots`, and says what it reduced.
  It scales `atGround` down (a bisection on its factor: the band maximum grows with it, no closed form once `at2000` is fixed); only when `atGround` at 0 still leaves the band above the cap — terrain high enough for `at2000` to dominate the band — does it scale `at2000` too, flagged in the result.
  The servers cap DCS Real Weather's wind with it: **20 kt over the whole band 0-1,500 ft above the METAR station**, decided by David on 2026-10-31 (a strong wind aloft is accepted).
  For scale, with a neutral `at2000` the band maximum is 2.13 times the 10 m wind at sea level, 1.62 at 231 m and 1.35 at 468 m: the cap leaves about 9, 12 and 15 kt at the surface.
  VMCT does not reduce an author's wind with it: its helicopter rule warns (PRD D6); the cap and the band are the caller's arguments, not constants of the file.
- e. **Airfield altitudes** (VMCT side only, outside the shared file): the inversion needs the reference airfield's altitude, and `data/airdrome-positions.yaml` has only `name`, `id`, `lat`, `lon`.
  Add `elevation` (m) to it from the same sources (`veaf-build update-dcs-data --airdromes`: the `dcs-world-schema` database, or `Airbase:getPoint().y` from the runtime dump for a theatre the schema lacks), and expose it through `airfields_for_theatre`.
  Check first that the schema carries it; if it does not, the runtime dump does, for every theatre the dumps cover.
- f. **The model's version** is a constant of the file (`MODEL_DCS_VERSION = "2.9.31.29434"`), quoted by every report that uses the model.
- g. **Shared test vectors**: `dcs_wind_vectors.json` beside the module — inputs (setting or wanted wind, reference altitude, `at2000` when given) and expected outputs (`atGround`, the 10 m wind, `1 − w`, `reliable`) — replayed by this repository's tests and by the fork's, so a copy that drifts from the other fails.
  It includes the measured case of the servers: OMAA, ground 13 m, METAR 320/11 kt, `at2000` 2.65 m/s blowing to 227° → `atGround` **5.58 m/s** blowing to 140° (Real Weather writes 2.74 today), giving back 11.0 kt from 320 at 10 m; plus a high-terrain case on each side of the `reliable` threshold, one at 2,000 m for the `ValueError`, and band caps at sea level, 231 m and 468 m (20 kt over 0-1,500 ft) with one high enough to reduce `at2000`.

Done when:

- the five runs of `docs/whitepapers/dcs-wind-model/data/` replay through `base_wind` within **0.001 m/s** on every point (the whitepaper got 0.0003; the runs are rounded to 10⁻⁵), read in place by the tests — this needs [VEAF/VEAF-Mission-Creation-Tools#1227](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1227) merged into `develop` first;
- both inversions round-trip through `surface_wind` within 0.1 kt for a sample of altitudes (0, 262, 1,000 m), speeds and veers, and every case of `dcs_wind_vectors.json` passes;
- the Rosh Pina figures of the PRD come out (ground 5 m/s, `at2000` 7 then 11 m/s: 13 / 20 / 19 / 16 then 13 / 20 / 21 / 21 kt);
- a test asserts the module imports nothing outside the standard library, so the fork can keep copying it;
- `airfields_for_theatre("Syria")` gives Rosh Pina at about 262 m;
- mypy, ruff and the coverage gate pass (the gate is bumped per CLAUDE.md §3).
