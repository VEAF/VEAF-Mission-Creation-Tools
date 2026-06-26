# FEAT-EXPORT-BFR-PARSER-002 — array-ness normalizer + schemaVersion

Status: ⬜ ready
Type: feat
Files: `mission_tools/mission_exporter.py`, `test/python/`

## What to build

An **export-only** normalization pass applied in `build_export_object` (JSON path) that converts
any Python dict whose keys are exactly the contiguous integers `1..n` into a list (→ JSON array),
recursively. Add `schemaVersion` at the top level. The parser (`miz_tools`, `keep_as_dict`) and
the mission builder are **not** touched.

## Acceptance criteria

- [ ] Contiguous int-keyed dict `{1:a,2:b}` → `[a,b]`; nested too.
- [ ] Sparse `{2:a,5:b}` → object with string keys `{"2":a,"5":b}` (unchanged shape).
- [ ] Mixed `{1:a,"x":b}` → object.
- [ ] Empty `{}` → `{}` (documented parity-neutral).
- [ ] `schemaVersion` present at top level.
- [ ] `trigrules`, `trig.actions/conditions/flag` come out as arrays on a real mission.
- [ ] TDD; ruff + mypy clean; coverage gate bumped.

## Blocked by

FEAT-EXPORT-BFR-PARSER-001 (contract validated).
