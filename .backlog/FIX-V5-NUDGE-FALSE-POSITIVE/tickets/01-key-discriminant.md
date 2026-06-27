# 01 — Discriminate legacy v5 triggers by key

Status: 🔄 in-progress

Add a key-based guard to the legacy-v5 detection in `clear_veaf_triggers` so v6
triggers are never miscounted as legacy v5.

## Tasks

- [ ] TDD: failing test — MISSIONPATH conditions on v6 keys (`12005/12006`) must NOT
      emit the nudge; the same conditions on v5 keys (`108xx/109xx`) must.
- [ ] Fix: add `map_key not in _VEAF_TRIGGER_DICT_KEYS` to the detection condition.
- [ ] CHANGELOG `[Unreleased]`, PATCH bump.

## Definition of Done

- New test green; existing `test_migrate_from_v5_deprecation.py` still green.
- `poetry run pytest` green, coverage gate held; ruff/mypy clean.
