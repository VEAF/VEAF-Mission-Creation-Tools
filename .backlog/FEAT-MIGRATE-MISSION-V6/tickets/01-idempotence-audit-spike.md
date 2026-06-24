# FEAT-MIGRATE-MISSION-V6-001 — idempotence audit + regression tests

Status: ✅ done
Type: spike
Files: `test/python/`

## What to build

Audit done — all injectors are idempotent on rebuild-after-promote (see lot summary):
aircrafts (skip/replace by name), spawn-data (Lua stripped on extract + trigger
remove/reinject), waypoints (replace by name), presets (overwrite), warehouses
(dict keyed by type), weather (scalar set + `update`). Add per-injector unit tests
asserting a second apply over an already-injected mission produces no duplicate (lock
the contract).

## Acceptance criteria

- [x] Per-injector idempotence contract documented (aircrafts, spawn-data, waypoints, presets, warehouses, weather)
- [x] Per-injector tests assert no duplicate on a second apply over an already-injected mission

## Blocked by

None — can start immediately
