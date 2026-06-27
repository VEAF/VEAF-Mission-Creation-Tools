# TDM-003 — CI mock-coverage job (non-blocking warning)

Status: ⬜ ready
Type: feature (CI)
Files: `.github/workflows/` (Lua CI or a dedicated job)

## What to build

Run `audit-dcs-mocks` in CI and surface the report as a **non-blocking warning** (the job
informs, it does not fail the build). A ratchet (fail on *new* gaps) is a later option,
not part of this ticket.

## Acceptance criteria

- [ ] CI runs `audit-dcs-mocks` and publishes the gap report
- [ ] Job is non-blocking (warning only)
- [ ] Report is visible in the run summary

## Blocked by

TDM-002
