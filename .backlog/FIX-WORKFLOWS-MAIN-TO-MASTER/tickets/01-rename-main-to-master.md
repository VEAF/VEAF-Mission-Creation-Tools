# 01 — Rename main → master in all workflow triggers

Status: ✅ done

## Task

Replace the dead `main` branch reference with `master` in every CI workflow, so the jobs
actually run on the repo's real stable branch.

## Steps

- `branches: [develop-v6, main]` → `[develop-v6, master]` in: `dcs-data-consistency.yml`,
  `dcs-mock-coverage.yml`, `lua-ci.yml`, `python-quality.yml`, `sbom.yml`,
  `secret-scanning.yml`.
- `docs.yml`: push trigger `- main` → `- master`; deploy step condition
  `refs/heads/main` → `refs/heads/master`; update the step name comment.
- `sbom.yml`: update the header comment mentioning `main` pushes.
- Leave every `develop-v6` trigger and the `v*` tag paths untouched.

## Done when

- No workflow references a `main` branch; all use `master`.
- All 7 workflow files remain valid YAML.
- The PR checks are green.
