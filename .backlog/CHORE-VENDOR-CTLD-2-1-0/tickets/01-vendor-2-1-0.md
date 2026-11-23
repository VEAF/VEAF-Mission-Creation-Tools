# 01 — vendor CTLD 2.1.0

Status: ✅ done — 2026-11-23

Replace `src/scripts/community/CTLD.lua` with the `CTLD.lua` asset of the VEAF/CTLD release `published-v2.1.0`, converted from CRLF to LF, and move both pins of the `ctld` entry in `vendored.yaml`.

## Acceptance

- `ctld.VERSION == "2.1.0"` in the vendored file, matching `vendored.yaml` (`test_vendored_pins_match_the_files.py`).
- `test_ctld_catalogue_gap.py` green against the `2.5.0` catalogue, the three new settings included.
- `poetry run test-lua` green, `test_community_scripts_load.lua` included.
- `poetry run check-vendored` reports CTLD up to date.
