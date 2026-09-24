# 01 — Weather variants never change the weather DCS reads

Status: ⬜ ready
Type: fix
Files: `src/python/veaf-tools/weather_injector/weather/dcs_weather_converter.py`,
`weather_injector/weather_injector_worker.py` (`_set_mission_weather`, clearsky block), tests

## What happens

`DCSWeatherConverter` (~l. 97-120) builds

```python
{"atmosphere": {"temperature_celsius", "wind": {"speed_mps", "direction_degrees"},
                "visibility_meters", "clouds": {"type", "base_altitude_meters", "density"}},
 "fog": {"enabled", "density", "thickness_meters"}}
```

and `_set_mission_weather` does `current.update(weather)`. The mission gains two keys DCS does not
know, and the fields DCS **does** read keep the base mission's values: `clouds.preset / base /
thickness / density / iprecptns`, `season.temperature`, `wind.atGround / at2000 / at8000`, `qnh`,
`visibility.distance`, `enable_fog`, `fog.visibility / thickness`.

Unchanged since the feature's first commit, 21f3f386 (2025-11-25) — `git log -S'"atmosphere"'`.

## Measured

Caucasus v6 (`VEAF-Open-Training-Mission-Caucasus/missions`, built 2026-07-15):

| variant | DCS fields | `atmosphere` |
|---|---|---|
| dawn-broken | Preset2, base 2500, 20 °C, wind 0, qnh 760 | 23.2 °C, base 3400 |
| dawn-overcast-rain | Preset2, base 2500, 20 °C, wind 0, qnh 760 | 16.4 °C, base 2900 |

GermanyCW-v6: all 17 variants Preset1 / base 0 / 20 °C / calm (the synthetic blank mission's values).

David remembers testing weather early in v6 and seeing it work. Worth finding out what was tested:
the **time** does change per variant (`start_time` is written directly), which may be what was seen.

## What ships

- A converter that writes the DCS schema. Coverage → `clouds.preset` needs care: DCS presets
  (`Preset1..27`, `RainyPreset1..3`) are what DCS renders since 2.7; `density` is ignored when a
  preset is set. Pick presets per METAR coverage (FEW/SCT/BKN/OVC) and base.
- **Precipitation**: a METAR `RA` / `SHRA` / `TS` must reach DCS (`RainyPreset*`, `iprecptns`), else a
  "rain" variant is dry. The `weather:` object has no precipitation field — add one, or document that
  rain needs a METAR.
- `qnh` from the METAR (DCS stores mmHg), wind at ground and aloft, temperature in `season`.
- `clearsky` applied to the DCS fields.
- Stop writing `atmosphere` / top-level `fog` into the mission.

## Done when

- A test builds two variants from different METARs and asserts different values **in the DCS
  fields**, not in the converter's intermediate dict
- GermanyCW-v6 rebuilt: `day-scattered`, `day-overcast-rain`, `day-real` differ in `clouds.preset`,
  `season.temperature`, `wind.atGround`
- One variant opened in DCS shows the expected sky (David, a glance)
