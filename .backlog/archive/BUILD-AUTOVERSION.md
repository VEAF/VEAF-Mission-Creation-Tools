# Lot BUILD-AUTOVERSION — auto-compute the release build number

Status: ✅ done

**Goal**: `veaf-build` should derive the release version automatically instead of requiring `--version`. Scheme is `X.Y.Z.BUILD`.

Algorithm:
1. Read the **project base version** from `pyproject.toml` (`X.Y.Z`, e.g. `6.4.20`).
2. If `published.zip` exists, read its **published version** (from `veaf-version.json` inside it, e.g. `6.4.20.3`).
3. If the published version shares the **same base** as the project (`6.4.20` == `6.4.20`) → **increment the build number** (`6.4.20.3` → `6.4.20.4`).
4. Otherwise (different base, e.g. project bumped to `6.4.21`, or no `published.zip`) → start from the project base with **build number 1** (`6.4.21.1`).

Notes: `--version` should remain an explicit override. Keep the provenance/version stamping (`veaf-version.json`) consistent. Add unit tests for each branch (same base → +1, new base → .1, no zip → .1).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| BUILD-AUTOVERSION-001 | Compute the release `X.Y.Z.BUILD` from project base vs `published.zip` version per the algorithm above; `--version` overrides; tests for each branch. | `veaf_build/`, `test/python/` | feat | ✅ |
