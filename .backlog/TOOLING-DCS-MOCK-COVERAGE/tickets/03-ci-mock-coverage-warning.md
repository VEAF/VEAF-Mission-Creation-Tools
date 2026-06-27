# TDM-003 — CI mock-coverage job (non-blocking warning)

Status: ✅ done
Type: feature (CI)
Files: `.github/workflows/` (Lua CI or a dedicated job)

## What to build

Run `audit-dcs-mocks` in CI and surface the report as a **non-blocking warning** (the job
informs, it does not fail the build). A ratchet (fail on *new* gaps) is a later option,
not part of this ticket.

## Acceptance criteria

- [x] CI runs `audit-dcs-mocks` and publishes the gap report (`.github/workflows/dcs-mock-coverage.yml`)
- [x] Job is non-blocking (`continue-on-error: true`)
- [x] Report is visible in the run summary (`--format markdown >> $GITHUB_STEP_SUMMARY`)

## Blocked by

TDM-002
