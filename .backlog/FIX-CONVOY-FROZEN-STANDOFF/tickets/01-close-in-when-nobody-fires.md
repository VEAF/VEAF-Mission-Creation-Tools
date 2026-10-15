# 01 — A fighting convoy that exchanges no fire closes in

Status: ✅ done — Measured in game on 2026-10-15 (R48, *Kolkhida* mission 1 test copy built from `develop`): two blue M-2 Bradleys on the red assault convoy's road 800 m ahead of it, 6 km from any other red unit; at contact both sides fired at once (red ammunition 23 511 → 20 387, one red vehicle and both Bradleys lost), no `closing in` was logged, and the convoy drove on 60 s after the fight. The push itself was not exercised in game, since fire was exchanged at once.

- Record the last fire exchanged by the convoy: a shot or hit taken (`reportFire`, already there) **and** a shot fired by its own units (`S_EVENT_SHOOTING_START` / `S_EVENT_SHOT` with a convoy unit as initiator).
- In `watch`, a convoy in `STATE_FIGHTING` whose enemy is still in sight and that has exchanged no fire for `STALEMATE_DELAY` (proposed 120 s, a constant to tune in game) drives toward the nearest living threat (`Off Road`, `ASSAULT_SPEED`), as `pressOn` does for an enemy out of sight; the clock restarts after each push.
- `STATE_FALLING_BACK` is left alone: a convoy that fled does not walk back into the ambush.
- Lua tests as in the PRD; the stalemate measured in the PRD as the regression case.

## Done

- `ConvoyUnitHandler.lastFireExchanged`: set when the contact starts (`engage`), on every shot or hit taken (`reportFire`), on every shot fired by one of the convoy's units (`reportOwnFire`, from `S_EVENT_SHOOTING_START` or `S_EVENT_SHOT` with a convoy unit as initiator, whatever it is aimed at), and after each push.
- `ConvoyUnitHandler:closeIn`, called by `watch` for a convoy in `STATE_FIGHTING` with an enemy in sight, nothing exchanged for `STALEMATE_DELAY`, and **every vehicle below `HALTED_SPEED` (1 m/s)**: off road at `ASSAULT_SPEED` onto the nearest enemy in sight, **with no standoff** — stopping 900 m short again is what froze it. Alarm state and ROE were already set by `fight`.
- The push applies to an assault convoy too: one near its objective is already driving into it, and one that arrived there, or is held because the objective is beyond `OBJECTIVE_PRESS_DISTANCE` (the Kolkhida case), has the same stalemate.

## Only a halted convoy is pushed

Found at the review of the local diff: a contact made at 2.5-3 km sends the convoy to 900 m of the enemy, a drive of 200 s or more at `ASSAULT_SPEED`, and DCS's vehicles open fire only on the way (~1.3 km on 2026-10-08). Without the condition, the push came 120 s into that approach and replaced the 900 m stop, which worked on 2026-10-08, by a drive onto the enemy. The clock is not restarted while the convoy drives: halted at the standoff with no shot all the way, it is pushed at the next beat.

## `STALEMATE_DELAY` = 120 s, and why

The ticket proposed 120 s; kept. It is twice `QUIET_DELAY`, so a pause between two bursts of a fight that is going on is not taken for a stalemate, and short enough that a frozen convoy moves within a player's attention span. A constant like every other delay of the convoy watch: the module exposes none of them in `mission.yaml`, and this one is to be tuned from R48, not by mission makers.

## Tests

`test/lua/test_veafGroundAI_convoy.lua`, through the scheduler and the event handler (the wiring, not only the handler): held at 800 m, the push comes after the delay and not before, and not while the convoy still drives to its standoff, onto the enemy, and the next one a whole delay later; the Kolkhida assault convoy far from Poti; own gun fire, own missile launch, and hits taken each keep the orders; a convoy falling back is not pushed. Each guard was mutated out once and its test failed.
