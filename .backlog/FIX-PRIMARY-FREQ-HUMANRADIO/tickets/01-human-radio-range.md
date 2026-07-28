# 01 — Gate the primary-frequency promotion on the aircraft's HumanRadio range

Status: ✅ done

## Goal

Stop the presets injector from writing a group primary `frequency` the DCS Mission Editor
refuses, by extracting the `HumanRadio` min/max range into the radio specs and checking the
promoted channel against it.

## Definition of Done

- [x] `radio_specs_updater.py` parses `HumanRadio` and emits `human_radio:` per aircraft
- [x] `dcs-radio-specs.yaml` + `doc/mission-maker/dcs-radio-specs.md` regenerated at the
      pinned `DATAMINE_REF` (CI consistency guard passes)
- [x] `radio_frequency_validator.get_human_radio()` / `fits_human_radio()` added
- [x] `process_units` promotes channel 1 only when it fits `human_radio`
- [x] Unit tests for extraction, validator and the promotion guard; FW-190A8 @ 134 MHz no
      longer promoted, F-16C and MiG-15bis unaffected
- [x] `doc/mission-maker/scripts/` / presets doc mention the primary-frequency rule
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` + `plugin.json`
- [x] mypy exclusion for `presets_injector_worker` dropped if listed (ratchet policy)
