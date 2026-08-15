# Per-type radio-preset projection

> **Audience: developers.** How the build projects the channel lists
> (`channel_lists`, the "plan mode" of `presets.yaml`) onto each aircraft type's
> physical radios, honouring its hardware quirks (channel 0, reserved slots,
> hardcoded special channels, key-based mapping…), plus channel priority/colour
> and per-type kneeboards ([ADR 0012](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0012-channel-priority-colour-and-ajs37-packing.md)).
>
> Architecture decision: [ADR 0010](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0010-per-type-radio-preset-projection.md)
> (extends [ADR 0003](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/adr/0003-presets-fidelity.md)).
> Upstream analysis: [exploration](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/docs/exploration/RADIO-PRESETS-PER-TYPE-PROJECTION.md).
> Mission-maker side: [`presets.yaml` format](../PIPELINE_REFERENCE.en.md#two-authoring-formats).

---

## The model in brief

The mission-maker declares, once per coalition, **channel lists by functional
radio role** (`channel_lists`) — not by physical radio. At build time, a
**packer** reads each type's real radios from the DCS specs and **projects**
each list onto the matching radio, applying the type's *layout* rule.

```text
channel_lists (mission-maker, by role)
        │
        ▼
   packer  ──reads──►  dcs-radio-specs.yaml   (per-radio bands/modulation, auto-generated)
        │      ──reads──►  dcs-radio-layouts.yaml (per-type quirks, hand-maintained)
        ▼
   PresetDefinition  ──►  existing injector  ──►  unit["Radio"] + kneeboard
```

The packer produces `PresetDefinition` objects and reuses the existing injector,
band validation and kneeboard generation unchanged. An explicit assignment in
`presets_assignments` (legacy format) stays the **manual-override** path: it
always wins over the packer.

## Source files

| File | Role |
|---|---|
| [`dcs-radio-layouts.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/python/veaf-tools/presets_injector/data/dcs-radio-layouts.yaml) | **Source of truth for per-type quirks.** Hand-maintained. Every primitive is documented in the file header. |
| [`dcs-radio-specs.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml) | Per-physical-radio frequency ranges / modulation. **Auto-generated** (`poetry run update-radio-specs`), never hand-edit. |
| [`presets_manager.py`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/python/veaf-tools/presets_injector/presets_manager.py) | The packer and its rules: `_assign_roles_by_position` (band-based default), `_check_layout_radio_count` (count guard), `_channel_list_for_role` (role resolution). |

## Radio roles (fixed vocabulary)

The role carries the frequency band; a channel lacking that band is dropped from
the list (reported under `validate`, silent under `build`).

| Role | Meaning |
|---|---|
| `primary_1` | 1st V/UHF radio (UHF band) |
| `primary_2` | 2nd V/UHF radio (VHF band); also the warbirds' single radio |
| `fm_substitute` | FM as a 2nd radio (helicopters with a single V/UHF) |
| `fm_supplement` | FM atop two V/UHF radios (attack aircraft) |
| `fm_secondary` | a 2nd supplemental FM (e.g. OH-58D); defaults to a copy of `fm_supplement` |

## Band-based default (types with no layout entry)

A type absent from `dcs-radio-layouts.yaml` goes through the
`_assign_roles_by_position` default: each physical radio is classified by its
frequency ranges, radios unambiguously dedicated to one sub-band are assigned
directly — so a deliberately inverted order (the A-10's VHF-first radio 1)
resolves without an explicit entry — and physical order is only a fallback for
genuinely ambiguous combo radios (the F/A-18's two identical ARC-210s).

This is why **A-10C and A-10C_2 are deliberately absent** from the layout file:
their VHF-first ordering and the ARC-210's wide-band ambiguity are already
resolved correctly by the default.

## Quirk primitives

Declared per physical radio (1-based index, specs / `.miz` order) in
`dcs-radio-layouts.yaml`:

| Primitive | Effect |
|---|---|
| `rotate_last_to_head: true` | **Channel-0 rotation**: the list's last entry moves to the head (slot 1), the rest follows in 2..N. |
| `keyed_groups: {block_size, bases}` | **Key-based mapping** (ADR 0012): several roles share one radio, each channel placed by its **key** (Group = `base + key`, slot = `((Group − min_base) mod block_size) + 1`). Gaps preserved, overflow wraps to slot 1 (the Viggen's Group 100 recycles `primary_2`'s 20th channel). A key beyond the role's share (`block_size / number_of_roles`) is dropped + `WARNING`. |
| `trailing_specials: [{…}, …]` | **Special channels at the tail.** Each entry is either an **airframe constant** `{freq, mod}` (e.g. the Viggen's E/F/G) or **plan-sourced** `{priority: N}` — the frequency comes from the channel tagged `priority: N` (always AM; slot left empty if absent). Optional `label` = pilot name (Sp1, H…). Maker-overridable via `presets_assignments`. |
| `reserved_head_slots: [idx, …]` | **Reserved head slot(s)** fed by a list index ("M" / "C" slot). `[20]` = last entry moved to the head; `[1, 20]` = first duplicated at the head then last moved. Mutually exclusive with `rotate_last_to_head`. |
| `capacity: <int>` | Radio's **physical capacity**: the excess is truncated at the tail (silent, debug log). |

**Composition order** when several primitives coexist on one radio: base content
(`keyed_groups` *or* the plain role list) → (plain-list path only) rotation *or*
reserved head slots (mutually exclusive) → `trailing_specials` appended (at the
block boundary for `keyed_groups`, else right after the content) → `capacity`
truncation.

The packer also checks the declared radio count against the real specs and logs
a `WARNING` on drift (`_check_layout_radio_count`) — useful after a DCS patch
changes an aircraft's radio count.

## Types with a quirk (current state)

These types have an explicit entry in `dcs-radio-layouts.yaml`; all others go
through the band-based default.

| Type | Radios | Quirk |
|---|---|---|
| **Mi-24P** | 2 (R-863 V/UHF + R-828 FM) | Radio 1 `primary_1` with **channel-0 rotation**; radio 2 `fm_substitute`, standard. |
| **CH-47Fbl1** | 3 (ARC-186 + ARC-164 + ARC-201D) | Radio 1 `fm_substitute` **with rotation** (a secondary AM band fools the band classifier → explicit entry required); radio 2 `primary_1` with rotation; radio 3 `fm_secondary`. |
| **OH58D** | 4 (UHF, VHF, FM1, FM2) | Radios 1-2: reserved "M" slot (`reserved_head_slots: [20]`). Radios 3-4: "C" + "M" slots (`[1, 20]`). |
| **AJS37** (Viggen) | 1 (V/UHF, 47 slots) | **`keyed_groups`** (Groups 100-139 block: `primary_1` keys 1-20 → 101-120, `primary_2` keys 1-20 → 121-139 + the Group-100 recycle) + **7 `trailing_specials`** at slots 41-47: Sp1/Sp2/Sp3 + H **plan-sourced** (`priority` 1-4), E/F/G **hardcoded**. Deliberately breaks ADR 0003 iso-functionality (slot 1 = `primary_2`'s 20th, not a dummy). |

The slot-by-slot detail of each type (with comments explaining every choice)
lives directly in
[`dcs-radio-layouts.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/python/veaf-tools/presets_injector/data/dcs-radio-layouts.yaml).

## Channel priority and colour (ADR 0012)

Two optional attributes the mission-maker sets on a plan entry (`channel_lists`):

- **`priority: N`** — importance rank. **Universal**: the channel is highlighted
  on every kneeboard (`Pn` marker + orange Name/Freq cells). **Viggen routing**:
  priorities 1-4 fill FR22 Special 1/2/3 + FR24 H (band from the role:
  `primary_1`→UHF, `primary_2`→VHF; always AM). One entry per value; `priority`
  is **not** read from `channels_collection`.
- **`color: <name|#RRGGBBAA>`** — visually groups channels by filling the **CH**
  cell (text auto-contrasted). Accepted in `channel_lists` **and**
  `channels_collection` (the plan entry overrides the definition). An unknown
  name → `WARNING` + uncoloured channel. Presentation only; no effect on packing.

## Per-type kneeboards (ADR 0012)

> Ten Flaming Cliffs aircraft have no settable radio and get a kneeboard **only**: see
> [`kneeboard_only`](../mission-maker/dcs-radio-specs.en.md#kneeboard-only).

The build renders **one kneeboard per injected `(coalition, type)`**, dropped in
that type's DCS folder: `KNEEBOARD/<type>/IMAGES/presets.png` (coalition-suffixed
only when the same type flies for both sides). This replaces the old generic
`KNEEBOARD/IMAGES/` folder. The title is the concrete type. Radio header bars are
**grey** (the old red/green/orange coding is gone). For the AJS-37, the CH column
shows **pilot labels** (`100`-`139` then `Sp1/Sp2/Sp3/E/F/G/H`) and its 47-slot
radio is **split across two columns**.

## Adding or fixing a type

1. Identify the aircraft's physical radios in
   [`dcs-radio-specs.yaml`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/src/python/veaf-tools/presets_injector/data/dcs-radio-specs.yaml)
   (index, bands) — see also the readable table
   [`dcs-radio-specs.md`](../mission-maker/dcs-radio-specs.en.md).
2. Check whether the band-based default is enough (often yes). If not, add an
   entry in `dcs-radio-layouts.yaml` with the index → role mapping and the
   needed primitives; comment each radio (name + band).
3. Cover the behaviour with a test in
   [`test/python/presets_injector/`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/tree/develop/test/python/presets_injector)
   (layout fidelity, capacity, the AJS-37 case…).
