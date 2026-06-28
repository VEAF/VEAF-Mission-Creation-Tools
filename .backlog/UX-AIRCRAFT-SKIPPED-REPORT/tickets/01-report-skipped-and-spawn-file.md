# 01 — Report skipped aircraft + name the spawn-data file

Status: ✅ done

## Tasks

- [x] `pipeline.console.spawn_data` gains a `{file}` suffix; `build` passes the file name
      when `src/spawn-groups.yaml` exists.
- [x] `InjectionResult.groups_skipped` + count in `inject_groups`; `build` prints the
      skipped count when non-zero (new `pipeline.console.aircraft_skipped`, FR/EN).
- [x] Tests: skipped count for mixed / all-exist / purely-additive injections.
- [x] CHANGELOG `[Unreleased]`; PATCH bump (6.7.3 → 6.7.4); `poetry install`.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- A build whose spawnable aircraft already exist prints `0 injected` + `N already
  present (skipped)`, and the spawn-data header names `spawn-groups.yaml`.
