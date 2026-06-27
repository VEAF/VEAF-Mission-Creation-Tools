# VDW-004 — scheduled workflow that opens/updates a drift issue

Status: ✅ done
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

- [x] Weekly cron + manual `workflow_dispatch` (`.github/workflows/vendored-drift-watch.yml`)
- [x] One recap issue opened/updated on drift, listing drifts + `manual` reminders + `manual_steps`
- [x] No new issue when one is already open (matched by the `vendored-drift` label, edited in place)
- [ ] Validated by a manual dispatch dry-run — **blocked**: GitHub runs `schedule` /
      `workflow_dispatch` only from the **default branch**, which here is `master`,
      not `develop-v6`. The workflow (and its cron) activates once `develop-v6` is
      released to `master`. Until then the underlying `check-vendored` is validated
      directly (`poetry run check-vendored` flags the real TUM drift) and the
      issue-body rendering is unit-tested; only the `gh issue` create/update glue
      awaits the first run on `master`.

## Note (GitHub default-branch caveat)

This whole watch only fires once the workflow file reaches `master` (the repo's
GitHub default branch). It does **not** run from `develop-v6`. No code change needed
— it activates with the next v6 release to `master`.

## Blocked by

VDW-003
