# FIX-CONVOY-FROZEN-STANDOFF — a convoy holding in front of an enemy nobody fires at stays there for ever

Status: ⬜ ready

## Found

Claude, 2026-10-10, *Kolkhida* mission 1 test copy (R47 item 4, `D:\dev\_VEAF\tmp\dcs-session-2026-10-10`, fiddle hook, probes `p12`–`p14`).
Two blue M-2 Bradleys put on the road 800 m ahead of the red assault convoy `Senaki - Poti assault` (9 vehicles).
At contact (`convoy Bison: contact with 1 enemies`) the convoy lost one vehicle, then stood still: 40 minutes of game time later, state `STATE_FIGHTING`, 7 vehicles at 0 m/s 673–853 m from the Bradleys, the leading BMPT with a line of sight to one of them (`land.isVisible` at +2 m), both Bradleys alive, and **no ammunition spent by either side between two readings ~3 game minutes apart**.

## Cause

- `ConvoyUnitHandler:fight`: Poti is more than `OBJECTIVE_PRESS_DISTANCE` away, so the assault objective is dropped, and the threat is within `ASSAULT_STANDOFF` (900 m), so the convoy is ordered to **`Hold`**, ROE open fire.
- DCS does not make the held vehicles engage — the same as the two Bradleys halted 1.9 km from a BMP on 2026-10-08 (`fight`'s comment), which fired only once sent forward.
- `ConvoyUnitHandler:watch` records every enemy the convoy's units can see as a threat, which refreshes `lastContact` on every tick: `QUIET_DELAY` never elapses, so `pressOn` and `standDown` are never reached.

## Decided (David, 2026-10-10)

When no fire has been exchanged for a while although the enemy is in sight, the convoy **closes in** on it instead of holding — moving is what made DCS's vehicles fire on 2026-10-08.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-close-in-when-nobody-fires.md) | A fighting convoy that exchanges no fire closes in | ⬜ |

## Definition of done

- Lua tests: a convoy in contact with fire exchanged keeps its orders; one with the enemy in sight and no fire for `STALEMATE_DELAY` is sent toward the nearest living threat; a convoy falling back is not.
- `veafGroundAI.md` (FR + EN) says what a convoy does when nobody fires.
- In game: the same ambush, the convoy closes in and the fight ends one way or the other.
