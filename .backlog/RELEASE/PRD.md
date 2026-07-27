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
