# 06 — `attack` and `escort`

Status: ✅ done — read in game 2026-10-02: `attack` destroyed its tank (R31, R32), `escort` stayed within 3 km of a driving group, undamaged (R33)

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

- `attack` (armed only): flies to `dest`, engages ground units and helicopters within a radius there,
  then orbits.
- `escort` (armed only): follows the ground group named by `dest` and covers it (`GroundEscort`).
- Both refused for an unarmed helicopter, with a message.
