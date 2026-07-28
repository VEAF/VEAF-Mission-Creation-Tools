# 02 — Back-merge `master` → `develop`

Status: ✅ done
Type: chore

## Why

PR #625 (`develop-v6` → `master`) was **squash-merged**, so the two branches ended up with
the same *content* (identical tree) but no shared *history*: `develop` read as permanently
ahead, and `published-v6.11.0` was unreachable from `master`. The canonical gitflow
prescribes a back-merge after every release; it was missing.

## What happened

The merge raised **14 conflicting files** — all of them the predicted artificial kind:
`master` still carried `develop-v6` (it was squashed before the rename), `develop` carried
`develop`. Resolved by keeping `develop`'s side everywhere, which is correct by construction
(`develop` = `master` + the rename commit). Keeping `master`'s side on the 8 workflows would
have re-broken CI.

## Result

- `git merge-base --is-ancestor origin/master develop` now succeeds: **histories reunified**.
- No content lost: the remaining `master` ↔ `develop` differences are the rename plus this
  lot's own documents.
- The release skill now forbids squash on release merges, so this will not recur.
