# 01 — A fighting convoy that exchanges no fire closes in

Status: ⬜ ready

- Record the last fire exchanged by the convoy: a shot or hit taken (`reportFire`, already there) **and** a shot fired by its own units (`S_EVENT_SHOOTING_START` / `S_EVENT_SHOT` with a convoy unit as initiator).
- In `watch`, a convoy in `STATE_FIGHTING` whose enemy is still in sight and that has exchanged no fire for `STALEMATE_DELAY` (proposed 120 s, a constant to tune in game) drives toward the nearest living threat (`Off Road`, `ASSAULT_SPEED`), as `pressOn` does for an enemy out of sight; the clock restarts after each push.
- `STATE_FALLING_BACK` is left alone: a convoy that fled does not walk back into the ambush.
- Lua tests as in the PRD; the stalemate measured in the PRD as the regression case.
