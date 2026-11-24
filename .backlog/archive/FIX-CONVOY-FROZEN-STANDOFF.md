# FIX-CONVOY-FROZEN-STANDOFF — a convoy holding in front of an enemy nobody fires at stays there for ever

Status: ✅ done — Measured in game on 2026-10-15 (R48, *Kolkhida* mission 1 test copy built from `develop`): two blue M-2 Bradleys on the red assault convoy's road 800 m ahead of it, 6 km from any other red unit; at contact both sides fired at once (red ammunition 23 511 → 20 387, one red vehicle and both Bradleys lost), no `closing in` was logged, and the convoy drove on 60 s after the fight. The push itself was not exercised in game, since fire was exchanged at once. · archived 2026-11-24

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
| [01](FIX-CONVOY-FROZEN-STANDOFF.md) | A fighting convoy that exchanges no fire closes in | ✅ |

## Definition of done

- Lua tests: a convoy in contact with fire exchanged keeps its orders; one with the enemy in sight and no fire for `STALEMATE_DELAY` is sent toward the nearest living threat; a convoy falling back is not.
- `veafGroundAI.md` (FR + EN) says what a convoy does when nobody fires.
- In game: the same ambush, the convoy closes in and the fight ends one way or the other.

## Tickets, in full

## 01 — A fighting convoy that exchanges no fire closes in

Status: ✅ done — Measured in game on 2026-10-15 (R48, *Kolkhida* mission 1 test copy built from `develop`): two blue M-2 Bradleys on the red assault convoy's road 800 m ahead of it, 6 km from any other red unit; at contact both sides fired at once (red ammunition 23 511 → 20 387, one red vehicle and both Bradleys lost), no `closing in` was logged, and the convoy drove on 60 s after the fight. The push itself was not exercised in game, since fire was exchanged at once.

- Record the last fire exchanged by the convoy: a shot or hit taken (`reportFire`, already there) **and** a shot fired by its own units (`S_EVENT_SHOOTING_START` / `S_EVENT_SHOT` with a convoy unit as initiator).
- In `watch`, a convoy in `STATE_FIGHTING` whose enemy is still in sight and that has exchanged no fire for `STALEMATE_DELAY` (proposed 120 s, a constant to tune in game) drives toward the nearest living threat (`Off Road`, `ASSAULT_SPEED`), as `pressOn` does for an enemy out of sight; the clock restarts after each push.
- `STATE_FALLING_BACK` is left alone: a convoy that fled does not walk back into the ambush.
- Lua tests as in the PRD; the stalemate measured in the PRD as the regression case.

### Done

- `ConvoyUnitHandler.lastFireExchanged`: set when the contact starts (`engage`), on every shot or hit taken (`reportFire`), on every shot fired by one of the convoy's units (`reportOwnFire`, from `S_EVENT_SHOOTING_START` or `S_EVENT_SHOT` with a convoy unit as initiator, whatever it is aimed at), and after each push.
- `ConvoyUnitHandler:closeIn`, called by `watch` for a convoy in `STATE_FIGHTING` with an enemy in sight, nothing exchanged for `STALEMATE_DELAY`, and **every vehicle below `HALTED_SPEED` (1 m/s)**: off road at `ASSAULT_SPEED` onto the nearest enemy in sight, **with no standoff** — stopping 900 m short again is what froze it. Alarm state and ROE were already set by `fight`.
- The push applies to an assault convoy too: one near its objective is already driving into it, and one that arrived there, or is held because the objective is beyond `OBJECTIVE_PRESS_DISTANCE` (the Kolkhida case), has the same stalemate.

### Only a halted convoy is pushed

Found at the review of the local diff: a contact made at 2.5-3 km sends the convoy to 900 m of the enemy, a drive of 200 s or more at `ASSAULT_SPEED`, and DCS's vehicles open fire only on the way (~1.3 km on 2026-10-08). Without the condition, the push came 120 s into that approach and replaced the 900 m stop, which worked on 2026-10-08, by a drive onto the enemy. The clock is not restarted while the convoy drives: halted at the standoff with no shot all the way, it is pushed at the next beat.

### `STALEMATE_DELAY` = 120 s, and why

The ticket proposed 120 s; kept. It is twice `QUIET_DELAY`, so a pause between two bursts of a fight that is going on is not taken for a stalemate, and short enough that a frozen convoy moves within a player's attention span. A constant like every other delay of the convoy watch: the module exposes none of them in `mission.yaml`, and this one is to be tuned from R48, not by mission makers.

### Tests

`test/lua/test_veafGroundAI_convoy.lua`, through the scheduler and the event handler (the wiring, not only the handler): held at 800 m, the push comes after the delay and not before, and not while the convoy still drives to its standoff, onto the enemy, and the next one a whole delay later; the Kolkhida assault convoy far from Poti; own gun fire, own missile launch, and hits taken each keep the orders; a convoy falling back is not pushed. Each guard was mutated out once and its test failed.
