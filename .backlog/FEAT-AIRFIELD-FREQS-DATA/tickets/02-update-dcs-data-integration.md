# 02 — Integrate into `update-dcs-data` + bundle the artifact

Status: ⬜ ready
Type: feat

## Context

The parser (ticket 01) must run for every installed theatre and its output must ship
with the tools so `convert-v5` (lot 3) can read it without a DCS install.

## Tasks

- [ ] Wire the parser into `veaf-build update-dcs-data`: iterate the installed
      `Mods/terrains/*` theatres (same discovery as `--airdromes`), write the merged
      `airfield-frequencies.yaml` (all theatres, versioned/header-stamped).
- [ ] Bundle `airfield-frequencies.yaml` for the packaged tools: add it to the
      PyInstaller `datas` **and** to `veaf_build/worker.py`'s extra-data list — mirror
      how `dcs-radio-layouts.yaml` is bundled (FIX-VEAF-BUILD-RADIO-LAYOUT-DATA), with a
      regression test on the extra-data list.
- [ ] Loader helper (bundle path + `importlib.resources` fallback), like the radio
      specs/layouts loaders in `presets_manager`.
- [ ] Developer doc: note the new datamine output in `doc/developer` where
      `airdromes.yaml` / radio specs are documented.

## Definition of Done

- `update-dcs-data` regenerates `airfield-frequencies.yaml` across installed theatres.
- The artifact is bundled (test asserts it is in the packaged data list).
- `ruff`/`mypy`/`pytest` green.
