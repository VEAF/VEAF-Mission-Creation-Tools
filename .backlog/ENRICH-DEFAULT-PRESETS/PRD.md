# Lot ENRICH-DEFAULT-PRESETS — broaden the shipped default radio presets (with Tripack)

Status: ⬜ ready
Branch: feat/enrich-default-presets → PR → develop

## Problem Statement

The shipped default `src/defaults/mission-folder/src/presets.yaml` defines only **3**
preset collections — `Blue coalition - classic UHF/VHF/FM` (standard jets), `inverted
VHF/UHF/FM (A-10)`, and `FM/UHF (CH-47)`. A kneeboard is generated only for a preset
that is **actually used by an aircraft present in the mission** (`used_in_mission`,
`presets_manager.py:821`), so a mission only ships kneeboards for those three airframes;
any other aircraft gets no VEAF radio presets/kneeboard out of the box.

## Solution

Enrich the default presets to cover more aircraft (and the red coalition where
relevant) with sensible default frequencies, **in collaboration with Tripack** — his
real-mission usage drives which airframes and frequency plans matter. Not urgent;
post-current-batch.

## User Stories

1. As a mission-maker, I want sensible default radio presets for more airframes, so
   that more aircraft get a VEAF kneeboard out of the box without hand-authoring.

## Implementation Decisions

- Extend the existing collections; keep the current three working.
- Frequency plans chosen with Tripack from real-mission usage.

## Testing Decisions

- Validate that each added aircraft yields a correct kneeboard.

## Out of Scope

- Reworking the preset data structure (coverage only).

## Further Notes

Lockstep: doc (`veafRadioPresets`/GUIDE) if the structure or coverage is documented.
