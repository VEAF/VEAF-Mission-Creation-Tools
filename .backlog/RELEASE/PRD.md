# Lot RELEASE — v6.1.0

Status: ⬜ ready
Branch: from `develop-v6` directly → master

## Problem Statement

The v6 line is feature-complete on `develop-v6` but has not been merged to `master`
nor published as an official release.

## Solution

Finalize the changelog and release notes, squash-merge `develop-v6` → `master`, tag
`v6.1.0`, publish to GitHub via `veaf-build publish`, and switch the doc URL prefix
from `/dev/` to `/latest/`.

## User Stories

1. As a user, I want an official v6.1.0 release on `master` and GitHub, so that I can
   install the stable v6 toolchain.

## Implementation Decisions

- Released from `develop-v6` directly (no feature branch).
- Squash merge into `master`, then tag and publish.

## Testing Decisions

- Release is a chore lot; verification is the publish pipeline succeeding.

## Out of Scope

- Any remaining feature lots — RELEASE must come last (depends on Lots 1–4).
