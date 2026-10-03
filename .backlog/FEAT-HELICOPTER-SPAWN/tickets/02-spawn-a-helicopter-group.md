# 02 — Spawn a helicopter landed

Status: ✅ done

Lot: [FEAT-HELICOPTER-SPAWN](../PRD.md)

`_spawn unit, name <helicopter>` and `_spawn group, name <group of helicopters>` put the helicopter on the
ground at the marker, engine off, and it stays there (R23, variant E).

## What changes

- `veafUnits` marks a helicopter unit (`helicopter = true`, from the DCS category) and a group made of
  them; a helicopter is never placed on water.
- `spawnUnit` stops refusing helicopters (airplanes stay refused). Neither path applies the marker's
  `alt` to the spawn point of a helicopter: on a helicopter it is the job's altitude.
- Both paths hand the group to `veafAircraftSpawn.spawnHelicopterGroup`, which submits it under
  `HELICOPTER` with the route of its role. With no `task`, the role is `parked`: one `TakeOffGround`
  point and `uncontrolled = true`.
- A `dest` does not turn a helicopter group into a convoy.

## Done when

- Tests fail on the old code: the category submitted, the refusal, the `uncontrolled` flag, the point
  type, the altitude left alone.
