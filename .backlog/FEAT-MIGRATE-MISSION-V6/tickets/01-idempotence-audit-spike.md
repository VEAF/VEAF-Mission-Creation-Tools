# FEAT-MIGRATE-MISSION-V6-001 — idempotence audit (spike)

Status: ⬜ ready
Type: spike
Files: `*_injector/`, `test/python/`

## What to build

Confirm the waypoints/presets/warehouses/weather injectors never duplicate when
`src/mission/` already holds their output (the rebuild-after-promote scenario).
Document the per-injector idempotence contract; add a regression test that builds →
extracts → rebuilds and asserts stability (group/trigger counts unchanged).

## Acceptance criteria

- [ ] Per-injector idempotence contract documented (waypoints, presets, warehouses, weather)
- [ ] Regression test: build → extract → rebuild asserts stable group/trigger counts

## Blocked by

None — can start immediately
