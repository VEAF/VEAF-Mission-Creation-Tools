# 01 — Share the rich mission.yaml preamble between prepare and generate-config

Status: ✅ done

## Goal

Make `prepare --template` emit the same documented preamble as `convert-v5` /
`generate-config`, without duplicating the text a fourth time.

## Changes

- `lua_config_generator.py`: extract `global_log_level_section()`,
  `mission_identity_section(live_name=None)`, `security_section()`, `pipeline_section()`
  (the YAML guide already lives in `yaml_syntax_header()`). Refactor
  `generate_mission_yaml_template` to call them — output unchanged.
- `mission_template.py`: `generate_mission_yaml` emits guide + global_log_level +
  mission (live name) + security above the tier `modules:` block, plus `pipeline:` after it.
- `doc/mission-maker/GUIDE.md` + `GUIDE.en.md`: note the enriched preamble on the `prepare` row.

## Tests

- `TestMissionTemplatePreamble` (sections present per tier, commented/inert, helper reuse).
- `generate-config` output byte-identical (diff before/after).

## Done when

- `poetry run pytest` green, coverage gate held.
- `ruff` / `ruff format --check` / `mypy` clean.
- CHANGELOG entry + PATCH bump + docs updated.
