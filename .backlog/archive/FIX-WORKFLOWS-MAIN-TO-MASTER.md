# Lot FIX-WORKFLOWS-MAIN-TO-MASTER

Status: ✅ done
Branch: `fix/workflows-main-to-master` → `develop` (merged, PR #616)

## Problem Statement

Every CI workflow triggers on the branch `main`, but the repository has **no `main`
branch** — its default/stable branch is `master` (branches: `develop`, `master`,
`development`). So all the branch-scoped triggers on `main` are **dead**: none of the CI
runs on a push to `master`. Surfaced right after the v6.10.0 release — pushing the release
to `master` triggered no quality checks, and `docs.yml` only redeployed the `latest` docs
alias via the `v*` tag, never via the branch push it was meant to.

Affected workflows (10 occurrences across 7 files):

- `dcs-data-consistency.yml`, `dcs-mock-coverage.yml`, `lua-ci.yml`, `python-quality.yml`,
  `sbom.yml`, `secret-scanning.yml` — `branches: [develop, main]`
- `docs.yml` — push trigger `- main`, the `main → latest` deploy step condition
  (`github.ref == 'refs/heads/main'`) and its comment

## Solution

Mechanical rename `main` → `master` in every workflow trigger and condition, so the CI
actually runs on `master`:

- Quality/consistency/SBOM/secret-scanning jobs now run on a `master` push (master receives
  the release merges — keeping it green is the point).
- `docs.yml` deploys the `latest` alias on a `master` push, matching the original intent of
  the (dead) `main → latest` step. The `v*` tag path (versioned + latest + set-default) is
  unchanged and remains the canonical release-doc mechanism.

## Implementation Decisions

- Pure mechanical substitution; no trigger added or removed beyond the `main`→`master`
  rename. `develop` triggers untouched.
- **No product version bump**: CI-only infrastructure; the shipped binary is unchanged.

## Testing Decisions

- CI-only YAML change; all 7 files validated as well-formed YAML. Verification is the PR's
  own checks passing, and the next `master` push (a future release) actually triggering the
  jobs.

## Out of Scope

- Consolidating the now-redundant `master → latest` branch deploy vs the `v*` tag deploy in
  `docs.yml` (both deploy `latest`; the tag also sets the default). Both are idempotent —
  left as-is to keep the change surgical.

---

## 01 — Rename main → master in all workflow triggers

Status: ✅ done

### Task

Replace the dead `main` branch reference with `master` in every CI workflow, so the jobs
actually run on the repo's real stable branch.

### Steps

- `branches: [develop, main]` → `[develop, master]` in: `dcs-data-consistency.yml`,
  `dcs-mock-coverage.yml`, `lua-ci.yml`, `python-quality.yml`, `sbom.yml`,
  `secret-scanning.yml`.
- `docs.yml`: push trigger `- main` → `- master`; deploy step condition
  `refs/heads/main` → `refs/heads/master`; update the step name comment.
- `sbom.yml`: update the header comment mentioning `main` pushes.
- Leave every `develop` trigger and the `v*` tag paths untouched.

### Done when

- No workflow references a `main` branch; all use `master`.
- All 7 workflow files remain valid YAML.
- The PR checks are green.
