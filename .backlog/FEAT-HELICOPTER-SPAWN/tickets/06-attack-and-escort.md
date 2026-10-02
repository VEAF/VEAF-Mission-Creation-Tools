# 06 — `attack` and `escort`

Status: ⬜ ready — after the checkpoint of ticket 04

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

- `attack` (armed only): flies to `dest`, engages ground units and helicopters within a radius there,
  then orbits.
- `escort` (armed only): follows the ground group named by `dest` and covers it (`GroundEscort`).
- Both refused for an unarmed helicopter, with a message.
