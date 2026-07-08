---
status: accepted
---

# Channel priority, colour, and the AJS-37 packing (extends ADR 0010)

Extends [ADR 0010](0010-per-type-radio-preset-projection.md); deliberately
breaks [ADR 0003](0003-presets-fidelity.md)'s iso-functionality for the AJS-37
(see Consequences). Terms defined in [CONTEXT.md](../../CONTEXT.md).

## Context

ADR 0010 gave the mission-maker a role-based _preset plan_ (`channel_lists`)
that a per-type _Radio layout_ packs onto each airframe's physical radios. Three
gaps surfaced from real use (driver: the **AJS-37 Viggen**):

- The Viggen's FR22 exposes data channels **Group 100–139** plus shortcut
  buttons **Special 1/2/3**; its FR24 backup radio holds **E/F/G/H**. The pilot
  wants **"channel N = Group 10N"** (dial 104 for channel 4). DCS stores all of
  this as one 47-slot `Radio` table. The plan could only reproduce it via
  hardcoded per-type constants (fusion + leading dummy + 7 hardcoded specials),
  none of which the mission-maker could drive.
- Presets produced by the packer (the whole `channel_lists` path) generated **no
  kneeboard at all** — only legacy `presets_collection` presets did — and those
  landed in one shared `KNEEBOARD/IMAGES/` folder with red/green/orange radio
  headers and a title that could carry the layout's regex key.
- Nothing let the mission-maker flag a channel as **important** or **group
  related channels visually** on the kneeboard.

## Decision

**1 — Channel priority.** An optional `priority: <n>` on a plan entry (a
_Channel list_ entry, **never** `channels_collection`). Two independent
consumers:

- *Universal:* every _Preset kneeboard_ highlights the channel — a right-aligned
  `Pn` marker in the Name cell + an orange background on the Name & Freq cells.
  The channel keeps its ordinal position.
- *Layout-consumed:* the AJS-37 fills its FR22 **Special 1/2/3** and FR24 **H**
  from plan priorities **1/2/3/4**. The band comes from the tagged entry's
  _Radio role_ (`primary_1` → UHF, `primary_2` → VHF; a hardcoded freq is used
  verbatim), modulation **AM**. One entry per priority value across the plan
  (duplicate → first wins + `WARNING`); a missing priority leaves its special
  slot empty; priority > 4 is still highlighted but not routed.

**2 — Channel colour.** An optional `color:` (a name resolvable by Pillow
`ImageColor.getrgb`, or `#RRGGBBAA`) on a channel, in `channel_lists` **or**
`channels_collection` (the plan entry overrides the definition). It colours the
kneeboard **CH** cell background (text auto-contrasted by luminance). An unknown
name → `WARNING`, channel left uncoloured. Presentation only; never affects
packing.

**3 — AJS-37 packing (replaces the old fuse + leading-dummy + trailing-specials
entry).** A **key-based affine mapping** into DCS Group 100–139:

- `primary_1` key `K` → Group `100 + K` (K = 1…20 → DCS slots 2…21).
- `primary_2` key `K` → Group `120 + K` (K = 1…19 → DCS slots 22…40).
- `primary_2` key `20` → Group `100` (DCS slot 1) — the otherwise-unused first
  slot recycles the one channel that 101–139 (39 slots) cannot hold.
- Gaps preserved (no key 8 in `primary_1` → Group 108 empty); keys > 20 dropped
  + `WARNING`.
- Specials at **absolute DCS slots 41–47** regardless of data-list size: S1/2/3
  (41–43) from priorities 1–3, **E/F/G** (44–46) hardcoded airframe constants
  (kept at the current fixture values), **H** (47) from priority 4. Modulation
  AM for priority-sourced specials.

The `trailing_specials` layout primitive is extended to accept a `{priority: N}`
variant alongside `{freq, mod}`.

**4 — Per-type kneeboards.** One PNG **per (coalition, concrete `unit_type`)
actually injected**, written to that type's own DCS folder
`KNEEBOARD/<type>/IMAGES/presets.png` (coalition-suffixed only when the same
type is injected for both coalitions). This **replaces** the generic
`KNEEBOARD/IMAGES/` pages. Title = the concrete type (correct now that the regex
key is gone). Radio header bars are **grey** (red/green/orange dropped). The
AJS-37 kneeboard shows **pilot-facing labels** (`100`–`139`, then
`Sp1/Sp2/Sp3/E/F/G/H`) instead of raw slot indices `01`–`47`; a radio with many
channels is split across columns for legibility.

## Consequences

- Plan authors get importance highlighting and colour grouping; the AJS-37 — and
  any future shortcut airframe — is packed from the plan instead of hardcoded
  constants.
- **convert-v5 is unchanged.** v5 `radioSettings.lua` has no priority/colour
  concept, and the AJS-37 already falls back to its faithful `presets.v5.yaml`
  copy; both features are hand-authored (mission-maker + shipped default).
- ADR 0003's iso-functionality **no longer holds for the AJS-37 by design**: the
  new Group-100 recycle changes slot 1 from a dummy to `primary_2[20]`. The
  Tripack `radioSettings.lua` fixture and the AJS-37 tests are rewritten to the
  new mapping.
- Kneeboards move to per-type folders; the generic-folder pages are no longer
  emitted (missions regenerate on rebuild).

## Alternatives rejected

- **`priority` in `channels_collection`** — mixes routing intent into channel
  definitions and forces one priority per channel everywhere; kept plan-only,
  one entry per value.
- **Keep the AJS-37 specials hardcoded** — the mission-maker could not steer the
  shortcut buttons from the plan, which was the whole point.
- **Per-unit kneeboards, or keeping the generic folder** — the shared folder
  cannot disambiguate aircraft types; the per-type folder matches DCS's own
  kneeboard convention and puts each page where its pilots look.
