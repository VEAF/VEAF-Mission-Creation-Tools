# 01 — Rename the branch, rewrite references, fix the release skill

Status: ✅ done
Type: chore

## Tasks

- [x] Delete the blocking `develop/ctld-1.6.0-alpha` (SHA recorded in the PRD).
- [x] Rename `develop-v6` → `develop` via the GitHub API.
- [x] Rewrite all 297 references across 181 tracked files (history included, per David).
- [x] Verify the 8 workflow triggers now read `develop` — without this, no CI runs at all.
- [x] Rewrite `.claude/commands/release.md`: PR onto `master`, tag on `master`, merge commit
      (never squash, with the reason), back-merge `master` → `develop`, plugin manifest in
      the lockstep file list.
- [x] Local branches/worktrees realigned (`git branch -m`, `remote prune`).
- [x] `pytest` green (2300) — no `.py`/`.lua` file was touched by the rewrite.

## Verified

`git ls-files | xargs grep -l develop-v6` returns nothing. No composite name (e.g.
`port-pr288-to-develop-v6`) existed inside tracked files, so the blind replacement was safe.
