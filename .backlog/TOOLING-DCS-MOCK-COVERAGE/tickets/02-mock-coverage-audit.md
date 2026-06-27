# TDM-002 — `audit-dcs-mocks` coverage command

Status: ✅ done
Type: feature
Files: logic in `src/python/veaf-tools/veaf_libs/dcs_mock_audit.py` (typed + coverage-gated), thin CLI in `veaf_build/dcs_mock_audit_cli.py` (`poetry run audit-dcs-mocks`), tests under `test/python/`

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

- [x] Report lists DCS calls used by VEAF but not mocked
- [x] Calls filtered to schema-known DCS namespaces (no VEAF/mist false positives)
- [x] Presence only — no signature/arg comparison
- [x] Unit tests with fixtures (mini schema + mini mock + sample call site), no network

## Blocked by

TDM-001
