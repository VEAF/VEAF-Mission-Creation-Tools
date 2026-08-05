# FIX-CONVERTV5-ICAO-MESSAGE

Status: ✅ done

## Problem

When `convert-v5` runs without `--icao` on a mission that uses realweather, it prints
a notice that reads like a failure and only points at re-running the command:

> La version météo 'night-real' utilise realweather.
> Le code ICAO a été laissé vide dans la configuration générée.
> Passez `--icao UGGG` (remplacez par votre code d'aérodrome) pour le définir automatiquement.

This is misleading on two counts:

1. The conversion **did not fail** — the converter writes `airport_icao: TODO` into the
   generated `versions.yaml` and continues (see
   `convert_weather` in `mission_builder/v5_pipeline_converters.py`). The `TODO` is a
   deliberate, self-documenting placeholder.
2. It only advertises the heavy recovery path (re-run with `--icao`, which needs
   `--force` and clobbers any manual edits made since). It omits the simplest fix:
   edit the `TODO` field in `versions.yaml`.

## Decision

Keep the behaviour as-is (write `TODO` + warn — the post-conversion correction
mechanism is already correct). **Only reword** the three console i18n keys so the
message states that the conversion succeeded and offers the lightest recovery path
first.

No logic change → no mypy debt reopened. Pure i18n (FR + EN).

## Scope

- Reword `convert_v5.command.realweather_empty_icao` and
  `convert_v5.command.realweather_hint` in `fr.json` and `en.json`.
- `realweather_notice` left as-is (already accurate).
- CHANGELOG entry, PATCH bump.

## Out of scope

- Halting the pipeline on empty ICAO (rejected: disproportionate for an optional field).
- A dedicated post-conversion fix command (rejected: editing one YAML field or
  re-running already covers it — over-engineering).

---

## 01 — Reword the empty-ICAO notice

Status: ✅ done

Reword the realweather empty-ICAO console notice emitted by `convert-v5` so it:

1. states the conversion succeeded (`airport_icao: TODO` written to `versions.yaml`);
2. offers the lightest recovery first (edit the `TODO`), then the re-run path.

### Tasks

- [ ] `fr.json`: reword `convert_v5.command.realweather_empty_icao` + `realweather_hint`.
- [ ] `en.json`: same, English.
- [ ] CHANGELOG `[Unreleased]` entry.
- [ ] PATCH bump in `pyproject.toml`.

### Definition of Done

- `poetry run pytest` green (no test asserts these strings; none should break).
- `ruff` / `mypy` clean (no Python logic touched).
