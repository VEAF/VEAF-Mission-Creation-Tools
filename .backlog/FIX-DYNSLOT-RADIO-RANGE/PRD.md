# FIX-DYNSLOT-RADIO-RANGE — the La-7 templates carry a frequency DCS 2.9.31 no longer accepts

Status: 🔄 in progress

Origin: David opening a built "Marteau du Golan" (`VEAF_Syria_MarteauDuGolan_20261028.miz`) in the Mission Editor on 2026-10-29: « Mission cannot be saved due to errors! La-7 Template: Invalid frequency 118.6 MHz / La-7 Template Red: Invalid frequency 121.5 MHz ».

## Problem Statement

DCS 2.9.31.29434 (datamine dump of 2026-10-28) replaced the La-7's radio: its `HumanRadio` went from 100–156 MHz (SCR-522, default 124) to 3.7–6.06 MHz AM (HF, default 3.7), and its `panelRadio` block is gone.

The two shipped La-7 dynamic-slot templates carry `frequency: 121.5`, valid when they were grafted on 2026-09-21 (b03ac841, extracted from a mission saved in the editor of the time).
The blue one gets 118.6 on top of it: the presets injector promotes channel 1 of its preset, which `fits_human_radio` let through because our radio specs were pinned to the 2.9.30 dump (`DATAMINE_REF` `fdd11ed9`, 2026-09-30).

## Measured

Every template of `src/defaults/mission-folder/src/dynamic-slot-templates.yaml` (122 groups) checked against the `HumanRadio` of its type in the 2026-10-28 datamine dump, which is the build installed on DAVID-BUREAU (`2.9.31.29434`):

- out of range: `La-7 Template` and `La-7 Template Red` (121.5 MHz, allowed 3.7–6.06), and nothing else;
- no bounds to check (`HumanRadio` without `minFrequency`/`maxFrequency`, the Flaming Cliffs airframes): F-15C, J-11A, MiG-29A/G/S, Su-25, Su-25T, Su-27, Su-33 — both coalitions;
- every template type has a `HumanRadio` block in the dump.

## Root cause

Two layers:

1. The radio specs were a DCS version behind: `DATAMINE_REF` had not been bumped past 2.9.30.
2. Bumping it alone loses the La-7 instead of fixing it: `extract_all_specs` emits an aircraft only when it has a `panelRadio`, and the new La-7 has only a `HumanRadio`. An aircraft absent from the specs is *unknown*, and every check is permissive on an unknown type — so the injector would still promote a VHF channel 1, and nothing would flag 121.5. The MiG-15bis has been in that situation all along: its overlay entry declares its HF radio, but its `HumanRadio` bounds were never carried.

## Solution

- Bump `DATAMINE_REF` to the 2.9.31.29434 dump and regenerate countries, units and radio specs.
- `extract_all_specs` keeps an aircraft that has a bounded `HumanRadio` but no `panelRadio`, with no radio; `apply_overrides` fills such an entry from its `add_aircraft` declaration; radio-less entries left after the overlay are dropped, so the AI-only airframes stay out of the specs as before.
- Declare the La-7's HF radio in `dcs-radio-specs-overrides.yaml`, like the MiG-15bis. Its VHF preset channels are then out of range, so it gets no preset and no promoted channel.
- Set both La-7 templates to 3.7 MHz, the radio's own default.
- A catalogue invariant: every template's frequency fits its type's `human_radio`.

## Out of scope

- Probing whether DCS still stores a `Radio` preset table for a La-7 with no `panelRadio`: the specs say no channel fits, so none is written.
- Listing radio-less airframes in the generated primary-frequency table of `dcs-radio-specs.md`.
