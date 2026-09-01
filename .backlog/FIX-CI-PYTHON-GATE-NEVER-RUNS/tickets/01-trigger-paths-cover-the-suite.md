# 01 — Trigger the gate on what it checks

Status: ✅ done

Type: fix · Files: `.github/workflows/python-quality.yml`, `test/python/test_ci_trigger_paths.py`

## The defect

`Python Quality` runs only for changes under `src/python/`, `test/python/`, `veaf_build/`,
`pyproject.toml`, `poetry.lock` and its own workflow file. Its suite also asserts on `.backlog/`,
`src/scripts/`, `doc/`, `plugin/` and `CHANGELOG.md` — see the table in the PRD.

Consequence: a lot that touches only Lua, only documentation or only the backlog merges with pytest,
ruff and mypy never invoked. The PR page shows seven or eight green checks, so nothing signals the
absence. #877, #875 and #866 all merged that way, and #877 left `develop` red.

## What was done

- The five missing paths added to **both** filters, with the reason and the measurement recorded in
  a comment next to the list
- `test/python/test_ci_trigger_paths.py` keeps the list honest: it asserts the new paths are present
  and that the `push` and `pull_request` filters are identical. GitHub Actions does not resolve YAML
  anchors, so the duplication is deliberate and needs a guard rather than a convention.

## Proof it can fail

Removing `.backlog/**` from the `push` filter turns both assertions red — the coverage one on the
missing path, the equality one on the drift between the two lists.
