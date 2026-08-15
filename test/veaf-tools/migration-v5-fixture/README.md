# Frozen v5 migration fixture

These files are a **frozen copy of the v5 demo mission's config and presets**, owned by the migration
tests so the demo itself can move to v6 (`MIGRATE-DEMO-MISSION-V6` ticket 01).

- `src/scripts/missionConfig.lua` — read by `test_config_migrator.py` (end-to-end v5 → v6 migration).
- `src/presets.yaml` — read by `test_presets_schema_migrator.py` (the six v5 → v6 preset renames that
  `FIX-CONVERT-V5-PRESETS-SCHEMA` found by walking this exact file).

Kept **whole**, not trimmed: the point is to exercise the migrator on realistic v5 content, and
trimming risks silently dropping a shape a test asserts. **Do not run `convert-v5` on this folder** —
it must stay v5, or the tests stop testing the v5 → v6 path.
