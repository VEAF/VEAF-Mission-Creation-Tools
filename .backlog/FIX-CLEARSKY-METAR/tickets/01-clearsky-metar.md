# 01 — Compose `${METAR}` from the capped weather of a METAR or ICAO `clearsky` variant

Status: ✅ done

Files: the weather injector (`weather_injector_worker.py`, `weather/dcs_weather_converter.py`,
`weather/metar_composer.py`), `doc/PIPELINE_REFERENCE.md` (FR + EN), `known-limitations.yaml`, tests.

## Done when

- A `metar:` or `airport_icao:` variant with `clearsky: true` gets a `${METAR}` composed from the capped
  values, with the report's station, real temperature and QNH, stamped at the variant's time in UTC.
- The caps live in one function, used by the injected weather table and by the composed METAR.
- The documentation table says so, and says that a raw METAR keeps its publication time.
- The single-cloud-layer parsing is a `kind: tool` known limitation.
