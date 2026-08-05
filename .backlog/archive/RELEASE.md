# Lot RELEASE — v6.10.0

Status: ✅ done
Branch: from `develop` directly → master

## Problem Statement

The v6 line is feature-complete on `develop` but has not been merged to `master`
nor published as an official release.

## Solution

Finalize the changelog and release notes, merge `develop` → `master`, tag
`published-v6.10.0` (binaries + GitHub Release, advances `published-latest`) and
`v6.10.0` (versioned docs + `latest` alias), publishing via the CI `release.yml`
and `docs.yml` workflows.

## User Stories

1. As a user, I want an official v6.10.0 release on `master` and GitHub, so that I can
   install the stable v6 toolchain.

## Implementation Decisions

- Released from `develop` directly (no feature branch).
- Versioned `6.9.30` → `6.10.0` (round bump marking the official v6 milestone).
- `master` carried a parallel v5 line (`v5.102.0` → `v5.103.3`); v6 already contained
  the only v5 critical fix, so master was superseded with a `merge -s ours` of the v5
  history followed by a fast-forward onto v6 — `master` tree is pure v6, v5 history
  preserved in the ancestry (no `--squash`, no force-push).

## Testing Decisions

- Release is a chore lot; verification is the publish pipeline succeeding.

## Out of Scope

- Any remaining feature lots — RELEASE must come last (depends on Lots 1–4).

---

## REL-001 — finalize CHANGELOG.md for v6.1.0

Status: ⬜ ready
Type: chore
Files: `CHANGELOG.md`

### What to build

Finalize `CHANGELOG.md` for v6.1.0.

### Acceptance criteria

- [ ] `CHANGELOG.md` finalized for v6.1.0

### Blocked by

Lots 1–4 (all feature work must land before the changelog is finalized)

---

## REL-002 — write RELEASE_NOTES.md for v6.1.0

Status: ⬜ ready
Type: chore
Files: `RELEASE_NOTES.md`

### What to build

Write `RELEASE_NOTES.md` for v6.1.0.

### Acceptance criteria

- [ ] `RELEASE_NOTES.md` written for v6.1.0

### Blocked by

REL-001

---

## REL-003 — squash merge `develop` → `master`

Status: ⬜ ready
Type: chore
Files: —

### What to build

Squash merge `develop` → `master`.

### Acceptance criteria

- [ ] `develop` squash-merged into `master`

### Blocked by

REL-002

---

## REL-004 — tag `v6.1.0` + publish GitHub

Status: ⬜ ready
Type: chore
Files: —

### What to build

Tag `v6.1.0` and publish the GitHub release (`veaf-build publish`).

### Acceptance criteria

- [ ] `v6.1.0` tag created
- [ ] GitHub release published via `veaf-build publish`

### Blocked by

REL-003

---

## REL-005 — switch doc URL prefix from `/dev/` to `/latest/`

Status: ⬜ ready
Type: chore
Files: `v5_converter.py`, `src/defaults/mission-folder/mission.yaml`

### What to build

Change the doc URL prefix from `/dev/` to `/latest/` in `v5_converter.py` (`DOC_BASE`,
`_DOC_BASE`) and `src/defaults/mission-folder/mission.yaml`.

### Acceptance criteria

- [ ] `DOC_BASE` / `_DOC_BASE` in `v5_converter.py` use `/latest/`
- [ ] `src/defaults/mission-folder/mission.yaml` doc URL uses `/latest/`

### Blocked by

REL-003
