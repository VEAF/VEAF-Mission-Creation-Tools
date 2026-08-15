# Lot FIX-RADIO-LAYOUT-GAPS — three gaps in the preset-plan's radio data

Status: ✅ done — 2026-08-10, all three tickets closed

**Context**: converting the Foothold `presets.yaml` to the preset-plan model
([FEAT-FOOTHOLD-PRESETS-PLAN](FEAT-FOOTHOLD-PRESETS-PLAN.md)) exercised the packer over a large, varied
fleet — 32 aircraft types on one map alone. Three data gaps surfaced.

**None is a bug in the packer's logic.** All three are VEAF-maintained *data* being incomplete, and each
degraded a mission silently. Filed together because they are the same kind of work, and because the
Foothold conversion had to work around all three at once.

| # | Ticket | Status |
|---|--------|--------|
| 01 | Never assign a comm role to an ADF | ✅ |
| 02 | AJS-37: out-of-range trailing specials | ✅ |
| 03 | Cover Flaming Cliffs in the radio specs | ✅ |

## A radio-compass treated as an FM radio

The `MiG-29 Fulcrum`'s radio 2 is an `ARK-19` — a radio-compass, ranges `0.15–1.2995 MHz`. The default
role classification saw a band below the V/UHF floor and assigned the **FM** role, so a 30-channel FM
list was projected onto an ADF. Every channel was then reported out of range and dropped, and the
kneeboard advertised an FM radio the aircraft does not have.

Measured across `dcs-radio-specs.yaml` — every "radio" whose ranges all sit below 2 MHz:

| Type | Radio | Explicit layout |
|---|---|---|
| `Ka-50` | `ARK-22` | no |
| `Ka-50_3` | `ARK-22` | no |
| `MiG-29 Fulcrum` | `ARK-19` | no |
| `Yak-52` | `ARK-15M` | no |

`FIX-DYNSLOT-RADIO-UNITS` already knew this hazard from the other end: a primary `frequency` below the
VHF floor — it names an `ARK-15M` at 0.625 MHz — makes DCS refuse to save the mission. The role
classification now applies the same reasoning.

## The other two

**The AJS-37's `E` and `F` never reached the mission.** `dcs-radio-layouts.yaml` gives its radio 1 a
`trailing_specials` list containing 33 and 34 MHz, but the specs give the AJS-37 a single radio spanning
`103.0-400.0 MHz` — so both fell outside it and were dropped.

**Flaming Cliffs aircraft had no radio specs at all**, so nothing could be projected onto them.
