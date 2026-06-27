# VDW-004 — scheduled workflow that opens/updates a drift issue

Status: ⬜ ready
Type: feature (CI)
Files: `.github/workflows/vendored-drift-watch.yml`

## What to build

A GitHub Actions workflow, `on: schedule:` (weekly cron) + `workflow_dispatch` (manual
dry-run), that runs `check-vendored` and, when drift is found, **opens or updates one
recap issue** listing:
- every drifted artifact (current pin → latest upstream), and
- every `manual` artifact to re-check by hand,
each with its `manual_steps` so the maintainer sees the real update work.

Notify only — **no auto-update / no auto-bump PR** (that is the COMMUNITY-AUTOUPDATE
vision). Idempotent: update the existing open issue rather than spawning a new one each run.

## Acceptance criteria

- [ ] Weekly cron + manual `workflow_dispatch`
- [ ] One recap issue opened/updated on drift, listing drifts + `manual` reminders + `manual_steps`
- [ ] No new issue when one is already open (update in place)
- [ ] Validated by a manual dispatch dry-run

## Blocked by

VDW-003
