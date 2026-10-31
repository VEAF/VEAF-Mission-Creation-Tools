# 03 — the authoring actions stop presenting the setting as the wind

Status: ⬜ ready

Without DCS, the MCP actions do not know the simulated wind; they must stop implying they do:

- a. **`set_weather`** returns the three layers it wrote (`atGround`, `at2000`, `at8000`, today ground + 2 and + 5 m/s, `dcs_weather_converter.py`) and, when the mission has a helicopter slot and the ground setting exceeds 5 m/s, a warning: DCS simulated about twice that in the low layer on 2026-10-31 (known limitation of ticket 04); measure it with `mission-check` before writing the briefing.
  Its description says that the values are a setting, not the wind pilots meet.
- b. **`inspect_built_mission`** shows the three layers, not the ground one only (`inspect_built.py`), labelled "set", and the same warning.
- c. **`build_mission_briefing`** writes the measured wind (ticket 01's `<stem>_CHECK.wind.json`, when it exists and matches the built `.miz`'s weather) in the deck's weather block (`weather_lines`, `campaign_manager/mission_pages.py`, which prints the three set layers today); without one, it writes the setting **and** a `warnings` entry saying the wind is unmeasured.
- d. When the model of `feature/dcs-wind-model` lands (PRD D2), a and b use it instead of the warning; not in this lot.
- e. **`set_weather`** takes optional `wind_speed_2000` / `wind_speed_8000` (and their directions), defaulting to today's derivation: the *Marteau du Golan* fix needed `at2000` set on its own (8 m/s for 5 at the ground).

Done when: the three actions are unit-tested on a mission with and without a helicopter slot, and on a briefing build with and without a measurement file.
