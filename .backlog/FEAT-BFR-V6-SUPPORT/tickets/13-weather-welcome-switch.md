# 13 — `mission.yaml` switch for the VEAF weather welcome

Status: 🧑 waiting-human (code done; checked on a converted BFR part)

The switch already existed and was documented, `modules.WEATHER.welcomeBrief: false`, and it was inert: the build writes it with `veaf.setConfig` and calls `veafWeather.initialize()` without an argument, which only read its argument (measured 2026-10-27).
No new key, then: the root cause is fixed.

## Done when

- `veafWeather.initialize()` without an argument reads the mission's `welcomeBrief` setting.
- Lua and Python tests; checked on a converted BFR part.
