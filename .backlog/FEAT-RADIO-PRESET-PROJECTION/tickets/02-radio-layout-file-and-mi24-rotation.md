# FEAT-RADIO-PRESET-PROJECTION-02 — radio layout file + channel-0 rotation (Mi-24P)

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Introduce the hand-maintained `dcs-radio-layouts.yaml` (beside the auto-generated
specs), keyed by type, mapping physical radios by index (with clear comments) to
roles plus primitives. Wire it into the packer as an override of the band-based
default, add the radio-count guard (flag layout/specs drift under `validate`), and
implement the first primitive — **channel-0 rotation** — end-to-end on the Mi-24P
(radio 1 rotates the list's last entry to the head; radio 2 = `fm_substitute`).

Verifiable end-to-end: the Mi-24P shows the rotated channel 0.

## Acceptance criteria

- [x] `dcs-radio-layouts.yaml` parsed (exact type + regex), radios by index.
- [x] Layout entry overrides the band-based default for its type.
- [x] Channel-0 rotation primitive implemented; Mi-24P reproduced.
- [x] `fm_substitute` role reaches the Mi-24P FM radio.
- [x] Radio-count guard flags drift under `validate`.
- [x] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-01

## Implementation notes

- Schema: `dcs-radio-layouts.yaml` top-level keys are unit_type strings (exact
  match first, then `re.fullmatch` regex fallback — mirrors
  `PresetAssignmentCollection._match_unit_type`). Each entry has a `radios` map
  keyed by **1-based physical radio index**; each radio has a mandatory `role`
  and optional primitive flags — so far only `rotate_last_to_head: true`
  (channel-0 rotation). The file's header comment documents the schema in full
  for tickets 03/04 to extend.
- New `presets_manager.py` pieces: `RadioLayoutRadio`/`RadioLayoutEntry`
  dataclasses, `parse_radio_layouts`, `get_radio_layout` (exact+regex lookup),
  `_check_layout_radio_count` (the radio-count guard), `_rotate_last_to_head`
  (the rotation primitive, produces a renumbered `RadioDefinition` copy). The
  bundled file is cached module-level via `_load_radio_layouts`, same pattern
  as `radio_frequency_validator._load_specs`.
- `_resolved_slots_for_type` now consults `get_radio_layout` first; when an
  entry exists it fully replaces `_assign_roles_by_position`'s role assignment
  for that type (not merged/blended) and carries a per-radio rotation flag
  through to `pack_preset_for_type`, which applies `_rotate_last_to_head` when
  building that radio's channel content.
- The radio-count guard runs at pack time (not a separate `validate` pass —
  there is no dedicated validate/build verbosity split for this concern yet)
  and logs via `logger.warning` (i18n key
  `presets_injector.radio_layout.count_mismatch`, added to en.json/fr.json to
  satisfy the repo's no-hardcoded-prose i18n test).
- Mi-24P entry: radio 1 (R-863) `primary_1` + `rotate_last_to_head: true`;
  radio 2 (R-828) `fm_substitute`. Verified end-to-end against the real
  `dcs-radio-specs.yaml` (2 radios) and reproduces the Tripack fixture's
  channel-0 rotation (list entry #20 at DCS channel slot 1, #1..#19 at slots
  2..20), uniformly for both coalitions (rotation is an airframe property).
