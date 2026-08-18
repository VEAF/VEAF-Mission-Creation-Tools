# FEAT-ARTILLERY-CONTROL — fire adjustment, the missing half of artillery

Status: ⬜ ready

Origin: [#198](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/198), plus
[#57](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/57), closed into it on 2026-08-17.

## What exists, and what does not

**Exists**: `-arty` spawns an M-109 battery (`veafShortcuts.lua:1084`), and `veafGroundAI` aims a
**named group** at a position with DCS's `FireAtPoint` (order spec at `:364-372`, task at `:568`).

**Missing**: any verb for **adjusting** fire. Grepped `veafGroundAI` for `correct` and `adjust`:
nothing. #198 describes the whole loop — fire for adjustment, a correction (`correct 09050` = 50 m
east), fire again.

## Scope

The adjustment loop, built on the order spec the module already parses. Two things the issue implies
without stating:

- a fire mission needs an **identity** (its `Sierra23`) so a correction knows what it corrects — state
  the module does not keep today
- a correction is a **bearing/distance offset** applied to the previous aim point, not a fresh
  coordinate

Mind the separator: `veafGroundAI` splits its orders on **semicolons**, not on the marker's commas.

## Definition of done

- [ ] A fire mission can be corrected by offset and fires again
- [ ] The mission is addressable by a name the player is told
- [ ] Tests on the offset arithmetic — a wrong bearing is a shell in the wrong village
- [ ] Documented on the veafGroundAI page, both languages
