# FIX-RADIO-LAYOUT-GAPS — three gaps in the preset-plan's radio data

Status: ✅ done — 2026-08-10, all three tickets closed

## Context

Converting the Foothold `presets.yaml` to the preset-plan model
([FEAT-FOOTHOLD-PRESETS-PLAN](../archive/FEAT-FOOTHOLD-PRESETS-PLAN.md)) exercised the packer over a
large, varied fleet — 32 aircraft types on one map alone. Three data gaps surfaced. None is a bug
in the packer's logic; all three are **VEAF-maintained data** being incomplete, and each degrades
a mission silently.

They are filed together because they are the same kind of work, and because the Foothold
conversion had to work around all three at once.

## The three gaps

### 1. A radio-compass (ADF) is treated as an FM radio

`MiG-29 Fulcrum`'s radio 2 is an `ARK-19` — a radio-compass, ranges `0.15–1.2995 MHz`. The
default role classification sees a band below the V/UHF floor and assigns the FM role, so a
30-channel FM list is projected onto an ADF. Every channel is then reported out of range and
dropped, and the kneeboard advertises an FM radio the aircraft does not have.

Measured over `dcs-radio-specs.yaml` — every "radio" whose ranges all sit below 2 MHz:

| Type | Radio | Has explicit layout |
|---|---|---|
| `Ka-50` | `ARK-22` | no |
| `Ka-50_3` | `ARK-22` | no |
| `MiG-29 Fulcrum` | `ARK-19` | no |
| `Yak-52` | `ARK-15M` | no |

`FIX-DYNSLOT-RADIO-UNITS` already knows this hazard from the other end: a primary `frequency`
below the VHF floor (it names an `ARK-15M` at 0.625 MHz) makes DCS refuse to save the mission.
The role classification should apply the same reasoning.

### 2. Two of the AJS-37's specials never reach the mission

`dcs-radio-layouts.yaml` gives `AJS37` radio 1 a `trailing_specials` list containing
`{freq: 33, mod: 1, label: E}` and `{freq: 34, mod: 1, label: F}`. The specs give the AJS-37 a
single radio spanning `103.0-400.0 MHz`, so `_drop_out_of_range_channels` strips both before the
mission is written -- reported as channels 44/45 on every build.

**Not a design question.** ADR 0012 decided those seven specials and the packer honours the
decision; a layer below silently undoes part of it. What is open is narrower, and dated: the drop
arrived 2026-06-13 (#468) and the AJS-37 layout a month later (#569), so the two were never put
side by side. #468's own message says the guard exists **so the Mission Editor can save** -- while
veaf-tools writes the `.miz` directly and never takes that path. A mission with 33 MHz on an AJS-37
therefore flies, which is what Tripack tested, and would be refused only if someone re-saved it in
the editor. One experiment decides whether that trade is right here; see the ticket.

### 3. No Flaming Cliffs aircraft in the specs

`dcs-radio-specs.yaml` covers **87 types and no FC3 aircraft**: `Su-27`, `Su-25T`, `Su-25`,
`Su-33`, `MiG-29A`, `MiG-29S`, `MiG-29G`, `J-11A`, `A-10A`, `F-15C` are all absent — and so is
`F-14BU`. The packer needs physical radios to project onto, so **every FC3 type silently gets no
presets** under the preset-plan model.

These are playable aircraft and VEAF missions put player slots on them, so the gap is not
theoretical: the Foothold conversion kept a legacy override layer purely to cover them (7 types
lost their kneeboard plates before that layer was added).

The specs are generated from the pinned `dcs-lua-datamine`
(`veaf_build/radio_specs_updater.py`), so the question is whether the datamine exposes FC3 radios
at all, or whether the generator filters them out.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Never assign a comm role to an ADF](tickets/01-adf-not-a-comm-radio.md) | ✅ |
| 02 | [AJS-37: out-of-range trailing specials](tickets/02-ajs37-out-of-range-specials.md) | ✅ |
| 03 | [Cover Flaming Cliffs in the radio specs](tickets/03-fc3-radio-specs.md) | ✅ |

## Why it matters beyond Foothold

Any mission adopting the preset-plan model hits these. Gap 3 especially: the model cannot be
recommended without reservation to a mission carrying FC3 slots — which is most VEAF training
missions.
