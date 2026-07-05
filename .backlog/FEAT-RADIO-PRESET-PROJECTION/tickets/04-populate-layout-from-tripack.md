# FEAT-RADIO-PRESET-PROJECTION-04 — populate the layout for every Tripack type

Status: ⬜ ready
Type: feat
Phase: 1
Files: `presets_injector/data/dcs-radio-layouts.yaml`, `test/python/presets_injector/`

## What to build

Populate `dcs-radio-layouts.yaml` with an entry for **every** aircraft type whose
layout in the reference Tripack `radioSettings.lua` is non-trivial (i.e. not a
plain band-based default): the warbird/prop family (restricted bands), the A-10
(deliberate VHF-on-radio-1 order), Mi-24P (channel 0), OH-58D (reserved slots +
two FM), AJS-37 (fusion + specials + modulations), CH-47F, and any other quirk
surfaced by the analysis (§4 of the exploration doc). Prefer a structured
extraction from the fixture over hand transcription where feasible; verify each
entry against the fixture.

## Acceptance criteria

- [ ] Every non-trivial type from the fixture has a layout entry.
- [ ] Band-only types are deliberately left to the default (documented).
- [ ] A test asserts the populated layout reproduces the fixture's per-slot
      channels for the headline types (Mi-24P, OH-58D, AJS-37).
- [ ] Radio-count guard passes for every populated entry against the specs.

## Blocked by

Tickets 02 (schema) and 03 (packer, to validate reproduction).
