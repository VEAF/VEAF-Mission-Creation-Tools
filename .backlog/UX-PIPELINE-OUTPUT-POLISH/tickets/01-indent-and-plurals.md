# 01 — Indent pipeline details + natural plurals

Status: ✅ done

## Tasks

- [x] `logger.detail()` — permanent line indented by 2 spaces (console only; log file
      un-indented).
- [x] `tn(key, count, **kwargs)` i18n helper — `singular|plural` selection.
- [x] Route every per-step detail line through `detail()` (build.py + mission builder,
      presets, waypoints workers); keep the final `work_done` as a top-level line.
- [x] Convert single-count pipeline messages to `singular|plural` + `tn`; compose
      multi-count messages (spawn data, warehouses) from per-noun `tn` fragments. FR/EN.
- [x] Tests: `tn` (singular/plural/single-form, FR agreement); workers report via
      `detail`. CHANGELOG; bump (6.7.4 → 6.7.5); `poetry install`.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- Build output: each step header followed by 2-space-indented details with natural
  singular/plural in FR and EN.
