# 01 — vendor CTLD 2.0.0-rc15

Status: ✅ done — 2026-10-27 (PR #1204)

Replace `src/scripts/community/CTLD.lua` with the `CTLD.lua` asset of the VEAF/CTLD release `published-v2.0.0-rc15`, converted from CRLF to LF, and move both pins of the `ctld` entry in `vendored.yaml`.
Make the catalogue gap read `ctld.configListSince`, so that `ctld-upgrade` writes the Fat Cow lists into a `2.2.0` configuration instead of stamping their absence.

## Acceptance

- `ctld.VERSION == "2.0.0-rc15"` in the vendored file, matching `vendored.yaml` (`test_vendored_pins_match_the_files.py`).
- `poetry run test-lua` green, `test_community_scripts_load.lua` included.
- `poetry run check-vendored` reports CTLD up to date.
- `TestListsNewerThanTheMission`: a `2.2.0` file misses the four Fat Cow lists, the upgrade writes them and closes the gap, a list removed at `2.3.0` stays removed.
