# FEAT-RADIO-PRESET-PROJECTION-02 — radio layout file + parser + band-based defaults

Status: ⬜ ready
Type: feat
Phase: 1
Files: `presets_injector/data/dcs-radio-layouts.yaml` (new), `presets_injector/`, `test/python/presets_injector/`

## What to build

Define and parse `dcs-radio-layouts.yaml` (hand-maintained, beside the
auto-generated `dcs-radio-specs.yaml`), keyed by type (exact or regex). Each entry
maps physical radios **by index** (specs/`.miz` order, with clear comments) to a
role, plus the layout primitives: channel-0 rotation, reserved head slots
(default fill = the list's last entry), hardcoded trailing specials (freq + mod),
radio fusion, slot capacity, per-channel modulation.

Provide the **band-based default** for a type with no layout entry (UHF
radio→`primary_1`, VHF→`primary_2`, FM→`fm_substitute`/`fm_supplement` by V/UHF
count). Add the radio-count guard: cross-check a layout's radio count against the
specs and surface drift under `validate`.

## Acceptance criteria

- [ ] `dcs-radio-layouts.yaml` schema defined + documented (commented indices).
- [ ] Parser reads type (exact + regex) → per-radio role + primitives.
- [ ] Band-based default resolution for types with no entry.
- [ ] Radio-count guard flags layout/specs drift under `validate`.
- [ ] Unit tests for parsing and default resolution.

## Blocked by

None (parallel with 01).
