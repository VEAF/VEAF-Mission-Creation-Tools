# FIX-CONVERT-WEATHER-I18N

Status: 🔄 in-progress

## Problem

Three `convert-v5` pipeline-conversion warnings in `v5_pipeline_converters.py` were
hardcoded in English (the real-weather `TODO` ICAO notice, "weather file not found",
and the empty-waypoints warning). They reached the user in English even in a FR run.

They slipped past the COV-003 "no hardcoded prose" guard because that check only scans
`logger.*()` / `console.print()` / direct returns — not `warnings.append(...)`.

## Decision

Route all three through `t()` with FR/EN catalog entries.

## Implementation

- `mission_builder/v5_pipeline_converters.py`: replace the 3 f-string warnings with
  `t("convert_v5.warn.realweather_todo" | "weather_file_not_found" | "waypoints_empty")`.
- New i18n keys (FR/EN).
- Strengthen `test_realweather_produces_todo_icao_and_warning` to assert the warning
  names the version and the `TODO` (language-agnostic).

## Out of scope

- The COV-003 guard's scope (it does not cover `warnings.append`); broadening it could be
  a separate hardening lot.
