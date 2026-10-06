# 07 — Destroyed scenery replayed at start

Status: ⬜ ready

David, 2026-10-06: a bridge destroyed in a mission starts destroyed in the next.

- During the flight, scenery deaths are recorded in the state file: id and position.
  Measured already (`scenery-death-events-in-dcs`): `event.pos` is nil, `isExist()` is false but `getPosition()` answers, `getName()` returns the numeric id.
- At the next start, each recorded object is destroyed again before players can see it.
  How — the mission editor's scenery destruction zone written at build, or an explosion at its position at run time, or another call — is **to measure** on a bridge and on a building; the one that leaves the object destroyed without collateral wins, and the measurement goes to known limitations.
- Whether the objective tracker of the next mission (a bridge as target) sees the object as already dead is checked in the same reading.

## Done when

Tests cover recording from a death event and the replay call per recorded object; one in-game reading that a bridge destroyed in mission N is down at the start of mission N+1.
