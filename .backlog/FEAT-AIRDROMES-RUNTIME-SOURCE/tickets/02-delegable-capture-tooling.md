# 02 — Delegable map-data capture tooling

Status: 🔄 in-progress
Type: feat

## Goal

Let a **non-developer** (David's helpers, no source/Python/Poetry) collect a theatre's
airbases into a rich `<theatre>.json`, using only the shipped executables.

## Decisions

- **Data (validated live)**: `{id, name, lat, lon, coalition}` per airbase. lat/lon via
  `coord.LOtoLL` = the real value. Dropped `callsign` (== name) and `type` (always
  AIRDROME); `coalition` kept but reflects the *mission* (0 in an empty bridge mission).
- **Format**: rich `airbase_dumps/<theatre>.json`; `airdromes.yaml` stays the flat
  name→id projection derived from it.
- **Placement**: maker commands live in **`veaf-tools`** (the shipped exe), backed by a
  shared `veaf_libs/dcs_bridge_capture.py` also used by `veaf-build`.

## Tasks

- [x] Shared `veaf_libs/dcs_bridge_capture.py`: `resolve_bridge_lua`, `inject_bridge`
      (MCP editor-parity primitive), `capture_airbases` (enriched, `POST /api/exec`),
      `write_airbase_dump` (JSON).
- [x] `veaf-tools capture-map` + `veaf-tools inject-bridge` (i18n keys fr/en; MACHINE_ONLY).
- [x] `airdromes.py` reads `airbase_dumps/*.json` → name→id merge; `veaf-build --airdromes`
      + `--capture`/`--inject-bridge` rebased on the shared module.
- [x] TDD: `test_dcs_bridge_capture.py` + `test_dcs_data_airdromes.py` (JSON).
- [x] Docs: `doc/developer/capture-airbases.md` + `.en.md` (helper procedure); `dcs-data` updated.
- [x] CHANGELOG.
- [x] Clean CLI error handling: `capture-map`/`inject-bridge` catch bridge/HTTP errors →
      clear message + exit 1 (no stacktrace); `capture_airbases` maps 504 / timeout / refused
      to actionable messages.
- [x] Rebuilt `veaf-tools.exe` (6.10.1, commands ship) + `dcs-serve.exe`; assembled a
      "kit répétition" (`d:/dev/_VEAF/tmp/kit-repetition/`: both exe + `dcs-serve.yaml` + 6
      bridge missions + `PROCEDURE.md`) for David's dry-run.

## Validated live (Syria session)

- `veaf-tools capture-map` produced `Syria.json` (225 airbases, lat/lon) → `airdromes.yaml`
  regenerated, Tripack's airfields resolve, Caucasus preserved.
- `inject-bridge` embeds `dcs-bridge.lua` + trigger on a vanilla `.miz`.
