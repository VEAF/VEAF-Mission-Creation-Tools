# FEAT-BLANK-MISSION-THEATRE-005 — Extend blank-mission to all dcs-maps theatres

Status: ✅ done
Type: feat
Files: `src/python/veaf-tools/veaf_libs/data/theatre-defaults.yaml`, `test/python/veaf_libs/test_blank_mission.py`

## What was built

Regenerated `theatre-defaults.yaml` from the calibration missions in
[VEAF/dcs-maps](https://github.com/VEAF/dcs-maps) `data/maps/*.miz` (MIT, Mitch), downloaded and
parsed with our own `read_miz` — extracting each theatre's real **map centre + zoom** and
**per-coalition bullseye** (not fabricated). Keys are the exact DCS `theatre` string.

**9 theatres**: Caucasus, Afghanistan, GermanyCW, MarianaIslands, MarianaIslandsWWII, Normandy,
PersianGulf, SinaiMap, Syria. The generator (`blank_mission.py`) is unchanged — pure data.

The 5 maps dcs-maps does not ship (Nevada, Kola, Falklands, TheChannel, Iraq) will get a blank when
Mitch adds them (coordinate conversion already covers all 14 via the projection export).

## Acceptance criteria

- [x] `supported_theatres()` returns the 9 dcs-maps theatres (DCS-spelled).
- [x] `generate_blank_mission` works for a second theatre (Normandy) — parses, correct theatre, no groups.
- [x] Caucasus test no longer pins the demo bullseye literal (tracks the vendored data).
- [x] ruff + mypy clean.

## Note

Values extracted once from the calibration missions; the `.miz` themselves are **not** vendored —
only the numeric constants. Regenerate by re-parsing updated dcs-maps missions.
