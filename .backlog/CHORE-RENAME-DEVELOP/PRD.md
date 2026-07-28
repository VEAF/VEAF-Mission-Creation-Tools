# CHORE-RENAME-DEVELOP — `develop-v6` → `develop` + canonical gitflow for releases

Status: ✅ done

## Why

Two connected problems surfaced right after the 6.11.0 release:

1. **The release went to the wrong branch.** David asked for a release PR onto `master`
   (canonical gitflow). The project's release skill said the opposite — *"PR target:
   `develop-v6` (not `master` — `master` is reserved for stable milestones)"* — and that
   guidance was followed. Result: 6.11.0 was tagged on `develop-v6` and `master` stayed on
   6.10.0. The skill's wording made sense while `master` still carried **v5**; since 6.10.0
   `master` **is** the v6 stable line, so the canonical flow applies.
2. **The `-v6` suffix is now meaningless.** There is a single line, so the development
   branch should just be `develop`.

## Done

- `develop-v6` renamed to **`develop`** on GitHub (API rename: open PRs are retargeted,
  old references redirect).
- Every tracked reference rewritten: **181 files, 297 occurrences**. David's call was to
  rewrite **everything**, history included (`CHANGELOG.md`, `.backlog/` archives, dated
  `docs/superpowers/` plans) for full textual consistency — the alternative was to keep
  historical documents faithful to the name in use at the time.
- The 8 CI workflows now trigger on `develop` (critical: a stale trigger means no CI at all),
  plus `mkdocs.yml` `edit_uri`, the docs deploy condition, and `cliff.toml`.
- **Release skill rewritten** for the canonical gitflow: `release/x.y.z` → **`master`**,
  tag on `master`, **merge commit not squash**, then back-merge `master` → `develop`.

## Blocker removed along the way

The rename first failed with `'develop' is not a valid branch name`. Cause: a branch
**`develop/ctld-1.6.0-alpha`** existed, and git cannot hold both `develop` (a file ref) and
`develop/…` (a directory of refs). That branch was a single test commit from 2025-11-22,
916 commits behind, with no PR — deleted on David's call. Its tip is preserved here in case
of regret: `fa72fff76926aba0b6a47d4367073b57da95d8d1` (restore with
`git push origin <sha>:refs/heads/<name>`).

## Note on the 6.11.0 merge to master

PR #625 (`develop-v6` → `master`) was **squash-merged**, so the two branches carry the same
*content* (identical tree) but no shared *history*: `develop` reads as permanently ahead and
`published-v6.11.0` is not reachable from `master`. The back-merge below repairs the
divergence; the skill now forbids squash for release merges so it does not recur.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | Rename + rewrite all references + fix the release skill | ✅ |
| 02 | Back-merge `master` → `develop` to reunify the histories | ✅ |

## Not done (deliberately)

- Branch protection on `develop`: it has none after the rename. I did not measure it
  *before*, so I cannot claim it was lost — earlier merges onto `develop-v6` reported
  `CLEAN` (no required review or check), unlike `master` which reported `BLOCKED`. David to
  decide whether to add one.
- The unrelated branch `davidp57/port-pr288-to-develop-v6` keeps its name (it is a branch
  name, not a reference to the renamed branch).
