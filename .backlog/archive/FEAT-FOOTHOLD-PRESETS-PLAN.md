# FEAT-FOOTHOLD-PRESETS-PLAN — move the Foothold `presets.yaml` to the preset-plan model

Status: ✅ done

## Context

David carries a `presets.yaml` written for an earlier v6 and copied into all ten Foothold
mission folders (`src/presets.yaml`, ~17.6 KB). Question asked: does it still hold up, and
should it be converted?

**It holds up.** Verified by building an adopted `Foothold_AF_2.4.1` with that exact file on
6.11.4: the presets are injected, 30 kneeboard pages are produced, no error. And by
construction — [ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md) states the
two authoring formats coexist "**indefinitely** […] **No deprecation**". The file uses the older
layers (`radios_collection` → `presets_collection` → `presets_assignments` +
`channels_collection`), which remain the supported manual-override path.

Note that `veaf-tools validate` says nothing about this: it does not check the `presets.yaml`
schema, so its `✓` is not evidence either way. The build's own
`presets-validation-report.md` is where the answer is.

## What the report actually says

**10 aircraft types receive channels outside their radios' bands**, silently removed from the
injected presets (DCS would store them and ignore them):

| Type | Why |
|---|---|
| AJS37, F-4E-45MC, M-2000C, MiG-21Bis, MiG-29 Fulcrum, Mirage-F1BE, Mirage-F1CE, Mirage-F1EE, Ka-50_3, UH-1H | `presets_assignments.blue.*.all: modern_blue_uhf_vhf_fm` gives every type a 30-60 MHz FM radio; these types have no radio on that band |

For the AJS37 the whole 30-channel FM list is dropped. The report even suggests the manual
workaround (`AJS37: none`), which is the shape of the problem: the current model needs one
hand-written collection, or one exclusion, per airframe quirk.

The file already carries six hand-made collections for exactly that reason — inverted A-10
(`modern_blue_vhf_uhf_fm`), CH-47 FM-first, OH-58D two FMs, Apache, Gazelle — plus three types
given up on entirely: `Mi-8MT: empty`, `Mi-24P: empty`, `MiG-15bis: empty`.

**This is the case ADR 0010 was written for.** In the preset-plan model the mission-maker
declares a handful of Channel lists per Radio role, and a VEAF-maintained per-type Radio layout
projects them onto each airframe's physical radios — channel-0 rotation, reserved slots, radio
fusion, per-channel modulation included. The A-10, Apache, Gazelle, OH-58D and Mi-24P stop being
the maker's problem, and out-of-band channels stop being produced at all.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Rewrite the Foothold presets as a preset plan | ✅ |

## Result

Written as `tools/foothold/presets.yaml` and deployed to the ten mission folders (each previous
file kept alongside as `presets.yaml.bak`). Measured on two maps with very different fleets:

| | `Foothold_AF_2.4.1` | `WWII_Normandy_5.2.2` |
|---|---|---|
| Types with out-of-band channels | **10 → 2** | **2 → 0** |
| Kneeboard plates | 30 → **32** | 2 → 2 |
| Types losing coverage | **none** | **none** |

The two extra plates are `Mi-24P` and `Mi-8MT`, which the old file gave up on (`empty`) because
their channel-0 rotation needed a bespoke collection — the packer handles it. The six hand-written
collections (inverted A-10, Apache, Gazelle, CH-47, OH-58D) are gone.

### What the conversion uncovered

Converting first **removed** presets from 7 types (F-14BU, J-11A, MiG-29A/G/S, Su-25T, Su-27): the
packer needs each type's physical radios from `dcs-radio-specs.yaml`, and that file covers 87 types
but **no Flaming Cliffs aircraft**. Those are playable and Foothold puts player slots on them, so
the file keeps a **legacy override layer** for them — the manual-override path ADR 0010 preserves
for exactly this case — with the channel lists reused through YAML anchors, so no frequency is
duplicated.

