# Lot VENDORED-DRIFT-WATCH — scheduled drift-watch for all vendored artifacts

Status: 🔄 in-progress
Branch: `feature/vendored-drift-watch` (one branch + one PR for the lot)

## Problem Statement

We vendor (commit a frozen copy of) several third-party artifacts: community Lua scripts
(mist, CTLD, CSAR, AIEN, TUM, Skynet, Hercules, STTS), the Python `luadata` library,
community sounds, and soon `dcs-world-api-schema.json` (TOOLING-DCS-MOCK-COVERAGE). Nothing
tells us when an upstream ships a newer version, so a pinned copy silently rots.

Worse, the provenance is **not obvious**. `mist` is a VEAF-maintained version with local
patches (an upstream PR unmerged for years) — there the VEAF fork **is** our source. But
for the others (`DCS-CTLD`, `DCS-CSAR`, `AIEN`, `the-universal-mission-for-dcs-world`) the
existence of a VEAF fork does **not** mean we vendor from it: VEAF often forks a repo only
to open a PR upstream, while the vendored copy may come straight from upstream, verbatim.
The real source — and whether the copy carries local changes — can only be established by
**comparing content**, not by the presence of a fork. For a forked/patched artifact,
updating is **not a drop-in copy** but a re-apply/rebase of VEAF changes — knowledge that
lives nowhere in the repo today.

## Solution

A single source-of-truth **manifest** of every vendored artifact, a **`check-vendored`**
command, and a **scheduled GitHub workflow** that opens/updates **one issue** when any pin
drifts from upstream. **Notify only — never auto-update** (auto-update is the
COMMUNITY-AUTOUPDATE vision, out of scope). The manifest also records, per artifact, the
**vendoring mode** and the **manual steps** required to update it.

## User Stories

1. As a maintainer, I want a GitHub issue when an upstream of a vendored artifact has a
   newer version, so a stale copy never goes unnoticed.
2. As a maintainer, I want each entry to state whether updating is a plain copy or a
   fork-rebase / patch-reapply, with the steps, so I know the real work before bumping.

## Implementation Decisions

- **Manifest `vendored.yaml`** is the single source of truth for pins. Per entry: `id`,
  `source` (where we vendor from), `upstream` (reference origin, for forks), `pinned`
  (version/commit), `vendoring` (mode), `manual_steps` (required for non-verbatim), `path`,
  `watch[]` (`{kind, repo, ref, role}`).
- **Vendoring modes**: `verbatim` (plain copy) · `adapted` (VEAF patches re-applied in
  place) · `fork` (maintained in a VEAF repo — watch BOTH our fork and the upstream) ·
  `compiled` (built artifact from upstream, e.g. Skynet).
- **`watch.kind`**: `github-release` (compare latest tag) · `github-file` (compare the
  file's last commit on a ref) · `manual` (no automatable source → the issue just reminds
  to check by hand).
- **Notify, not auto-update**: the workflow opens/updates ONE recap issue listing drifts +
  the `manual` entries to re-check, each with its `manual_steps`.
- **No artifact download**: comparisons use the GitHub API (tag/commit) via the workflow
  `GITHUB_TOKEN`.
- **Provenance is established by content comparison** (VDW-001), never assumed from a VEAF
  fork existing — a fork is often only a contribution fork. The `source` / `vendoring`
  mode of each entry is the diff's verdict (vendored file vs upstream vs any VEAF fork).
- For confirmed forks, watch the VEAF `source` (did our copy fall behind our own fork?) AND
  the `upstream` (did the original ship something to port?).

## Testing Decisions

- `check-vendored` unit-tested with a fixture manifest and **mocked** GitHub API responses
  (no network in tests).
- The workflow validated by a manual `workflow_dispatch` dry-run before relying on the cron.

## Out of Scope

- Auto-update / auto-bump PRs (→ COMMUNITY-AUTOUPDATE vision).
- Vendoring `dcs-world-api-schema.json` itself (→ TOOLING-DCS-MOCK-COVERAGE); this lot only
  *watches* it.
- Actually rebasing any fork (this lot *detects* drift; the rebase is per-bump manual work).
