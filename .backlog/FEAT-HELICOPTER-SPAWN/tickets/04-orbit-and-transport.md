# 04 — `orbit` and `transport`

Status: ✅ done — read in game 2026-10-02 (R24–R28): orbit holds 1.5–2 km out; transport lands 30 m from an open-ground point, hovers at a forest edge

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

A `task` keyword on the marker names the job; unknown words are refused with a message.

- `orbit`: takes off from the marker (`TakeOffGroundHot`, airborne in 11 s per R23) and circles it
  (`Orbit`, `Circle`) at `alt` above the ground (default 150 m) and `speed` (default 40 m/s). Armed:
  weapons free; unarmed: weapons hold.
- `transport`: takes off, flies to `dest` at that altitude and lands there (`Land`). Returns fire only.
  Refused without a `dest`.

## Done when

- Tests on the route each role builds, the options it sets, and the refusals.
- **Checkpoint**: David's in-game reading before 05.
