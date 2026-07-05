# FEAT-RADIO-PRESET-PROJECTION-07 — migrate shipped default + docs

Status: ✅ done
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

- [x] Shipped default uses `channel_lists` (a role per radio).
- [x] `channels_collection` unchanged as the frequency source.
- [x] Pipeline Reference FR + EN document the preset plan + override.
- [x] Existing default-scaffold / mission-builder-defaults tests stay green.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01

## Implementation notes

The legacy shipped default assigned the same generic preset (`radio_uhf_30` /
`radio_vhf_30` / `radio_fm_30`, i.e. UHF+VHF+FM) to `blue.plane.all` and
`blue.helicopter.all`, with three explicit `presets_assignments` overrides.
Migrated to `channel_lists.blue`: `primary_1` (was `radio_uhf_30`), `primary_2`
(was `radio_vhf_30`), `fm_supplement` (was `radio_fm_30`) — same 30-channel
lists, verbatim frequencies, now declared once instead of duplicated per
preset. `channels_collection` is untouched.

Verified empirically (`pack_preset_for_type` / `PresetsManager.get_radios_for`
against the real shipped file) for each of the three overrides:

- **`A-10C_2: modern_blue_vhf_uhf_fm` — removed.** The packer's default band
  classification (ticket 01) already resolves `A-10C_2`'s ARC-210 the same way
  it resolves plain `A-10C`: VHF list on physical radio 1, UHF list on radio 2,
  FM on radio 3 — byte-for-byte identical to what the legacy override produced.
  No `presets_assignments` entry needed anymore.
- **`CH-47Fbl1: modern_blue_fm_uhf` — kept.** The legacy preset put only 2
  radios on the CH-47 (FM, then UHF). The packer's default classifies the
  CH-47's 1st physical radio (`VHF FM: ARC-186`, whose range extends into
  108–152 MHz) as VHF-capable rather than FM, so its own default would put the
  VHF list there and add an unwanted 3rd (VHF) radio overall — not what the
  legacy preset produced (FM + UHF only). Kept the explicit override to
  preserve the intended 2-radio layout; noted as a possible packer
  classification edge case below (not fixed here — out of this ticket's scope
  per the "do not touch presets_manager.py" caution).
- **`Mi-8MT: none` — kept as-is.** `none` (disable injection entirely) has no
  `channel_lists` equivalent; this is exactly ADR 0010's manual-override
  escape hatch.
- **Red coalition — kept as-is** (`all: none` for both plane and helicopter).
  No mission-content behaviour change intended by this ticket; git history
  showed no rationale to revisit, so the safe default (unchanged) was kept.

New regression tests added in `test/python/presets_injector/test_channel_lists.py`
(`TestShippedDefaultMigration`) load the real shipped `presets.yaml` via
`PresetsManager.read_yaml` and assert `get_radios_for` reproduces the exact
legacy frequencies/slots for `F-16C_50` (no override, either format), `A-10C_2`
(override dropped), `CH-47Fbl1` (override kept), `Mi-8MT` (explicit `none`
kept), and red coalition (still no injection).

**Possible packer follow-up (not fixed here, flagged for the orchestrating
session's judgement):** the CH-47's `VHF FM: ARC-186` radio spec reports a
108–152 MHz secondary range (an AM navaid/voice band alongside its 30–88 MHz
FM range) that makes `_classify_radio` treat it as `vhf`-capable even though
its module name ("VHF FM") and role are FM-oriented. This is a data/heuristic
edge case in `_classify_radio`'s coarse threshold, not a bug introduced by
this ticket — flagged, not fixed, per this ticket's "do not touch
presets_manager.py" instruction.
