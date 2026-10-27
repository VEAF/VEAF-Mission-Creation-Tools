# 13 — `mission.yaml` switch for the VEAF weather welcome

Status: ⬜ ready

## Done when

- `modules.WEATHER.init.welcome_brief: false` generates `veafWeather.initialize(false)`; absent, the call is unchanged.
- Python tests, `MISSION_YAML_REFERENCE` FR/EN; checked on a converted BFR part.
