# 01 — Solar times at the theatre's point when `position` is absent

Status: ✅ done — A Caucasus mission built from a `versions.yaml` without `position` gets its sunrise at the Caucasus point (07:24-07:25 on 2024-03-15, against 07:48 at Damascus), asserted on the `start_time` of the built `.miz`; no in-game check needed.

- `weather_injector/utils/theatre_position.py`: `theatre_position(theatre)` returns a `Position` from `theatre-defaults.yaml`'s map centre, else `theatre-bounds.yaml`'s centre, or `None`.
- `WeatherInjectorWorker.work`: with no `position`, take the theatre's (read from the base mission's `theatre` member) and log where; with one outside the theatre's bounds, warn.
- `src/defaults/mission-folder/src/versions.yaml`: the `position` block commented out as an override example.
- Docs FR + EN where `position` is documented; `known-limitations.yaml` entry for the one-point-per-theatre approximation.

## Done

- The points, all inside their theatre's bounds: Caucasus 41.62 N 41.61 E (Batumi), Syria 35.19 N 36.26 E (Hama), PersianGulf 26.78 N 55.88 E, GermanyCW 52.33 N 10.80 E, Normandy 49.51 N 0.09 W, and so on for the 14 theatres the projection knows.
- The timezone given with the point is `Etc/GMT∓n` for its longitude: it is read only for Iraq (UTC+3) and MarianaIslandsWWII (UTC+10), whose DCS clock is not in `theatre_offsets.py`; with the Damascus default both read UTC+3.
- The warning on a declared `position` uses `theatre-bounds.yaml`, the generous boxes the geocoder already uses: a position just off the map is not warned, Damascus on the Caucasus is.
- Tests: `test/python/weather_injector/test_default_solar_position.py`, end to end through `WeatherInjectorWorker.work()` on a blank Caucasus `.miz`; replacing the theatre point by `None` makes the first one fail.
