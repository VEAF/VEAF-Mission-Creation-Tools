# 05 — `patrol`

Status: ✅ done — read in game 2026-10-02 (R29–R31): the armed loop holds and engages a ground unit in its zone; the shuttle lands 16 m from `dest`, waits, and lands back home

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

- Armed: a circuit around the marker, or along its `dest` points, engaging ground units and
  helicopters within a radius (`EngageTargetsInZone`, default 3 km).
- Unarmed: a shuttle marker ↔ `dest`, landing a few minutes at each end (default 5), for ever.
