# VDW-003 — `check-vendored` command

Status: ✅ done
Type: feature
Files: logic in `src/python/veaf-tools/veaf_libs/vendored_check.py` (typed + coverage-gated), thin CLI in `veaf_build/vendored_check_cli.py` (`poetry run check-vendored`), tests under `test/python/`

## What to build

A command that reads `vendored.yaml`, and for each entry applies its `watch.kind`:
- `github-release` → compare latest release tag vs `pinned`;
- `github-file` → compare the file's last commit on `ref` vs `pinned`;
- `manual` → no comparison, flagged as "re-check by hand".

Compares via the **GitHub API only** (no artifact download). Prints a report (drifted /
up-to-date / manual) and exits non-zero when any drift is found. Reusable by the VDW-004
workflow (machine-readable output, e.g. JSON, alongside the human table).

## Acceptance criteria

- [x] `poetry run check-vendored` reports drift / up-to-date / manual per artifact
- [x] Non-zero exit on any actionable finding (drift or unresolved watch)
- [x] Unit tests with a fixture manifest and **mocked** API responses (no network in tests)
- [x] No artifact is downloaded (tag/commit comparison only, via the GitHub API)

## Blocked by

VDW-002
