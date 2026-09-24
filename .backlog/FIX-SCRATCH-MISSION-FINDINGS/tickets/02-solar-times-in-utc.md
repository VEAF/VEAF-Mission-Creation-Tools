# 02 — Solar times are computed in UTC; the timezone is ignored

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/weather_injector/utils/solar_calculator.py`, tests

## What happens

```python
loc = LocationInfo(latitude=..., longitude=..., timezone=position.timezone)
times = sun(loc.observer, date=target_date)
```

`astral.sun.sun()` returns **UTC** unless given `tzinfo`. `position.timezone` goes into `LocationInfo`
and is never used again, so every `sunrise…` / `sunset…` expression lands in UTC.

## Measured

- GermanyCW-v6, Ramstein, `Europe/Berlin`, 1980-06-01: `sunrise-15*60` → `start_time` 03:13.
  Sunrise that day: 03:28 UTC (NOAA formula) = 05:28 CEST (West Germany had summer time from
  6 April 1980).
- Caucasus v6, `Asia/Tbilisi`, 2022-06-29: dawn variants at 01:28.

## Check first

That DCS reads `mission.start_time` as the theatre's **local** time. One-glance check for David: open
Caucasus v6 `dawn-broken` (01:28) — middle of the night? If yes, every solar variant of every v6
mission is 2 to 4 hours early.

Then which local time: DCS theatres use a fixed offset, which may differ from the IANA zone with its
historical DST. The right conversion may be "UTC + the theatre's DCS offset" rather than
`tzinfo=position.timezone`.

## Checked (2026-09-24, David in DCS)

- **DCS reads `start_time` as theatre local time.** Caucasus v6 `dawn-broken` (`start_time` 5301 =
  01:28, 2022-06-29): pitch dark. The ticket is confirmed.
- **The offset is a fixed per-theatre value, not the IANA zone.** DCS's own table is in the
  encrypted `terrain.cfg.lua`, but the repo already carries one on the Lua side:
  `veafTime.getTimezone()` (`src/scripts/veaf/veafTime.lua`), Caucasus +4, PersianGulf +4, Syria +3,
  Sinai +2, Marianas +10, Nevada −8 ("DST not modeled in DCS"). Unsourced, but consistent with the
  Caucasus observation.
- **GermanyCW is +2.** A copy of the GermanyCW-v6 build set to 04:58 on 1980-06-01 at Ramstein
  (sunrise 03:28 UTC, NOAA formula): dawn glow, sun not up, so 02:58 UTC. +1 would have put the sun
  30 min above the horizon. Measured in June only: whether DCS keeps +2 in winter is not known.
- **Second defect found on the way:** the mission's theatre name is `GermanyCW`, and it is missing
  from both `veaf.theatreName` and `veafTime.getTimezone()`, so the runtime computes GermanyCW sun
  times with offset 0.

Fix direction: astral in UTC + the theatre's fixed offset, from a Python table that a test keeps in
step with the Lua one; add `GermanyCW` = +2 on both sides.

## Done when

- A test pins sunrise for a known place and date to the right local time
- GermanyCW-v6 `dawn-real` starts just before sunrise, checked in DCS

## Outcome (PR 1)

- `SolarCalculator` takes the theatre's fixed offset; `theatre_offsets.py` mirrors
  `veafTime.getTimezone()`, a test keeps the two equal; `GermanyCW` = +2 added on both sides (and to
  `veaf.theatreName`). A theatre not in the table falls back to `position.timezone`, with a warning.
- Bench: dawn variants at 05:13 (sunrise 05:28 local − 15 min), were 03:13.
- Checked in DCS by David on 2026-09-24 (`dawn-real`): ok.
