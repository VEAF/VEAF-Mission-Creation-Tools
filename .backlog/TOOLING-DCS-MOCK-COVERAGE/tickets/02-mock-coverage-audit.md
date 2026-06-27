# TDM-002 — `audit-dcs-mocks` coverage command

Status: ⬜ ready
Type: feature
Files: `src/python/veaf-tools/...` (+ `poetry run audit-dcs-mocks`), tests under `test/python/`

## What to build

A command that builds three sets and reports the gap:
- **schema** — DCS functions parsed from the vendored `dcs-world-api-schema.json`;
- **used** — DCS calls extracted by regex from `src/scripts/veaf/*.lua`, filtered to the
  schema-known DCS namespaces (so VEAF/mist calls are excluded);
- **mocked** — functions defined in `test/lua/dcs_mocks.lua`.

Output (presence only): **used ∧ in-schema ∧ not-mocked** (the real gap), plus
informational **used ∧ not-in-schema** (typo / undocumented) and **mocked ∧ never-used**
(cleanup). Human table + machine-readable output for CI. Non-zero exit when the gap is
non-empty (CI decides whether to fail — see TDM-003).

## Acceptance criteria

- [ ] Report lists DCS calls used by VEAF but not mocked
- [ ] Calls filtered to schema-known DCS namespaces (no VEAF/mist false positives)
- [ ] Presence only — no signature/arg comparison
- [ ] Unit tests with fixtures (mini schema + mini mock + sample call site), no network

## Blocked by

TDM-001
