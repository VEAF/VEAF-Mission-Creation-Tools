# FEAT-BLANK-MISSION-THEATRE-001 — Blank-mission generator

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_libs/blank_mission.py`, `src/python/veaf-tools/veaf_libs/data/theatre-defaults.yaml`, `test/python/veaf_libs/test_blank_mission.py`

## What to build

A pure-Python generator that synthesizes a minimal, loadable DCS blank mission for a given theatre,
without any DCS round-trip:

- A **generic mission skeleton** — the set of `mission` keys DCS needs to open a mission without
  error (coalitions/countries stubs, `triggers`/`trig`/`trigrules`, `map`, `date`, `start_time`,
  `weather`, `result`, …), theatre-agnostic.
- A **per-theatre constants table** (`veaf_libs/data/theatre-defaults.yaml`): theatre name, a
  reference bullseye (DCS `x`/`y`), and map centre. Lightweight data, not a `.miz` asset.
- `generate_blank_mission(theatre) -> ...` emits the exploded `src/mission/` set: `mission`,
  `options`, `warehouses`, `theatre` (name), `l10n/DEFAULT/{dictionary,mapResource}`. Reuse the
  existing `write_miz`/`create_miz`/luadata serialization rather than hand-rolling Lua text.

## Acceptance criteria

- [ ] `read_miz` (or the folder reader) parses the generated output; `theatre` matches the request.
- [ ] The generated `mission` carries a per-coalition bullseye from the constants table.
- [ ] `veaf-tools build` succeeds on a folder using the generated `src/mission/` (empty of groups).
- [ ] Unknown theatre → clear error naming the supported set.
- [ ] ruff + mypy clean (full-tree; new module typed from the start — no exclusion).

## Open point

The exact minimal loadable key set is empirical — pin it against a real DCS load (manual check by
David) and freeze it as the skeleton. Start from an existing test mission's structure for reference.
