# 01 — vendor CTLD 2.0.0-rc12

Status: 🔄 in-progress

Replace `src/scripts/community/CTLD.lua` with the `CTLD.lua` asset of the VEAF/CTLD release
`published-v2.0.0-rc12`, converted from CRLF to LF, and move both pins of the `ctld` entry in
`vendored.yaml`.

## Acceptance

- `ctld.VERSION == "2.0.0-rc12"` in the vendored file, matching `vendored.yaml`
  (`test_vendored_pins_match_the_files.py`).
- `poetry run test-lua` green, `test_community_scripts_load.lua` included.
- `poetry run check-vendored` reports CTLD up to date.
