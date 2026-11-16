# 02 — The QNH in hPa and inHg everywhere

Status: ✅ done

Files: `src/scripts/veaf/veafWeather.lua` (`veafWeatherUnitSystem.Systems`, `veafWeatherData:toStringPressure`), `test/lua/`, the weather page of `doc/` (FR and EN), `CHANGELOG.md`.

## What to do

- Apply D2: every pressure shown to a pilot (slot welcome message, weather menu, ATIS, combat zone weather) carries hPa and inHg; `MetricEastern` keeps mmHg as well.
- Check every caller of `toStringPressure` and of the `Pressures` list, including the carrier ATIS (`veafCarrierOperations.lua`, which picks `FaaNavy` or `MetricEastern`).

## Done when

- A luaunit test shows, for each unit system, the pressure string with both hPa and inHg, and fails on today's code.
- The doc page that describes the weather report says so.
