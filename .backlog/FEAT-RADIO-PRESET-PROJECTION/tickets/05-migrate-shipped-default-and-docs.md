# FEAT-RADIO-PRESET-PROJECTION-05 — migrate shipped default + docs

Status: ⬜ ready
Type: feat
Phase: 1
Files: `src/defaults/mission-folder/src/presets.yaml`, `doc/PIPELINE_REFERENCE*.md`, `doc/mission-maker/dcs-radio-specs.md`

## What to build

Migrate the shipped default `presets.yaml` (`src/defaults/mission-folder/src/`) to
the new `channel_lists` model, so the shipped default demonstrates the preset plan
(defaults-lockstep rule, CLAUDE.md §9.7). Keep `channels_collection` as the
frequency source. Update the mission-maker docs (Pipeline Reference §1 — Radio
presets; the DCS radio specs page) to document `channel_lists`, the radio roles,
the layout file, and the manual-override path. FR + EN doc pages in lockstep.

## Acceptance criteria

- [ ] Shipped default `presets.yaml` uses `channel_lists` (with a role per radio).
- [ ] `channels_collection` unchanged as the frequency source.
- [ ] Pipeline Reference (FR + EN) documents the preset plan model + override.
- [ ] A build using the shipped default produces valid radios (existing default
      scaffold / mission-builder defaults tests still green).

## Blocked by

Tickets 01–03 (model must exist to migrate onto it).
