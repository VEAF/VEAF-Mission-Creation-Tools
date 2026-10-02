# 06 — `attack` and `escort`

Status: 🧑 waiting-human — `attack` read in game ✅ (R31); `escort` wanders up to 7 km from a stationary group, R32 reads it on a moving convoy

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

- `attack` (armed only): flies to `dest`, engages ground units and helicopters within a radius there,
  then orbits.
- `escort` (armed only): follows the ground group named by `dest` and covers it (`GroundEscort`).
- Both refused for an unarmed helicopter, with a message.
