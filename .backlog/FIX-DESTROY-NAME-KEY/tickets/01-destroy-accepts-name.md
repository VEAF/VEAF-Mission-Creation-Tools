# 01 — accept `name` in `_destroy` and document the options

Status: 🔄 in progress

The `destroy` handler in `src/scripts/veaf/veafSpawnObjects.lua` falls back to `options.name` when `options.unitName` is not set and `name` is not blank.
`doc/mission-maker/scripts/veafSpawn{,.en}.md` show `_destroy, unitname Tank-1` and an options table (`unitname`, `name`, `radius` 150), FR and EN in step.

## Acceptance

- Tests through `veafSpawn.executeCommand` (`test/lua/test_veafSpawn.lua`): `name X` and `unitname X` destroy X only; both written, `unitname` wins; no name clears the circle.
- `poetry run test-lua`, `stylua --check`, `poetry run docs-check` pass.
