# FEAT-RADIO-PRESET-PROJECTION-01 — full chain on a standard aircraft

Status: ✅ done
Type: feat · Phase: 1 · AFK

## Parent

Lot [FEAT-RADIO-PRESET-PROJECTION](../PRD.md) · [ADR 0010](../../../docs/adr/0010-per-type-radio-preset-projection.md)

## What to build

The founding tracer bullet: the complete path for a standard 1:1 aircraft. Parse
a `channel_lists` block (per coalition, roles `primary_1`/`primary_2`/`fm_*`),
resolve each role to its band from `channels_collection`, deduce the role of each
physical radio from the specs (band-based default, no layout file yet), pack a
`PresetDefinition`, and let the existing injector write `unit["Radio"]`. A channel
lacking the role's band is dropped. An explicit old-format preset assigned to a
type still wins over the packer (manual override, ADR 0010).

Verifiable end-to-end: an F-16 receives its UHF/VHF/FM lists on the right radios;
a type with an explicit override keeps it.

## Acceptance criteria

- [x] `channel_lists` parsed per coalition into roles; aliases resolve by band.
- [x] Default maps a standard aircraft's radios to roles from the specs.
- [x] Packer emits a `PresetDefinition`; downstream injection/validation reused.
- [x] Channel lacking the role's band is dropped (recorded).
- [x] Explicit old-format assignment wins over the packer.
- [x] Tests: parsing + a standard aircraft packed end-to-end (prior art
      `test_presets.py`, `test_presets_injector_worker.py`).

## Blocked by

None — can start immediately.

## Implementation notes

The default is **not** the flat "radio 1 -> primary_1, radio 2 -> primary_2,
radio 3 -> FM" positional rule the ticket description sketched. Verified against
the real `dcs-radio-specs.yaml`: only 19 of 87 aircraft have radios that are
cleanly single-band throughout — most modern radios (ARC-210, ARC-222…) report
the union of every mode they support, and some 2-radio helicopters (Mi-8MT,
UH-1H-shaped) mean "1 primary + 1 FM", not "UHF + VHF". A pure radio-count or
band-purity heuristic misclassifies the F-16 (this ticket's own worked example),
the Hornet, and most helicopters.

The implemented default instead classifies each physical radio from its ranges
(uhf-dedicated / vhf-dedicated / ambiguous combo / FM-or-other), assigns
dedicated radios to their natural role directly (so the A-10's inverted
VHF-first order resolves correctly with **no** explicit layout entry), and falls
back to physical order only for genuinely ambiguous combo radios (e.g. the
Hornet's two identical ARC-210s). See `_classify_radio` / `_assign_roles_by_position`
in `presets_manager.py` for the reasoning, and
`TestPackPresetRealSpecsEndToEnd` in `test_radio_preset_packer.py` for the
regression coverage against real aircraft (F-16, F/A-18, A-10, UH-1H, Mi-8MT,
Bf-109K-4).

This does not reopen ADR 0010's decisions — the outcome (simple default for the
common case, explicit `Radio layout` override for the rest) is unchanged; only
the *mechanism* differs from the ADR's illustrative sketch. `fm_secondary`
defaulting to a copy of `fm_supplement` (ticket 03's stated behaviour) is
implemented here too, since it falls out naturally from the same role-assignment
pass.
