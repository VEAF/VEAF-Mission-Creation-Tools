# Lot FEAT-PRESETS-PRIORITY-COLOR — channel priority, colour & AJS-37 packing

Status: ✅ done
Branch: feat/presets-priority-color → PR [#569](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/569) → develop (merged, squash `4fcfadef`)
ADR: [0012](../../docs/adr/0012-channel-priority-colour-and-ajs37-packing.md) (extends 0010, breaks 0003 for the AJS-37)

## Problem Statement

The preset plan ([ADR 0010](../../docs/adr/0010-per-type-radio-preset-projection.md))
cannot express the AJS-37 Viggen's real radio shape without hardcoded per-type
constants the mission-maker cannot drive: FR22 data channels **Group 100–139** +
shortcut **Special 1/2/3**, FR24 backup **E/F/G/H**, with the pilot convention
**"channel N = Group 10N"**. Separately, the packer path produces **no kneeboard**
(only legacy `presets_collection` presets do), those land in a shared
`KNEEBOARD/IMAGES/` folder with red/green/orange headers and a title that can carry
the layout regex, and nothing lets the maker flag a channel as important or group
channels visually.

## Solution

Two reusable author attributes on channels — **`priority`** (universal kneeboard
highlight; consumed by the AJS-37 layout to fill its shortcut buttons) and
**`color`** (kneeboard grouping) — plus a rewritten **AJS-37 packer** (key-based
Group-100–139 mapping with the Group-100 recycle, specials at absolute slots
41–47) and a **per-type kneeboard** generator (`KNEEBOARD/<type>/IMAGES/`, grey
headers, pilot-facing Viggen labels). Full design in ADR 0012.

## User Stories

1. As a mission-maker, I tag a channel `priority: 1` so it is highlighted on every
   kneeboard, and on the AJS-37 it lands on FR22 Special 1.
2. As a mission-maker, I tag channels with `color:` to group them visually on the
   kneeboard CH column.
3. As an AJS-37 pilot, I read a kneeboard that matches the cockpit ("channel 4 =
   Group 104", Special/E/F/G/H labelled), one per aircraft type.

## Implementation Decisions (ADR 0012)

- `priority` plan-only, one entry per value; band from role (primary_1→UHF,
  primary_2→VHF), AM; missing → empty special, duplicate → first + WARNING,
  >4 → highlighted only.
- `color` in `channel_lists` (overrides) or `channels_collection`; Pillow
  `ImageColor.getrgb`; unknown → WARNING + uncoloured; auto-contrast text.
- AJS-37: `primary_1` key K → Group 100+K, `primary_2` key K → 120+K, key 20 →
  Group 100; gaps preserved, keys >20 dropped + WARNING; specials 41–47 (S1/2/3 =
  priority 1–3, E/F/G hardcoded current values, H = priority 4); `trailing_specials`
  gains a `{priority: N}` variant.
- Per-type kneeboard keyed on `(coalition, concrete unit_type)` injected;
  `KNEEBOARD/<type>/IMAGES/presets.png` (coalition-suffixed on collision);
  replaces generic folder; title = concrete type; grey radio headers; AJS-37 shows
  pilot labels; long radios split across columns.

## Out of Scope

- **convert-v5** (no v5 source for priority/colour; AJS-37 keeps its faithful
  `presets.v5.yaml` fallback).
- Broadening default preset coverage — that is lot `ENRICH-DEFAULT-PRESETS`,
  sequenced **after** this lot so it can use `priority`/`color`.

## Testing Decisions

- Unit tests per ticket (TDD). AJS-37 fixture (`radioSettings.lua`) + tests
  (`test_radio_preset_ajs37.py`, `test_presets_fidelity.py`) rewritten to the new
  mapping. Bump `--cov-fail-under` per the ratchet.

## Further Notes

Lockstep: ADR 0012 (done), dev page `radio-preset-projection` (FR/EN),
`PIPELINE_REFERENCE` (FR/EN), CONTEXT.md glossary (done). `presets_manager.py` is
not in the mypy `ignore_errors` list — keep it type-clean.

---

## 01 — Channel data model: `priority` + `color`

Status: ✅ done

### Scope

Add `priority: int | None` and `color: str | None` to `Channel` (and carry them
through `add_channel_from_dict` / `parse_channel_lists`). `priority` parsed only
from `channel_lists` entries; `color` parsed from both `channel_lists` entries
(override) and `channels_collection` channel definitions (fallback).

### Acceptance

- A plan entry `{priority: 2, color: green}` yields a `Channel` with
  `priority == 2`, `color == "green"`.
- `color` on a `channels_collection` definition propagates to every plan entry
  referencing it, unless the entry sets its own `color` (override wins).
- `priority` on a `channels_collection` definition is ignored (plan-only).
- Both default to `None` when absent; existing plans keep working unchanged.

### Tests

- `test_channel_lists.py`: priority/color parsing, override precedence, plan-only
  priority.

---

## 02 — AJS-37 key-based packer + `{priority}` specials

Status: ✅ done
Depends on: 01

> Note: `test_presets_fidelity.py` / the Tripack fixture test the **convert-v5
> faithful copy** (out of scope, Q9a) — left untouched. The ADR 0003 break
> applies only to the **packer** path (`test_radio_preset_ajs37.py`,
> `test_radio_preset_full_layout_fidelity.py`), rewritten here.

### Scope

Rewrite the AJS-37 handling in the packer + `dcs-radio-layouts.yaml`:

- Key-based affine mapping into DCS Group 100–139: `primary_1` key K → Group
  100+K; `primary_2` key K → Group 120+K; `primary_2` key 20 → Group 100.
- Gaps preserved (sparse `channels` dict); keys > 20 dropped + `WARNING`.
- Specials at absolute DCS slots 41–47: S1/2/3 = priorities 1–3, E/F/G = hardcoded
  current fixture values (`33`/FM, `34`/FM, `127.5`/AM), H = priority 4.
- Extend `trailing_specials` to accept `{priority: N}` alongside `{freq, mod}`.
  Priority resolution: scan the coalition plan, band from role (primary_1→UHF,
  primary_2→VHF), AM modulation; hardcoded freq used verbatim; missing → empty
  slot; duplicate value → first + `WARNING`.
- Retire the old `fuse` + `leading_dummy` AJS-37 entry.

### Acceptance

- AJS-37 with `primary_1` keys 1–20 + `primary_2` keys 1–20: slot 1 = p2[20],
  slots 2–21 = p1[1..20], slots 22–40 = p2[1..19], slots 41–47 as above.
- Gappy plan (shipped-default sizes) leaves the right Groups empty and still lands
  specials at 41–47.
- Priorities 1–4 present → S1/2/3 + H filled from them (AM); absent → empty.

### Tests

- Rewrite `test_radio_preset_ajs37.py` to the new mapping.
- Rewrite the AJS-37 half of `test_presets_fidelity.py` and the `radioSettings.lua`
  fixture expectations (ADR 0003 iso-functionality intentionally dropped here).

---

## 03 — Kneeboard: priority highlight, colour, grey headers

Status: ✅ done
Depends on: 01

### Scope

Render the new channel attributes and drop the coloured radio headers:

- **priority**: right-aligned `Pn` marker in the Name cell + orange background on
  the Name & Freq cells.
- **color**: fill the CH cell background with the resolved colour
  (`ImageColor.getrgb`, unknown → `WARNING` + uncoloured); channel-number text
  auto-contrasted (white/black) by background luminance.
- **grey headers**: replace the red/green/orange `radio_colors` radio title bars
  with grey (matching the existing column-header row).

### Acceptance

- A `priority: 3` channel shows `P3` + orange Name/Freq cells.
- A `color: "#000080"` channel shows a navy CH cell with white number text.
- A `color: green` channel shows a green CH cell.
- All radio title bars render grey; no red/green/orange remains.

### Tests

- `test_presets_image*`: presence of `Pn`, orange cells, CH-cell colour,
  contrast branch, grey header colour.

---

## 04 — Per-type kneeboards + Viggen pilot labels

Status: ✅ done
Depends on: 02, 03

### Scope

Replace the collection-driven generic-folder generation with per-type pages:

- Collect the presets actually injected, keyed `(coalition, concrete unit_type)`
  during `process_groups` (works for packer, legacy assignments, `all`/regex;
  `none` skipped).
- Emit one PNG per entry to `KNEEBOARD/<type>/IMAGES/presets.png`; suffix
  `-<coalition>` only when the same type is injected for both coalitions.
- Stop emitting the generic `KNEEBOARD/IMAGES/presets-<name>.png` pages.
- Title = concrete type (+ coalition). Sanitise types containing `/` for the path.
- **Viggen labels**: the AJS-37 CH column shows pilot-facing labels — `100`–`139`
  for the 40 data slots, `Sp1/Sp2/Sp3/E/F/G/H` for slots 41–47 — driven by the
  layout, instead of raw slot indices. Other types keep index = number.
- A radio with many channels (Viggen's 47) is split across columns for legibility.

### Acceptance

- A mission with a blue AJS37 and a blue A-10C produces
  `KNEEBOARD/AJS37/IMAGES/presets.png` and `KNEEBOARD/A-10C/IMAGES/presets.png`,
  and no `KNEEBOARD/IMAGES/presets-*.png`.
- Blue + red of the same type → `presets-blue.png` / `presets-red.png` in that
  type's folder.
- The AJS37 page shows `104` (not `05`) and `Sp1`/`H`, wrapped across columns.

### Tests

- `test_presets_injector_worker*`: per-type file paths, coalition suffixing,
  generic-folder removal, Viggen label mapping.

---

## 05 — Docs + shipped-default lockstep

Status: ✅ done
Depends on: 01, 02, 03, 04

### Scope

- ADR 0012 — done (this lot's design record).
- CONTEXT.md glossary (`Channel priority`, `Channel colour`, updated `Preset
  kneeboard`) — done during grilling.
- Dev page `doc/developer/radio-preset-projection.md` (+ `.en.md`): document
  `priority` (universal + Viggen routing), `color`, the AJS-37 key mapping +
  Group-100 recycle, the `{priority}` special variant, per-type kneeboards + grey
  headers + Viggen labels. Update the AJS-37 row of the quirk table.
- `doc/PIPELINE_REFERENCE.md` (+ `.en.md`): mission-maker view of `priority` /
  `color` in `presets.yaml`.
- `dcs-radio-layouts.yaml` header comments: document the extended
  `trailing_specials` `{priority}` variant and the AJS-37's key mapping.
- Shipped-default `src/defaults/mission-folder/src/presets.yaml`: no functional
  change required (no AJS37 in the default missions), but add a commented
  `priority` / `color` example if it aids discoverability.

### Acceptance

- Docs describe the new attributes and the AJS-37 behaviour accurately; deep links
  resolve; FR/EN parity.
