# Lot FEAT-PRESETS-PRIORITY-COLOR — channel priority, colour & AJS-37 packing

Status: ⬜ ready
Branch: feat/presets-priority-color → PR → develop-v6
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
