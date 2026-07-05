# FEAT-RADIO-PRESET-PROJECTION-03 — reserved head slots + fm_secondary (OH-58D)

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

Implement the **reserved head slot(s)** primitive (default fill = the list's last
entry #20; the OH-58D FM adds a second head slot filled from #01), and the
`fm_secondary` role (defaults to a copy of `fm_supplement` when the mission-maker
does not define it). Demonstrate end-to-end on the OH-58D: UHF/VHF radios get a
reserved "M" head slot; FM1/FM2 get "C"+"M" head slots; the two FM radios receive
`fm_supplement` and `fm_secondary`.

Verifiable end-to-end: the OH-58D's "no channel 1" layout is reproduced.

## Acceptance criteria

- [x] Reserved head slot primitive (count + fill entry) implemented.
- [x] `fm_secondary` role; absent → copy of `fm_supplement`.
- [x] OH-58D reproduced: M/C head slots on the right radios.
- [x] Tests (prior art `test_presets_fidelity.py`).

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02 (needs its `dcs-radio-layouts.yaml` file + parser
  + packer-override wiring — corrected from the original "01 only" dependency,
  which assumed that plumbing already existed)

## Note

`fm_secondary` defaulting to a copy of `fm_supplement` was already implemented in
ticket 01 (it fell out naturally from the role-assignment pass). This ticket's
remaining scope is the **reserved head slot** primitive and the OH-58D layout
entry.

## Implementation notes

- Schema: `dcs-radio-layouts.yaml` radios gain a second, optional primitive key,
  `reserved_head_slots: [<list index>, ...]`, alongside ticket 02's
  `rotate_last_to_head`. Each entry is a **1-based index into the channel
  list** that fills one leading DCS channel slot, in the declared order.
  **Only the index matching the list's actual last entry is removed from its
  original tail position** (rotation semantics, the same convention as
  `rotate_last_to_head`); any other reserved index is a leading **duplicate**
  that also stays in its original tail position. Two shapes populated so far:
  `[20]` (a single "M" slot fed by the list's last entry, removed from the
  tail — a 20-entry list still produces 20 slots total — OH-58D UHF/VHF) and
  `[1, 20]` (a "C" slot duplicating the list's first entry — which stays in
  the tail too — then an "M" slot fed by the last entry, removed from the
  tail — a 20-entry list produces 21 slots total — OH-58D FM1/FM2). The two
  primitives are mutually exclusive per radio: declaring both on the same
  radio entry is a rejected authoring error (`parse_radio_layouts` raises
  `ValueError`). The file's header comment documents the schema in full for
  ticket 06 to extend.
- `RadioLayoutRadio` gains a `reserved_head_slots: list[int]` field (default
  `[]`). New `_prepend_reserved_slots` function (parallel to
  `_rotate_last_to_head`): produces a renumbered `RadioDefinition` copy with
  the reserved entries first, then the tail (the list minus only the
  last-entry index, if it was one of the reserved ones). An index that is not
  a valid 1-based position (`<= 0`, or beyond the list's actual length) is
  skipped rather than raising — safe degradation for a shorter-than-expected
  maker list, consistent with `pack_preset_for_type`'s existing HF-radio
  fallback philosophy. `parse_radio_layouts` also tolerates a non-integer
  `reserved_head_slots` entry (malformed YAML): logged via a new i18n key
  (`presets_injector.radio_layout.invalid_reserved_head_slot`) and skipped,
  rather than aborting the whole layout file's parsing.
- Landed after ticket 04 (AJS-37 fusion/specials/modulation) merged first and
  restructured the same dispatch: `_content_for_radio` now applies all
  declared primitives in a fixed composition order (fusion/base content, then
  rotation-or-reserved-slots — mutually exclusive with each other — then
  leading dummy, then trailing specials). `reserved_head_slots` slots into
  that pipeline as an `elif` alongside `rotate_last_to_head`, rather than
  needing its own tuple-threading through `_resolved_slots_for_type` as
  originally implemented pre-rebase.
- OH-58D layout entry (4 physical radios, verified against the real
  `dcs-radio-specs.yaml` — unit_type is `OH58D`, no hyphen): radio 1 (UHF)
  `primary_1` + `reserved_head_slots: [20]`; radio 2 (VHF) `primary_2` +
  `reserved_head_slots: [20]`; radio 3 (FM1) `fm_supplement` +
  `reserved_head_slots: [1, 20]`; radio 4 (FM2) `fm_secondary` +
  `reserved_head_slots: [1, 20]` (content defaults to `fm_supplement`'s list
  via ticket 01's `_channel_list_for_role`, independent of the primitive
  declared on the radio). Note: the raw Tripack fixture
  (`tripack_radioSettings.lua`, `["blue OH-58D"]`) itself has a stale/buggy
  head-slot fill (duplicates entry #01 instead of reserving #01 then #20) —
  implemented per ADR 0010's resolved decision and the exploration doc's §8
  analysis instead of literally reproducing that fixture bug.
