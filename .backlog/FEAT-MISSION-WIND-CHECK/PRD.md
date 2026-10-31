# FEAT-MISSION-WIND-CHECK — set the wind pilots will meet, and say the wind DCS simulates

Status: ⬜ ready

## Why

On 2026-10-31, the objective mission *Marteau du Golan* (Syria), written by Claude through `veaf-mission-editor`, set its ground wind to 9 m/s (17 kt from 270), and its briefing announced "17 kt at the surface, stronger aloft".
Measured in DCS through the bridge (`atmosphere.getWind`): **24 kt at 10 m above Rosh Pina, and 36 kt at 1,000 ft above the ground**.
The helicopter pilots took 35 kt on the nose with no warning.

The same day, a study decoded DCS's static-weather wind model from `Weather.dll` and checked it in game: five runs of 5,392 points each, every one within 0.0003 m/s of the model.
It is written up in the whitepaper `docs/whitepapers/dcs-wind-model.fr.md` / `.en.md`, with the model in `docs/whitepapers/dcs-wind-model/dcs_wind.py` and the five runs in `docs/whitepapers/dcs-wind-model/data/` ([VEAF/VEAF-Mission-Creation-Tools#1227](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/1227)).
In short (DCS 2.9.31.29434):

- three levels in altitude above sea level: 0 m carries `atGround × 45^0.2` (2.141 × the setting), 2,000 m carries `at2000`, 8,000 m carries `at8000`, as they are;
- between two levels, the wind vector blends with the weight `exp(−s⁴)`, which stays near the lower level for half the layer and then swings fast;
- under 500 m above the ground, the vector is multiplied by `(h / 500)^p`, where `p` depends on the point's altitude above sea level (0.195 at sea level, 0.024 above 1,500 m);
- turbulence, temperature and season do not change the base wind.

So the editor's "ground wind" is the 10 m wind only at the sea shore: on an airfield at 250 m it is 1.34 times the setting, at 1,000 m 1.87 times, and between 300 and 600 m above the ground the wind reaches about 2.1 times the setting.

The Lua side is right: `veafWeather.lua` (ATIS, weather report, LASTE) asks `atmosphere.getWind` at the point it describes, and announced 13 kt at Rosh Pina where DCS simulated 13.1.
The Python side is not: everything that writes or describes the weather treats the setting as the wind.

1. **The tools write the setting as if it were the wind.** `DCSWeatherConverter.to_dcs_lua_table` (`weather_injector/weather/dcs_weather_converter.py`) writes the METAR's wind, or the wind given to `set_weather` and to the weather variants, straight into `atGround`, then `at2000 = ground + 2 m/s` and `at8000 = ground + 5 m/s`.
   A METAR of 15 kt at Rosh Pina becomes about 20 kt at 10 m and 32 kt at 1,000 ft above it.
   The `clearsky` cap of 15 kt (`_CLEARSKY_MAX_WIND_MPS`) caps the setting, so a "VFR-friendly" sky still flies above 20 kt on any inland airfield.
   The METAR's gusts (`27015G25KT`) are parsed and dropped.
2. **The tools describe the setting as if it were the wind.** The deck's weather block prints the three set layers (`weather_lines`, `campaign_manager/mission_pages.py`), `inspect_built_mission` prints the set ground layer (`veaf_mission_mcp/inspect_built.py`), and Claude copies the `set_weather` values into the briefing.
3. **The rule meant to protect helicopters speaks of the setting.** The authoring guide and both mission prompts say "wind 10 kt or less at the surface" for helicopter missions; applied to the setting, that gives about 20 kt in the layer helicopters fly in.
4. **`at2000` set below about 2.14 × `atGround` makes a jet in the low layer.** The level at 0 m carries 2.14 × the setting: an `at2000` under that makes the wind peak 300 to 600 m above the ground, then drop.
   Computed above Rosh Pina (262 m), ground set to 5 m/s, wind at 10 m / 1,000 / 2,000 / 3,000 ft above the ground: **13 / 20 / 19 / 16 kt** with `at2000` = 7 m/s (today's `ground + 2`), **13 / 20 / 21 / 21 kt** with `at2000` = 11 m/s.

## What

The model becomes a brick of veaf-tools; everything that writes the weather sets the wind the author asked for, at the place it is asked for; everything that describes the weather says the wind DCS will simulate; and the in-game reports round instead of truncating and tell helicopters about the low layer.

| # | What | Status | Ticket |
|---|---|---|---|
| 01 | The wind model as a standard-library `veaf_libs` brick, shared with the DCSServerBot fork: the base wind at a point, the profile above a place, and two exact inversions (`at2000` proportional, or given) that give the `atGround` for a wanted wind; tested against the five runs of the whitepaper and shared test vectors | ⬜ | [01](tickets/01-wind-model-brick.md) |
| 02 | From a gust to `groundTurbulence` in the shared brick: the gap gust − mean, capped at 2 m/s until the in-game measurement (its own session) gives a table | ⬜ | [02](tickets/02-measure-gusts.md) |
| 03 | Writing the weather: the wanted wind at a reference airfield is inverted into `atGround`, `at2000` defaults to 2.2 × `atGround` veered, `clearsky` caps the simulated wind, gusts feed `groundTurbulence` — for `set_weather`, the weather variants (`inject-weather`) and the METAR conversion | ⬜ | [03](tickets/03-write-the-wanted-wind.md) |
| 04 | Describing the weather: the deck's weather block by layer, `inspect_built_mission`, `set_weather`'s answer, the authoring guide and both mission prompts speak of the simulated wind; the helicopter rule applies to the simulated wind from 0 to 600 m | ⬜ | [04](tickets/04-describe-the-simulated-wind.md) |
| 05 | `veaf-tools dcs mission-check` compares the briefing's wind with the model, without DCS, and warns when helicopters fly into a hard low layer; measuring through the bridge becomes an optional check of the model against the running DCS | ⬜ | [05](tickets/05-mission-check-wind.md) |
| 06 | `veafWeather.lua`: speeds rounded instead of truncated, an ATIS line "max wind 0-2000 ft" for helicopters, gusts as an option | ⬜ | [06](tickets/06-lua-weather-reports.md) |
| 07 | Known limitation, documentation pages, demo mission step, CHANGELOG | ⬜ | [07](tickets/07-docs-and-limitation.md) |

Ticket 01 comes first: 03, 04 and 05 call it.
Ticket 02 feeds the gust part of 03 (item d); neither waits for the in-game measurement, which refines ticket 02's function when it lands.

## Decisions

Taken by David on 2026-10-31 (A to E of the study's brief); the details under them are recommendations, by default.

- **D1 — the model is a brick of veaf-tools, tested on the measured runs (A).**
  `veaf_libs/dcs_wind.py`, typed and documented, is the one place the model lives; Python code never computes a wind otherwise.
  Its tests replay the five runs of `docs/whitepapers/dcs-wind-model/data/` as reference data, read where they are: one copy of the measurement, owned by the whitepaper.
  The whitepaper's `dcs_wind.py` stays as the study left it, a record of how the model was found; the brick is the product.
  The model is written for DCS 2.9.31.29434; the brick names that version, and ticket 05's optional measurement is how a later DCS is checked against it.
  The file is standard-library only and is copied as is by the VEAF fork of DCSServerBot, to correct the `atGround` DCS Real Weather writes on the servers (0.48 × the METAR today, from a single runway elevation of 160 m); shared test vectors keep the two copies honest (ticket 01).
  With a real wind aloft (the servers' open-meteo data), the inversion takes that `at2000` as given rather than the 2.2 × default of D3.
- **D2 — the author sets the wind wanted at a place, the tool computes the setting (B).**
  The wanted wind is the surface wind at a **reference airfield**, 10 m above its ground, as a METAR or an ATIS says it.
  The tool inverts the model at that airfield's altitude to find `atGround`: the 10 m wind is linear in `atGround` once `at2000` is a fixed multiple of it (D3), so the inversion is one division, not a search.
  The reference airfield is, in order: the METAR's station when it is on the mission's map; otherwise an explicit `reference_airfield`; otherwise the mission's first player departure airfield; otherwise sea level, with a warning saying so.
  Its altitude comes from the bundled airfield data (ticket 01 adds it), so the inversion never needs the downloadable elevation grid.
  This holds for `set_weather` (`veaf_mission_mcp/mission_settings.py`), the weather variants of `inject-weather` (`weather_injector/weather_injector_worker.py`) and the METAR conversion (`DCSWeatherConverter.to_dcs_lua_table`), which all go through the converter.
  The `clearsky` cap of 15 kt applies to the wanted wind, hence to the simulated surface wind at the reference airfield.
- **D3 — `at2000` defaults to about 2.2 × `atGround`, veered (C).**
  At 2.2, `at2000` sits just above the 2.141 the 0 m level carries, so the profile only grows with height: no jet at 300-600 m, no drop above it.
  The direction at 2,000 m is the surface direction **veered 20° to the right** by default (the wind turns clockwise with height in the northern hemisphere, which is where every VEAF map but the Falklands lies); a parameter takes 0 to 30°.
  *Why 20 and not more:* computed above Rosh Pina with ground 5 m/s and `at2000` 11 m/s veered 20°, the speed still only grows (7, 10, 11, 11 m/s at 10 m, 1,000, 2,000, 3,000 ft) and the direction turns smoothly from 270 to 290; the blend of two vectors at an angle dips in between, by 0.4 kt at 30°, 1.3 kt at 45° and 6 kt at 90° over the sea (computed, 5 and 11 m/s), and opposite directions make a layer without wind (whitepaper, section 3.3).
  `at8000` keeps today's offset, now from `at2000`: `at2000 + 3 m/s`, same direction — nothing decided it, nothing measured it, and jets cruise above the layer this lot is about.
  `set_weather` and the variants may still set `at2000` and `at8000` explicitly; a value under 2.14 × `atGround` is accepted with a warning naming the jet it makes.
- **D4 — gusts feed `groundTurbulence`: the gap, capped until measured (C, and David on 2026-10-31 for the servers).**
  The METAR's gust group stops being dropped.
  How much `groundTurbulence` makes a 25 kt gust over a 15 kt wind is not known: the whitepaper measured the spread of `getWindWithTurbulence` (RMS 3.2 m/s at 10 m for a turbulence of 60), not a gust.
  The turbulence is the **gap** gust − mean (DCS Real Weather writes the peak, about three times the gap), **capped at 2 m/s** until a measurement says more is flyable; the same rule on the servers and here, in the shared brick (ticket 02).
  The measurement runs in its own session, *Mesure en jeu de la turbulence DCS*, and delivers a table gust gap → `groundTurbulence`; ticket 02's function interpolates it once it lands.
- **D5 — briefing, AI and guide describe the simulated wind (D).**
  The deck's weather block gives the wind by layer above the reference airfield: surface (10 m), 1,000 ft and 3,000 ft above the ground, FL100 and FL250 — the layers a helicopter, a low-level run and a jet each need.
  The layers are named constants in one place.
  The setting appears only where the author edits it (`set_weather`'s answer, `inspect_built_mission`), labelled "set".
- **D6 — the helicopter rule, simulated wind, 0 to 600 m (D).**
  A mission with at least one helicopter slot warns when the simulated wind between 0 and 600 m above a helicopter departure, objective or route point exceeds **20 kt**, or differs from the surface wind there by more than **15 kt**.
  *Source:* the original *Marteau du Golan* (36 kt at 1,000 ft, 24 at the surface) was not flyable on 2026-10-31; one bad point and one target, not a study.
  The thresholds are constants in one place, named in every line that applies them, to revise after the next evening with helicopters.
  The servers apply the same speed as a hard cap on their real weather, on a lower band: **20 kt over 0-1,500 ft above the METAR station**, decided by David on 2026-10-31, through ticket 01's `cap_setting_for_band`.
  Here the rule warns and the author decides, because a mission may want a hard wind on purpose.
  The authoring guide and both mission prompts state the rule in those terms, and drop "10 kt or less at the surface".
- **D7 — `mission-check` judges the briefing against the model; DCS is an optional cross-check (D).**
  Replaces the former D1 ("the measurement is the reference") and D2 ("the model in another lot"), written before the model was known.
  The comparison of the briefing's wind runs without DCS: an agent can run it at authoring time.
  A briefing that contradicts the simulated wind fails the check (exit code 1), like a wrong frequency; a hard wind for helicopters only warns, and fails only when the briefing does not announce it.
  The report gains a warning level (`Line.ok` is `True`, `False` or `None` today) rather than hide the warning among informing lines.
  An announced speed matches within **5 kt** of the simulated range at the layer it names (surface → 10 m; "low level", "aloft" or a height → that height band; a bare figure → surface), a direction within **30°**; a wind mentioned without a figure is listed, not judged.
  With DCS running the test copy, `--measure-wind` asks `atmosphere.getWind` at the same points through the bridge `mission-check` embeds and fails when the model and DCS differ by more than 0.5 kt: that is how a DCS update that changed `Weather.dll` gets caught.
- **D8 — the in-game reports (E).**
  `veafWeather.lua` rounds speeds to the nearest knot or m/s instead of truncating (`math.floor`), adds to the ATIS a line "max wind 0-2000 ft" giving the strongest wind and its height between the surface and 2,000 ft above the airfield, and may announce gusts by sampling `atmosphere.getWindWithTurbulence`, behind an option off by default.

## Out of scope

- RealWeather on the servers: another repository, studied in another session.
  A mission whose weather the server rewrites (`ICAO_` in the name) flies the server's weather; the tools say so and describe the weather they wrote.
- Dynamic weather (`atmosphere_type = 1`): DCS computes its wind elsewhere (`DynamicAtmosphere::getBaseWind_w`), not studied.
- Measuring and modelling turbulence: the in-game measurement belongs to its own session (D4); this lot only applies its table.

One branch, one PR.
