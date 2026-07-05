# FEAT-RADIO-PRESET-PROJECTION-06 — populate the full layout + capacity/truncation

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

With every primitive available, populate `dcs-radio-layouts.yaml` for the
remaining non-trivial types in the reference Tripack fixture (A-10 with the
deliberate VHF-on-radio-1 order, CH-47F, and any other quirk from §4 of the
analysis), and implement the **slot capacity** primitive with truncation when a
list exceeds a radio's capacity (recorded; verbose under `validate`, silent under
`build`). Band-only types are deliberately left to the default and documented as
such.

## Acceptance criteria

- [x] Every non-trivial fixture type has a layout entry (A-10, CH-47F, …).
- [x] Slot capacity + truncation implemented and reported.
- [x] Band-only types documented as intentionally default.
- [x] Radio-count guard passes for all populated entries.
- [x] A test asserts the populated layout reproduces the fixture for the headline
      types.

## Blocked by

- FEAT-RADIO-PRESET-PROJECTION-02
- FEAT-RADIO-PRESET-PROJECTION-03
- FEAT-RADIO-PRESET-PROJECTION-04
- FEAT-RADIO-PRESET-PROJECTION-05

## Implementation notes

**Slot capacity primitive.** New optional `RadioLayoutRadio.capacity: int | None`
field, parsed from a `capacity: <int>` key in `dcs-radio-layouts.yaml`. Applied
in `_content_for_radio` as the LAST composition step (after rotation/reserved
slots, leading dummy, and trailing specials), via a new `_truncate_to_capacity`
helper: when the fully composed channel count exceeds `capacity`, the excess is
dropped from the END of the list and the survivors renumbered 1..capacity. A
truncation logs one `logger.debug` line (`presets_injector.radio_layout.capacity_truncated`,
en+fr) with the unit type, radio index, capacity and dropped count — matching
ticket 05's silent-under-build / no-warning-noise convention (exploration doc
§8.4); no new reporting subsystem was added, since the packer has no group/
mission context to feed the existing `FrequencyIssue`/validation-report
mechanism, and a debug log is sufficient per the ticket's own guidance. No
aircraft in the reference fixture actually needs it today — the AJS-37's
47-slot fused radio is already an exact fit (confirmed by
`test_radio_preset_ajs37.py`'s `len(channels) == 47` assertion) — so the
primitive ships available but unused in `dcs-radio-layouts.yaml`, ready for the
next aircraft that needs it.

**CH-47Fbl1 fix.** Real `dcs-radio-specs.yaml` data: radio 1 "VHF FM: ARC-186"
has ranges `[30-88 FM, 108-116 AM, 116-152 AM]` — the secondary AM range pushes
`_classify_radio` to return `"vhf"` (reaches above the FM ceiling into the
V/UHF window) instead of recognizing the radio's real FM role, so the default
projection puts `primary_2` on it instead of an FM role — pinned by a new test
using the REAL specs (`TestDefaultMisclassifiesCh47fWithoutLayoutEntry` in
`test_radio_preset_ch47f.py`) before adding the fix. Added an explicit
`CH-47Fbl1` entry: radio 1 (ARC-186) → `fm_substitute` + `rotate_last_to_head`,
radio 2 (ARC-164, UHF) → `primary_1` + `rotate_last_to_head` (both rotations
match the real Tripack fixture, which rotates both radios exactly like the
Mi-24P), radio 3 (ARC-201D, a clean second FM set) → `fm_secondary` with no
primitive — declared so the radio-count guard matches the specs' real 3-radio
count, but produces no content unless the maker declares a distinct
`fm_secondary` list (`_channel_list_for_role` defaults `fm_secondary` to
`fm_supplement`, which the shipped default's `channel_lists.blue` does not
declare — see below).

**A-10C / A-10C_2 — intentionally absent.** Both are already resolved
correctly by `_assign_roles_by_position`'s band-based default (confirmed by
`test_radio_preset_packer.py::TestPackPresetRealSpecsEndToEnd` for A-10C's
VHF-first order, and `test_channel_lists.py::TestShippedDefaultMigration` for
A-10C_2's ARC-210, both already merged from tickets 01/07). Documented directly
in `dcs-radio-layouts.yaml`'s header comment (pointing at those two tests) so a
future maintainer does not wonder why they are missing, per this ticket's
acceptance criterion — no code change needed, no entry added.

**Other §4 quirks — no further entries needed.** §4.2's "minor quirks" (A-10C's
trailing empty/AM channels, CH-47F's flat `modulations` table) do not break the
1:1 mapping and are not reproduced as new primitives — they either already work
through the existing per-channel modulation support (ticket 04) or are cosmetic
artifacts of the source data, not layout concerns. §4.3's restricted-band
warbirds/prop/ADF families are validation-only concerns, already fully covered
by `dcs-radio-specs.yaml` + the frequency validator + ticket 05's regression
test — no layout entry warranted.

**Shipped default's CH-47Fbl1 `presets_assignments` override — kept, not
removed.** Verified empirically: the legacy override only ever populates 2
radios (FM then UHF, `modern_blue_fm_uhf`). Packing the new layout entry
against the shipped default's actual declared lists (`primary_1` +
`fm_supplement`, no `fm_substitute`/`fm_secondary`) either produces no radio 1
content at all (if radio 1 is mapped to `fm_substitute`, which the shipped
default never declares) or produces an unwanted 3rd radio (if radio 3 is mapped
to a role that resolves to `fm_supplement`'s list, which the shipped default
DOES declare) — neither reproduces the legacy 2-radio-only result byte-for-byte
without either changing the shipped default's channel_lists shape or adding
per-type content-suppression logic, both out of this ticket's scope. Removing
the override is left as a follow-up once the shipped default itself is
revisited (e.g. if it starts declaring a role vocabulary that naturally leaves
the 3rd radio empty).

**Full-lot regression test.** `test/python/presets_injector/test_radio_preset_full_layout_fidelity.py`
exercises `pack_preset_for_type` against the real bundled `dcs-radio-specs.yaml`
+ `dcs-radio-layouts.yaml` (no mocks) for Mi-24P (rotation), AJS-37 (fusion +
dummy + specials + modulation + exact 47-slot fit), OH-58D (reserved head
slots) and CH-47F (the role fix), confirming all five tickets' primitives still
compose correctly together in the shipped layout file.
