# 01 — Take the rc11 asset and move both pins

Status: ✅ done

## What changes

- `src/scripts/community/CTLD.lua` — the `CTLD.lua` asset of `published-v2.0.0-rc11`, **converted
  to LF before copying**. A raw copy shows a 37 000-line diff and makes every later comparison
  unreadable.
- `vendored.yaml` — `pinned: "2.0.0-rc11"` and the watch's `pinned: "published-v2.0.0-rc11"`. Both
  strings appear exactly once; each replacement asserts that before applying.
- `CHANGELOG.md` — one entry under `[Unreleased]`.

## Watch out

- **Verbatim means verbatim.** No local edit, whatever a linter says: `vendoring: verbatim` in
  `vendored.yaml`, and the next sync would silently drop anything added here.
- **Do not bump the version** (§9.5) and do not touch `src/defaults/mission-folder/mission.yaml`:
  the embedded configuration catalogue is byte-identical, measured, so the shipped default stays
  aligned on its own.
- The gate that matters is `test_community_scripts_load.lua`, which **runs** the file under the DCS
  mocks. `assert(loadfile(...))` only parses, which is how rc8 shipped dead and took every radio
  menu with it.

## Acceptance

- [x] `ctld.VERSION` in the vendored file reads `2.0.0-rc11`, with no CR in the file.
- [x] `poetry run check-vendored` reports the ctld pin up to date.
- [x] `poetry run test-lua` green, `test_community_scripts_load.lua` among the suites that ran.
- [x] `test_vendored_pins_match_the_files.py` green.
- [x] Python quality gate clean (ruff check, ruff format --check, mypy).
