# FEAT-RADIO-PRESET-PROJECTION-07 — migrate shipped default + docs

Status: ⬜ ready
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Migrate the shipped default `presets.yaml` (`src/defaults/mission-folder/src/`) to
the `channel_lists` preset plan so the shipped default demonstrates the new model
(defaults-lockstep, CLAUDE.md §9.7), keeping `channels_collection` as the
frequency source. Update the mission-maker docs (Pipeline Reference §1 and the DCS
radio specs page, FR + EN) to document channel lists, roles, the layout file, and
the manual-override path.

## Acceptance criteria

- [ ] Shipped default uses `channel_lists` (a role per radio).
- [ ] `channels_collection` unchanged as the frequency source.
- [ ] Pipeline Reference FR + EN document the preset plan + override.
- [ ] Existing default-scaffold / mission-builder-defaults tests stay green.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01
