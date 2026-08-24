# 02 — One predicate for "is this a FARP platform", instead of four copies

Status: ✅ done
Type: fix

The second defect the PRD named — *"the type list at `:1082` enumerates four strings, so any FARP type
outside it silently falls back to 75 m"* — and it is not hypothetical.

## The list exists four times, and it has already diverged

| Where | Types listed |
|---|---|
| [`veafGrass.lua:204`](../../../src/scripts/veaf/veafGrass.lua:204) — recognising FARP units | `SINGLE_HELIPAD`, `FARP_SINGLE_01`, `FARP`, `Invisible FARP`, **`FARP_T`** |
| [`veafGrass.lua:241`](../../../src/scripts/veaf/veafGrass.lua:241) — recognising FARP airbases | the same **four**, without `FARP_T` |
| [`veafGrass.lua:1082`](../../../src/scripts/veaf/veafGrass.lua:1082) — tent / escort / prop distances | the same **four** |
| [`veafGrass.lua:1200`](../../../src/scripts/veaf/veafGrass.lua:1200) — windsock distance and angle | the same **four** |

Commit `a454c577` (2025-08-08, *"adds FARP_T to the list of recognized FARP unit types"*) added the
fifth type to **one** list.

## What that produces today, measured by reading

A `FARP_T` is recognised as a FARP unit (204) and `buildFarpUnits` runs for it — then falls through every
type test inside, so it is laid out as if it were not a FARP at all:

| | a FARP platform | a `FARP_T` today |
|---|---|---|
| escort distance | 150 m | **75 m** |
| tent distance | 200 m | **100 m** |
| other props | 130 m | **85 m** |
| windsock | 120 m, 0° | **50 m, 45°** |

So the escort is placed at half the intended distance, on top of the pads. Same defect as ticket 01,
reached by a different route — which is why both belong to this lot.

## What ships

- **`veafGrass.isFarpPlatformType(typeName)`** — the list, once. Used at all four sites.
- `FARP_T` is in it, since it was already recognised as a FARP everywhere except where it mattered.
- **It stops being mute.** A type that is *not* in the list but whose name contains `FARP` or `HELIPAD`
  logs a warning naming the type and saying the default distances are being used. That is the shape
  `FIX-COMBATZONE-ZONE-TYPE-SILENT` is about: a missing `else` that guesses instead of reporting. A
  guess and a warning is not the same as a guess.

Not a refactor for tidiness: the four copies **are** the defect, and leaving three of them would leave
the next type to diverge again.

## Behaviour change to announce

A `FARP_T` in an existing mission moves: its escort goes from 75 m to 150 m, and its windsock from
50 m/45° to 120 m/0°. That is the fix, not a side effect — but it is visible, so the changelog says so.

## Definition of done

- [x] One predicate, used at all four sites
- [x] `FARP_T` gets FARP distances
- [x] An unrecognised FARP-looking type warns instead of silently using the default distances
- [x] Lua tests for the predicate, for `FARP_T`, and for the warning path
