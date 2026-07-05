---
status: accepted
---

# Per-type radio-preset projection (the preset plan model)

Extends [ADR 0003](0003-presets-fidelity.md). Analysis:
[RADIO-PRESETS-PER-TYPE-PROJECTION](../exploration/RADIO-PRESETS-PER-TYPE-PROJECTION.md).

## Context

The v6 presets subsystem factorises frequencies (`channels_collection`) but the
per-radio channel maps are authored by hand: `radios_collection` →
`presets_collection` → `presets_assignments`. Aircraft with non-1:1 radio
layouts — Mi-24P channel-0 rotation, OH-58D reserved "M" channel, AJS-37 leading
dummy + hardcoded specials + per-channel modulations — each need a bespoke
preset, and a change to the mission's frequencies does not propagate to them.

We want the mission-maker to declare a small set of channel lists **once** and
have the build project them onto every aircraft's physical radios, honouring each
type's quirks automatically.

## Decision

**Preset plan model.** The mission-maker declares _Channel lists_ per _Radio
role_ and coalition; a per-type _Radio layout_ (VEAF-maintained) drives a packer
that projects the lists onto physical radios. Terms are defined in
[CONTEXT.md](../../CONTEXT.md).

- **Radio roles** (fixed vocabulary): `primary_1` (UHF), `primary_2` (VHF; also
  the warbirds' single radio), `fm_substitute` (FM as 2nd radio, helicopters),
  `fm_supplement` (FM atop two V/UHF, attack aircraft), `fm_secondary` (a 2nd
  supplemental FM e.g. OH-58D; defaults to a copy of `fm_supplement`). The role
  carries the frequency band; a channel lacking that band is dropped from the
  list — reported under `validate`, silent under `build`.
- **Radio layout** — `dcs-radio-layouts.yaml`, hand-maintained beside the
  auto-generated `dcs-radio-specs.yaml`, keyed by type (exact or regex). It maps
  each physical radio — by **index** (specs/`.miz` order, with clear comments) —
  to a role, plus primitives: channel-0 rotation, reserved head slots (the
  list's last entry, #20, by convention), hardcoded trailing specials, radio
  fusion, slot capacity, per-channel modulation. Types with no entry use
  band-based defaults. The packer cross-checks the layout's radio count against
  the specs and flags any drift.
- **Packer as a generator overlay.** The packer produces `PresetDefinition`
  objects and reuses the existing injector, band validation and kneeboard
  generation unchanged. The old layers remain the **manual-override** path: an
  explicit preset assigned to a type wins over the packer.
- **convert-v5** generates a preset plan **by default** (from the v5
  `radioPresets*` tables), falling back to a **faithful per-aircraft v5 copy**
  (the ADR 0003 behaviour) when the mission cannot be factored — warning the
  maker. This **inverts ADR 0003's default**: the faithful copy becomes the
  safety net, not the primary outcome. When the layout encodes the same quirks
  the v5 used, "generate plan + pack" reproduces the same channels, so the
  default is faithful by construction in the common case.

Sequencing — **phase 1**: the core (channel lists, layout file, packer, layout
populated for every type in the reference Tripack file, shipped-default
migration, tests). **Phase 2**: convert-v5 plan generation.

## Consequences

- One place to change a mission's frequencies; special aircraft follow
  automatically; a new special airframe is handled by VEAF (one layout entry),
  not by the maker.
- Two authoring formats coexist **indefinitely** (the preset plan, and the old
  layers as override); the parser reads both. No deprecation.
- The radio layout is hand-maintained data to populate and keep in sync with the
  specs after DCS patches — the radio-count guard flags drift.
- convert-v5 no longer guarantees iso-functionality by default; the faithful
  copy stays available as the fallback.

## Implementation note (ticket 01)

The "band-based default" is **not** a flat positional rule (radio 1 -> primary_1,
2 -> primary_2, 3 -> FM). Verified against the real `dcs-radio-specs.yaml`: only
19 of 87 aircraft have radios that are cleanly single-band throughout — most
modern radios (ARC-210, ARC-222…) report the union of every mode they support,
and some 2-radio helicopters mean "1 primary + 1 FM", not "UHF + VHF". The
implemented default classifies each physical radio from its frequency ranges,
assigns radios unambiguously dedicated to one sub-band directly (so a
deliberately inverted order, e.g. the A-10's VHF-first radio 1, resolves without
an explicit layout entry), and falls back to physical order only for genuinely
ambiguous combo radios (e.g. the F/A-18's two identical ARC-210s). See
`_assign_roles_by_position` in `presets_manager.py`. This does not change the
decision — a simple default for the common case, explicit `Radio layout`
override for the rest — only the mechanism.

## Alternatives rejected

- **Replace the old layers** — breaks existing missions and convert-v5.
- **Two parallel systems the maker picks between** — two models to learn and
  maintain.
- **Band-based role deduction alone** — fails for wide-band radios (A-10C_2
  ARC-210) and deliberate orderings (the A-10 wants VHF on radio 1); hence the
  explicit, VEAF-fixed slot→role mapping in the layout.
