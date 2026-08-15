# Lot FIX-RELEASE-WORKFLOW-PRERELEASE — make pre-releases actually safe

Status: ✅ done (PR pending → `feature/mcp-mission-editor`)

Branch: `fix/release-workflow-prerelease` → PR → `feature/mcp-mission-editor`

## Context

Publishing 6.9.20 as a **pre-release** (`veaf-build publish --version 6.9.20 --prerelease`) still
moved the floating `published-latest` tag to 6.9.20 and republished it as a full release — shipping
the in-development MCP branch to **every production maker** at their next `veaf-tools-updater` run.

Root cause: the CLI's `--prerelease` works locally, but pushing the `published-v6.9.20` tag triggers
the **`release.yml` workflow**, which:
- re-runs `veaf-build publish --ci --force` **without** `--prerelease`, and
- moves `published-latest` **unconditionally** (main job's "Move published-latest tag" step, plus the
  standalone jobs mirroring binaries onto `published-latest`).

The workflow had **no notion of a pre-release**, so the local flag was structurally powerless.

(Incident handled separately: `published-latest` was restored to 6.9.2 by reclobbering the 6.9.2
assets — see the session log; not a code change.)

## Decision (with David)

Encode the pre-release in the **version** (semver suffix), the single source of truth both the CLI
and the workflow read — no flag to forget, standard semver:

- stable: `--version 6.9.21` → tag `published-v6.9.21` → publish + advance `published-latest` (unchanged);
- pre-release: `--version 6.9.21-rc1` → tag `published-v6.9.21-rc1` → publish as pre-release,
  `published-latest` **left on the previous stable** (opt in with `--tag published-v6.9.21-rc1`).

## Change

- `veaf_build/github.py` — `GitHubPublisher._is_prerelease` now returns `self.prerelease or
  "-" in self.version`, so a semver pre-release version is treated as a pre-release even without the
  flag (the tag-move and `--latest` logic already keyed off `_is_prerelease`).
- `.github/workflows/release.yml` — both jobs compute `prerelease` from the tag's version (`*-*`),
  pass `--prerelease` to `publish`, and **skip** every step that touches `published-latest` (the
  "Move published-latest tag" step and the standalone `published-latest` mirror upload — whose old
  "skip if it doesn't exist" guard never fired, since `published-latest` always exists).
- `veaf_build/cli.py` — `publish` now **rejects** `--prerelease` on a plain version with a clear
  message (`use --version x.y.z-rc1`), so the exact trap that shipped dev to prod cannot recur.
  Help/docstring updated.
- Tests: `test_github_prerelease.py` covers `_is_prerelease` (flag / semver suffix / both) and the
  CLI guard (rejects plain version, allows suffixed).

## Out of Scope

- The one-off `published-latest` restore to 6.9.2 (operational, already done).
