# 01 — Reword the empty-ICAO notice

Status: ✅ done

Reword the realweather empty-ICAO console notice emitted by `convert-v5` so it:

1. states the conversion succeeded (`airport_icao: TODO` written to `versions.yaml`);
2. offers the lightest recovery first (edit the `TODO`), then the re-run path.

## Tasks

- [ ] `fr.json`: reword `convert_v5.command.realweather_empty_icao` + `realweather_hint`.
- [ ] `en.json`: same, English.
- [ ] CHANGELOG `[Unreleased]` entry.
- [ ] PATCH bump in `pyproject.toml`.

## Definition of Done

- `poetry run pytest` green (no test asserts these strings; none should break).
- `ruff` / `mypy` clean (no Python logic touched).
