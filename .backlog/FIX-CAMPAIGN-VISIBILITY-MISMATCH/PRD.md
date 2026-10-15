# FIX-CAMPAIGN-VISIBILITY-MISMATCH — `campaign next` announces 10 km, the mission flies 80 km

Status: ✅ done

## Found

David, 2026-10-15: `campaign next` announces a visibility of 10 km, the mission it writes carries 80 km.

## Measured

- `draw_weather` (`campaign_manager/mission_conditions.py`) draws the visibility among 8 000 and 10 000 m.
  `Kolkhida/2` draws `few`, base 3 100 m, **10 000 m**.
- `set_conditions` hands it to `set_weather`, whose converter (`dcs_weather_converter.py`, the `"visibility"` entry of the table) writes `80000 if visibility >= 9000`: the reading of a METAR's `9999`, "10 km or more", flown as DCS's maximum.
  It applies to a value given in metres too, by `set_weather` or a `versions.yaml` variant.
- The report (`NextMissionReport.conditions.weather`, returned as is by the MCP `campaign_next` action) gave the drawn 10 000 m; the mission deck reads the table and says "10 km or more", which is true.
- Kolkhida mission 2, built 2026-10-10: `visibility = { distance = 80000 }` in the `.miz`. The mission is consistent; only the report was wrong.
- Swept the 126 draws a campaign can make (3 covers × 21 bases × 2 visibilities): cloud base, temperature and ground wind are written as drawn, wind direction turned from FROM to TO as intended. QNH is not drawn. **Only the visibility differs.**

## Decision

David, 2026-10-15, option B of three: keep the converter's convention (9 km or more is 80 km), report what is written, and document the convention.
Option A — write an explicit value in metres as given — was set aside: every mission whose variant says `visibility: 10000`, the shipped default `noon` among them, would have gone from 80 km to 10 km at its next build.

## Tickets

- [01 — Report the visibility written](tickets/01-report-the-visibility-written.md) · ✅

## Done

`set_conditions` puts the distance `set_weather` wrote into the conditions it returns.
Test: six missions prepared in a row, the announced visibility, cloud base, temperature and ground wind equal the mission table's — red before the fix (`10000.0 == 80000`).
The convention is written where a visibility in metres is accepted: the MCP `set_weather` schema and docstring, `inject-weather --readme`, `PIPELINE_REFERENCE` and `CAMPAIGN` (FR and EN).
No DCS check: what DCS flies did not change.
