# UX-PIPELINE-OUTPUT-POLISH

Status: ✅ done

## Problem

The `build` "pipeline" output is hard to read:

1. Each step prints a `Pipeline: …` header, but the detail lines below it are flush-left,
   so they don't visually belong to their step.
2. Counts use the ugly catch-all plural `injected 1 group(s)` / `1 unit(s), 78 group(s)`.

## Fix

1. **Indent detail lines** by two spaces under their step. New `logger.detail()` (same as
   `tech` but the console line is prefixed with `  `; the log file stays un-indented).
   Every per-step detail line now goes through `detail()` instead of `tech()` — the built
   mission file, aircraft injected/skipped, spawn data, warehouses, weather, presets,
   waypoints. The final `Traitement terminé !` stays a top-level `tech()` line.
2. **Natural plurals.** New `tn(key, count, **kwargs)` i18n helper: the catalog value holds
   a `singular|plural` pair, and `tn` picks the singular for `count == 1`, the plural
   otherwise. Single-count messages become e.g. `injected 1 aircraft group` /
   `injected 2 aircraft groups`. Multi-count messages (spawn data, warehouses) compose
   per-noun `tn` fragments so each noun agrees independently (`1 unit, 78 groups`;
   `1 airport configured, 0 template links`). FR + EN forms updated.

## Out of scope

- Other `(s)` forms outside the build pipeline output (broad catalog sweep) — not touched.

---

## 01 — Indent pipeline details + natural plurals

Status: ✅ done

### Tasks

- [x] `logger.detail()` — permanent line indented by 2 spaces (console only; log file
      un-indented).
- [x] `tn(key, count, **kwargs)` i18n helper — `singular|plural` selection.
- [x] Route every per-step detail line through `detail()` (build.py + mission builder,
      presets, waypoints workers); keep the final `work_done` as a top-level line.
- [x] Convert single-count pipeline messages to `singular|plural` + `tn`; compose
      multi-count messages (spawn data, warehouses) from per-noun `tn` fragments. FR/EN.
- [x] Tests: `tn` (singular/plural/single-form, FR agreement); workers report via
      `detail`. CHANGELOG; bump (6.7.4 → 6.7.5); `poetry install`.

### Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- Build output: each step header followed by 2-space-indented details with natural
  singular/plural in FR and EN.
