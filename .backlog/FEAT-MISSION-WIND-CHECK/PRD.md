# FEAT-MISSION-WIND-CHECK — check the wind a mission announces against the wind DCS simulates

Status: ⬜ ready

## Why

On 2026-10-31, the objective mission *Marteau du Golan* (Syria), written by Claude through `veaf-mission-editor`, set its ground wind to 9 m/s (17 kt from 270), and its briefing announced "17 kt at the surface, stronger aloft".
Measured in DCS through the bridge (`atmosphere.getWind`): **24 kt at 10 m above Rosh Pina, and 34 to 37 kt between 150 and 600 m above the ground**.
DCS roughly doubles the set ground wind in that layer, then brings it back down towards the `at2000` value.
The helicopter pilots took 35 kt on the nose with no warning.
The mission was fixed by hand: ground wind 5 m/s and `at2000` 8 m/s, which gives 10 to 17 kt at the surface depending on the terrain's height and 18 to 20 kt in the low layer, and a briefing rewritten with the measured values.

Two faults, both in the authoring path and not in the mission:

1. **The briefing copies the setting.** Claude writes the `atGround` / `at2000` / `at8000` it set (`set_weather`, or the values the build reads back in the `.miz`) as "the wind", and nothing tells it the simulation differs.
   The tools do the same: the deck's weather block prints the three set layers as the wind (`weather_lines`, `campaign_manager/mission_pages.py`), and `inspect_built_mission` the ground one (`inspect_built.py`).
2. **The rule meant to protect helicopters speaks of the setting.** The authoring guide and both mission prompts say "wind 10 kt or less at the surface" for helicopter missions.
   Applied to the setting, that rule gives about 20 kt in the layer helicopters fly in — the measurement above is the rule's own outcome at 17 kt.

`set_weather` adds to it: it writes `at2000 = ground + 2 m/s` and `at8000 = ground + 5 m/s` (`dcs_weather_converter.py`), so the author never sees the layer values at all.

## What

A wind check in the verification that follows the build, with the measurement as its reference:

| # | What | Status | Ticket |
|---|---|---|---|
| 01 | `veaf-tools dcs mission-check` measures the simulated wind above the places the mission flies (departures, objectives, helicopter routes), at fixed heights above the ground, and writes the measurement next to the test copy | ⬜ | [01](tickets/01-measure-the-wind.md) |
| 02 | The same check compares every wind the briefing texts announce (`descriptionText` and tasks of the `.miz`, the approved briefing content, the deck) with the measurement, and flags the wind that is hard to fly for helicopters | ⬜ | [02](tickets/02-compare-the-briefing.md) |
| 03 | Without DCS: `set_weather`, `inspect_built_mission` and `build_mission_briefing` stop presenting the setting as the wind — a warning when helicopters fly in a strong setting, the measured wind in the deck when a measurement exists, the layer values shown | ⬜ | [03](tickets/03-warn-without-dcs.md) |
| 04 | Authoring guide, both mission prompts, known limitation (`kind: dcs`), documentation, CHANGELOG | ⬜ | [04](tickets/04-guide-prompts-docs.md) |

## Decisions (recommendations, by default)

- **D1 — the measurement is the reference, DCS is where it comes from.**
  The check reads `atmosphere.getWind` through the bridge `mission-check` already embeds (REFACTOR-BRIDGE-ONLY), in the mission scripting state; it needs a DCS running the test copy, like the rest of `mission-check`.
  *Why:* one measurement on one map is all we have; a rule of thumb ("×2 in the low layer") would encode it as if it were general.
- **D2 — the measurement goes through one function, so a model can replace it.**
  Another session is decoding DCS's wind model from `Weather.dll` (branch `feature/dcs-wind-model`, `docs/whitepapers/dcs-wind-model/`, first in-game run matching on 5,392 points).
  If it lands as a function `simulated_wind(point, height_agl) -> (from_deg, knots)`, tickets 02 and 03 call it without DCS and the check runs at authoring time.
  **This lot does not wait for it and does not depend on it**: every ticket is done with the DCS measurement; the model is a second provider behind the same function, in its own lot.
- **D3 — a briefing that contradicts the measurement fails the check; a hard wind only warns.**
  A briefing that announces 17 kt where pilots meet 35 is a factual error, like a wrong frequency: `mission-check` fails (exit code 1).
  A strong wind can be what the scenario wants (a storm, a hard extraction): it is reported, not refused, and it fails only when the briefing does not announce it.
  The report has no warning level today (`Line.ok` is `True`, `False` or `None`); ticket 02 adds one rather than hide the warning among informing lines.
- **D4 — thresholds, measured wind, for helicopter missions only** (a mission with at least one helicopter slot):
  warn when the wind between 0 and 600 m above a helicopter departure, objective or route point exceeds **20 kt**, or when it differs from the surface wind there by more than **15 kt** (the shear that surprised the pilots).
  *Source:* the original *Marteau du Golan* (34 to 37 kt, about 13 kt above its surface wind) was not flyable on 2026-10-31; the correction aims at 18 to 20 kt and has not been flown yet.
  One bad point and one target, not a study: the thresholds are constants in one place, named in the report, to revise after the next evening with helicopters.
- **D5 — tolerance of the comparison:** an announced speed matches when it lies within **5 kt** of the measured range at the layer it names (surface → 10 m; "low level", "aloft" or a height → that height band; a bare figure → surface), a direction within **30°**.
  A wind the texts mention without a figure ("windy", "strong wind") is listed, not judged.
- **D6 — CLI, under `dcs`, next to `mission-check`:** like it, the measurement needs a DCS running on this machine (CLAUDE.md §7).
  An agent writing a mission runs it when the user has launched the test copy, as it already does for `mission-check`; the prompts say so (ticket 04).

## Out of scope

- Turbulence and gusts (`atmosphere.getWindWithTurbulence`): the incident was the mean wind. The measurement may record the turbulent value next to it, unjudged.
- Changing the weather on its own: the check reports, the author decides. `set_weather` keeps its derivation of `at2000` / `at8000` by default and only gains parameters to set them (ticket 03 e).
- Missions whose weather the server rewrites (RealWeather, `ICAO_` in the name): the check measures what the test copy flies, and says the server may change it.

One branch, one PR.
