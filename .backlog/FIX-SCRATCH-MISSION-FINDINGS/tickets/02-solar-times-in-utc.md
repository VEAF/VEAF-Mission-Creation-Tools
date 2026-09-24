# 02 — Solar times are computed in UTC; the timezone is ignored

Status: ⬜ ready
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

## Done when

- A test pins sunrise for a known place and date to the right local time
- GermanyCW-v6 `dawn-real` starts just before sunrise, checked in DCS
