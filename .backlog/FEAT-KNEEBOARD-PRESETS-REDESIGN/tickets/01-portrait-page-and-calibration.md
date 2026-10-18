# FEAT-KNEEBOARD-PRESETS-REDESIGN-01 — portrait presets page and calibration page

Status: 🧑 waiting-human
Type: feat
Files: `presets_injector/presets_manager.py`, `presets_injector/presets_injector_worker.py`, `presets_injector/radio_frequency_validator.py`, `presets_injector/data/dcs-radio-layouts.yaml`, `veaf_libs/locales/*.json`, `doc/`

## What to build

Replace `RadioPresetsImageGenerator`'s drawing with the 2:3 layout of the PRD, add the shared calibration page, and the Viggen's `kneeboard_title`.

## Acceptance criteria

- [ ] Every presets page is 1536 × 2304
- [ ] A radio block is titled from the specs (`1. COMM 1 · ARC-210`), the layout's `kneeboard_title` winning
- [ ] A block stops at its last channel; the A-10C II's three radios fit on one page
- [ ] An overflowing preset gets a second page, named `presets_2.png`
- [ ] `KNEEBOARD/IMAGES/00-veaf-calibration.png` is written once when presets pages are, never otherwise
- [ ] Page texts come from `fr.json` / `en.json`
- [ ] Doc updated (mission-maker concept page, developer page), both languages
- [ ] Checked in DCS by David: the page reads undistorted in the default window

## Blocked by

None.