The two entries still in the report are **not** authoring mistakes; they are filed as
[FIX-RADIO-LAYOUT-GAPS](../FIX-RADIO-LAYOUT-GAPS/PRD.md): an ADF classified as an FM radio
(`MiG-29 Fulcrum`, `Ka-50`, `Ka-50_3`, `Yak-52`) and two out-of-range `trailing_specials`
hard-coded in the AJS-37 layout.

## Decision taken

**Hand-write the plan, or build a legacy→plan converter?** There is no migration tool today:
`convert-v5` generates a plan from a **v5 mission's** `radioPresets*` tables, which does not
apply here — this is a v6 file in the old format.

Recommendation: **hand-write it.** The source is small and regular (three channel lists —
UHF/VHF/FM — plus a couple of special collections), it is one file reused across the ten
missions, and the result must be read and approved by a human anyway. A converter would be more
code than the thing it converts, for a migration VEAF performs once.

David approved the hand-written route; done that way.

## Out of scope

- **Deprecating the old layers.** ADR 0010 is explicit that both formats stay. Nothing here
  removes or discourages the legacy path for other missions.
- **`ENRICH-DEFAULT-PRESETS`** (the shipped default `presets.yaml`, pending a session with
  Tripack) is a separate lot. This one is about the Foothold missions' own file — though
  whatever is learned here should inform it.

---

## 01 — Rewrite the Foothold presets as a preset plan

Status: ✅ done
Type: feat

### Why

See the PRD: the current file works, but hands ten aircraft types channels their
radios cannot receive, and needs a hand-written collection per airframe quirk. The preset-plan
model removes both problems.

### Target shape

Three `channel_lists` roles replace the six collections, following
`src/defaults/mission-folder/src/presets.yaml`:

| Role | From the current file | Notes |
|---|---|---|
| `primary_1` | `radio_uhf_30` | first V/UHF radio |
| `primary_2` | `radio_vhf_30` | second V/UHF; also the warbirds' single radio |
| `fm_supplement` | `radio_fm_30` | FM atop two V/UHF (attack aircraft) |
| `fm_substitute` | — | FM as **2nd** radio (helicopters); decide whether the FM list is reused as-is |

`channels_collection` is kept unchanged — it is the frequency source and is orthogonal to the
authoring model.

### Tasks

- [x] Write the `channel_lists` block for `blue` from the three existing radios, preserving
      channel numbers and titles (they appear on the kneeboards).
- [x] Decide `fm_substitute` (helicopter FM-as-second-radio): same list as `fm_supplement`, or
      a shorter one. The current file's CH-47 collection (`modern_blue_fm_uhf`) is the clue.
- [x] Drop the collections the packer now covers, and **check each against the report** rather
      than assuming: A-10C_2 (inverted), CH-47Fbl1, AH-64D_BLK_II, OH58D, SA342* (Gazelle).
- [x] Revisit the three `empty` assignments (`Mi-8MT`, `Mi-24P`, `MiG-15bis`): the packer knows
      the Mi-24P channel-0 rotation, so `empty` is likely no longer needed. `MiG-15bis` had its
      own fix (`FIX-MIG15-PRIMARY-FREQ`) — confirm what it needs now.
- [x] Keep `red: all: none` (Foothold's red side is AI).
- [x] Consider `priority`/`color` on the key channels (ADR 0012) — Guard, the tankers, the
      carrier — since they also drive the AJS-37 FR22 specials.
- [x] Build one mission with the new file and **diff `presets-validation-report.md` against the
      current one**: the out-of-band section must shrink to nothing, or every remaining entry
      must be explained.
- [x] Compare the generated kneeboards before/after on two or three types (a plain one, the
      Apache, the AJS-37) — the plates are what players actually read.
- [x] Roll the file out to the ten Foothold mission folders.
- [x] CHANGELOG + version bump.

### Verify

The acceptance criterion is the **report**, not the absence of errors: today's build is already
error-free while dropping 30 AJS-37 channels. Success is the out-of-band list going away, with
the kneeboards still showing the channels players expect.

### Notes

Do this on **one** mission first and get it reviewed before copying to the ten folders — the
same file is reused everywhere, so a mistake multiplies by ten.
