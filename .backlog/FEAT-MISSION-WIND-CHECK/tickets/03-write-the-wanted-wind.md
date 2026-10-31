# 03 — Write the wind the author wants, not the setting

Status: ⬜ ready

Every weather the tools write goes through `DCSWeatherConverter.to_dcs_lua_table` (`weather_injector/weather/dcs_weather_converter.py`): `set_weather` (`veaf_mission_mcp/mission_settings.py`), the weather variants of `inject-weather` and of the build (`weather_injector/weather_injector_worker.py`, `_inject_weather`), and the METAR conversion, from a string or from `airport_icao`.
Today it writes the wanted wind into `atGround`, `at2000 = ground + 2`, `at8000 = ground + 5`.
With the brick of ticket 01, it writes the setting that makes DCS simulate the wanted wind (PRD D2, D3):

- a. **The reference airfield.** `to_dcs_lua_table` takes the theatre and a reference airfield, and resolves it in the order of PRD D2: the METAR's station when it is an airfield of the mission's map (ICAO code to airfield: add the code to the bundled airfield data if it is not there, from the same sources as ticket 01 d); otherwise `reference_airfield`; otherwise the mission's first player departure airfield; otherwise sea level, with a warning.
  `set_weather` gains `reference_airfield` (optional); a variant of `versions.yaml` gains `weather.reference_airfield` (optional) — the schema, the validator and the shipped default `src/defaults/mission-folder/` follow (CLAUDE.md §9 item 7, if the default carries a weather block).
  The resolved airfield and its altitude are in the converter's answer and in the build's log line, so the author sees which place the wind was set for.
- b. **The inversion.** The wanted surface wind (METAR, `wind_speed` / `wind_direction`, or the `clearsky`-capped value) goes through `setting_for_surface_wind` at the reference altitude; `at2000` is 2.2 × `atGround` veered 20°, `at8000` is `at2000 + 3 m/s` (PRD D3).
  When `at2000` is given, the inversion with a given `at2000` is used instead (ticket 01 c); a result flagged `reliable = False` (reference airfield high enough for the 2,000 m level to dominate) is written with a warning naming the airfield and the weight of the ground level.
  `set_weather` and the variant's `weather:` mapping gain optional `wind_veer` (0-30°), and `wind_speed_2000` / `wind_direction_2000` / `wind_speed_8000` / `wind_direction_8000` to set the upper layers by hand; an `at2000` under 2.14 × `atGround` is written, with a warning naming the jet in the low layer.
  The METAR the briefing prints (`${METAR}`, `metar_composer.py` for a manual sky, the station's report otherwise) keeps the wanted wind: after this ticket it is also the wind DCS simulates at that airfield, which it was not before.
- c. **`clearsky`.** `cap_clearsky` keeps capping the wanted wind at 15 kt (`_CLEARSKY_MAX_WIND_MPS`); since the wanted wind is now the simulated surface wind at the reference airfield, the cap holds where pilots read it.
  Its docstring says so.
- d. **Gusts**: the METAR's `G` group, parsed today in `_fallback_metar_parsing` and dropped, is kept as `wind_gust`, and a manual weather takes `wind_gust` too; `turbulence_for_gust` (ticket 02: the gap gust − mean, capped at 2 m/s until the measured table lands) gives `groundTurbulence`.
  An explicit `turbulence` given to `set_weather` or a variant wins over the gust.
  A `clearsky` sky drops the gust.
- e. **What the converter answers**: the setting it wrote, the reference airfield, and the simulated wind at that airfield by layer (ticket 01 b, the layers of PRD D5), so `set_weather` and the build can show it (ticket 04).

Done when:

- unit tests on the converter: a METAR `27015KT` with a station of the map gives back 15 kt from 270 at 10 m above that station through `base_wind`; the same METAR at a sea-level airfield and at a 1,000 m airfield write two different `atGround`; a station off the map falls back to the departure airfield, then to sea level with its warning; `clearsky` with a 25 kt METAR gives 15 kt simulated at the reference airfield; explicit upper layers are written as given, with the warning under 2.14 ×;
- `set_weather` and a weather variant are tested through their entry points, not only through the converter;
- `27015G25KT` writes the `groundTurbulence` of `turbulence_for_gust` (20, i.e. 2 m/s, while the cap holds), `27015KT` writes 0;
- the build log names the reference airfield of each variant;
- `weather_injector_worker.py` and `mission_settings.py` stay clean under mypy (neither is in the excluded list today).
