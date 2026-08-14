# 01 — Free the migration tests from the demo

Status: ⬜ ready
Type: refactor
Files: `test/python/mission_builder/test_config_migrator.py`,
`test/python/mission_builder/test_presets_schema_migrator.py`, new fixtures under `test/fixtures/`

## Why first

The demo cannot move to v6 while two tests read it *as a v5 artifact*. Doing this first means ticket
02 is a conversion and nothing else.

## The work

Give each migration test a **minimal v5 fixture it owns**: one `missionConfig.lua` and one
`presets.yaml`, carrying the shapes the tests actually assert rather than a whole mission's worth of
content. `test_config_migrator.py:1087` runs an end-to-end migration of the fixture folder, so that
one needs a small v5 *folder*, not just a file.

Keep the coverage identical — this is a fixture move, not a rewrite. `FIX-CONVERT-V5-PRESETS-SCHEMA`
found six renames by walking the demo's presets file, and every one of them must still be exercised.

## Careful

`test_edit_zone.py` reads `veaf-demo-mission.miz` for a zone's field layout and does not care about the
mission's version. Leave it alone; ticket 02 must keep a built `.miz` at that path.

## Acceptance criteria

- [ ] Neither migration test reads `test/veaf-tools/demo-mission/`.
- [ ] The six presets renames and the config migration are still asserted, from the new fixtures.
- [ ] Full Python gate green, coverage ratchet respected.
