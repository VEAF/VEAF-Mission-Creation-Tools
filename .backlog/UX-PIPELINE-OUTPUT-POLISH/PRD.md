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
