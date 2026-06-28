# UX-PLURAL-SWEEP

Status: ✅ done

## Goal

Apply the `tn()` natural-plural mechanic (introduced in UX-PIPELINE-OUTPUT-POLISH) to the
rest of the CLI, removing the catch-all `injected 1 group(s)` form across all
count-bearing messages — FR and EN.

## Scope

~40 count-bearing messages across `convert-v5`, `convert-other`, `build`, `validate`,
`prepare`, `export`, `migrate-config`, the inject commands, the report summary, and the
presets/waypoints/warehouses/spawn-data/aircraft workers.

## Mechanic

`tn()` is simplified to a single convention: the catalog keeps its legacy `(s)`
optional-plural markers and `tn` resolves each `word(s)` by count (`word` for 1, `words`
otherwise). Invariant nouns carry no marker (`{count} aircraft`). The earlier
`singular|plural` form was dropped — it collided with messages containing a literal `|`
(e.g. the aircraft selector line), and `(s)` covers every case in the catalog.

- **Single-count** messages: call site `t(key, count=x)` → `tn(key, x)` (or
  `tn(key, x, n=x)` when the placeholder is `{n}`/`{m}`); the catalog `(s)` is untouched.
- **Multi-count** messages (validate summary, warehouses/spawn-data/waypoints "done",
  `convert_other` yaml, report module counts): each noun is rendered by its own `tn`
  fragment so it agrees independently, then composed in a `t()` wrapper.

## Guard

`test_all_used_keys_exist_in_en` now scans `tn(` calls too (previously only `t(`), so
`tn` keys are checked against the catalog like every other key.

## Out of scope

- `(s)` markers tied to a *list* placeholder rather than a numeric count (e.g.
  "module(s) {modules}", "ID(s): {ids}") — no count to resolve against; left as-is.
