# 01 — Plural sweep across the CLI

Status: ✅ done

## Tasks

- [x] Simplify `tn()` to the `(s)` convention only (drop `singular|plural`, which clashed
      with literal `|` in messages).
- [x] Route every single-count message through `tn()` (workers + commands; ~30 call sites),
      keeping the catalog `(s)` markers.
- [x] Convert multi-count messages to per-noun `tn` fragments composed in a `t()` wrapper
      (validate summary, warehouses/spawn-data/waypoints "done", `convert_other` yaml,
      report module counts).
- [x] Extend `test_all_used_keys_exist_in_en` to also scan `tn(` calls.
- [x] Tests for `tn` `(s)` resolution + extra-kwarg case; update tests asserting old `(s)`
      output (summary header). CHANGELOG; bump (6.7.5 → 6.7.6); `poetry install`.

## Definition of Done

- `poetry run pytest` green, coverage held; ruff/format/mypy clean; i18n parity ok.
- No remaining `(s)` catch-all on a count-bearing message; `1 asset extrait` /
  `5 assets extraits` style throughout, FR and EN.
