# 01 — Support the flat spawnableAircrafts layout

Status: ✅ done

## Tasks

- [x] `convert_aircraft_groups`: detect the layout (`categories` wrapper) and add a flat
      parser; share the routing/classification with the nested path.
- [x] Tests: keep the nested fixture; add a flat fixture (Tripack-style, numeric group
      index + name inside) asserting non-empty spawnables, helicopter routing, and
      dynamic-template split.
- [x] CHANGELOG `[Unreleased]`; PATCH bump (6.7.2 → 6.7.3); `poetry install`.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean.
- A flat-layout `settings.lua` converts its `veafSpawn-` groups into `spawnables.yaml`
  (verified against `d:\dev\_VEAF\tmp\test-tripack`).
