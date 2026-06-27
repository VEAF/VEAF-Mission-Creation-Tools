# VDW-003 — `check-vendored` command

Status: ⬜ ready
Type: feature
Files: `src/python/veaf-tools/...` (+ `poetry run check-vendored` entry), tests under `test/python/`

## What to build

A command that reads `vendored.yaml`, and for each entry applies its `watch.kind`:
- `github-release` → compare latest release tag vs `pinned`;
- `github-file` → compare the file's last commit on `ref` vs `pinned`;
- `manual` → no comparison, flagged as "re-check by hand".

Compares via the **GitHub API only** (no artifact download). Prints a report (drifted /
up-to-date / manual) and exits non-zero when any drift is found. Reusable by the VDW-004
workflow (machine-readable output, e.g. JSON, alongside the human table).

## Acceptance criteria

- [ ] `poetry run check-vendored` reports drift / up-to-date / manual per artifact
- [ ] Non-zero exit on any detected drift
- [ ] Unit tests with a fixture manifest and **mocked** API responses (no network in tests)
- [ ] No artifact is downloaded (tag/commit comparison only)

## Blocked by

VDW-002
