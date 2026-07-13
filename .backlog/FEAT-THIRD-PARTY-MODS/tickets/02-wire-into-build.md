# FEAT-THIRD-PARTY-MODS-002 — Wire into the build

Status: ✅ done
Type: feat
Files: `mission_builder/mission_builder_worker.py`, mission.yaml schema, `test/python/`

## What to build

- Read `mission.third_party_mods` (optional list, default empty) from the loaded
  `mission.yaml` during the build.
- Call `strip_third_party_mods` (from ticket 001) on the mission table in the existing
  read → mutate → write sequence of `mission_builder_worker.py`, before `write_mission`.
- Log the removed mod ids (VEAF logger, i18n message; use `tn` for singular/plural if the
  count is surfaced).
- If a mission.yaml schema/validation declares the `mission:` block fields, add
  `third_party_mods` as an optional list there so a populated field doesn't fail validation.

## Acceptance criteria

- [ ] With no `mission.third_party_mods`, the VEAF default list is still applied.
- [ ] A mod listed only in `mission.third_party_mods` is stripped (union with default).
- [ ] `mission.yaml` carrying `third_party_mods` validates cleanly.
- [ ] Build logs which mods were stripped.
- [ ] TDD on the worker path; ruff + mypy clean.

## Blocked by

FEAT-THIRD-PARTY-MODS-001.
