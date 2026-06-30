# 01 — Spec-aware build-time primary-frequency check

Status: 🔄 in-progress

## Goal

Stop the build from rejecting an aircraft whose genuine primary radio is HF (MiG-15bis
RSI-6K, 3.75–5.0 MHz) while keeping the ADF-promotion guard (Yak-52 ARK-15M @ 0.625 MHz).

## Changes

- `presets_injector_worker.py`:
  - import `validate_frequency`;
  - add `_is_valid_primary_frequency_for_unit(unit_type, freq)` — floor OR
    (`is_strict` AND in-spec);
  - the `process_groups` safety net uses the new helper with `g.unit_type`.

## Tests

- `test_process_groups_hf_primary_on_strict_aircraft_does_not_stop` (MiG-15bis @ 3.75).
- Existing `test_process_groups_stops_on_invalid_primary_frequency` (Yak-52 @ 0.625) stays green.

## Done when

- `poetry run pytest` green, coverage gate held.
- `ruff check` / `ruff format --check` / `mypy` clean on the worker.
- CHANGELOG entry + PATCH bump.
