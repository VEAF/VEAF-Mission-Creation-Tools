# Lot CI-NODE24 — Migrate GitHub Actions off deprecated Node.js 20

Status: ✅ done

**Goal**: GitHub Actions will force Node.js 20 actions to run on Node.js 24 starting June 16th, 2026, and remove Node.js 20 from runners on September 16th, 2026. Bump the affected actions to majors that ship a Node.js 24 runtime so the workflows keep working without the deprecation warning.

**Branch**: `chore/ci-node24` → PR → `develop`

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CI-NODE24-001 | Bump `actions/checkout@v4` → `@v5` in all workflows | `.github/workflows/docs.yml`, `python-quality.yml`, `release.yml`, `lua-ci.yml` (×3), `sbom.yml`, `secret-scanning.yml` | chore | ✅ |
| CI-NODE24-002 | Bump `actions/setup-python@v5` → `@v6` in all workflows | `.github/workflows/docs.yml`, `python-quality.yml`, `release.yml`, `sbom.yml` | chore | ✅ |
| CI-NODE24-003 | Bump Node.js 20 actions to their first Node.js 24 major: `actions/upload-artifact@v4`→`@v6` (v5 still defaults to Node 20; v6 is `runs.using: node24`), `JohnnyMorganz/stylua-action@v4`→`@v5`, `softprops/action-gh-release@v2`→`@v3`, `gitleaks/gitleaks-action@v2`→`@v3`. `snok/install-poetry@v1` left as-is (composite action — no Node runtime, unaffected). | `.github/workflows/python-quality.yml`, `sbom.yml`, `lua-ci.yml`, `secret-scanning.yml` | chore | ✅ |
| CI-NODE24-004 | Trigger each workflow (or wait for natural runs) and confirm the Node.js 20 deprecation annotation no longer appears | CI runs | chore | ✅ |
| CI-NODE24-005 | Follow-up: `docs-chatbot-index.yml` was missed by 001-003 and still ran `actions/setup-node@v4` + `actions/cache@v4` (Node 20). Bumped both to `@v5` (Node 24). | `.github/workflows/docs-chatbot-index.yml` | chore | ✅ |
| CI-NODE24-006 | Exhaustive sweep over all 9 workflows caught a second miss: `peter-evans/create-pull-request@v7` (Node 20) in `dcs-data-drift.yml`. Bumped to `@v8` (Node 24; runtime-only, no input/behaviour change). No Node 20 action remains in any workflow. | `.github/workflows/dcs-data-drift.yml` | chore | ✅ |

**Behavioral-change review (third-party major bumps)**: each cross-major bump was checked against its upstream release notes and confirmed to be a **runtime-only** Node 20→24 migration for our usage — no new defaults or flags affect these workflows: `stylua-action@v5` (Node 24 only; same `version`/`args` inputs), `action-gh-release@v3` (Node 24 only; v2 stays on Node 20), `gitleaks-action@v3` (Node 24 only; same `GITLEAKS_*` env contract). `upload-artifact@v6` keeps the v4 single-immutable-artifact-per-name semantics our steps already rely on (the v7 non-zipped-artifact change is opt-in and not adopted here).

> **SHA pinning** (Sourcery suggestion): not done. The repo consistently uses floating major-version tags for every action; switching to commit-SHA pinning is a repo-wide supply-chain-hardening convention change, out of scope for this Node-runtime maintenance lot. Tracked as a possible future lot if the team wants it.
