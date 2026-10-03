# 01 — a `-cap` or `-afac` draws from its own side

Status: 🧑 waiting-human — merged in #1052, in-game check R32

`veafSpawn.initializeAirUnitTemplates` records each template's side;
`veafSpawn.findSpawnableAircraftGroupname(name, side)` draws from that side's matches and the neutral
ones, falling back to every match (with a `dcs.log` warning) when none of those matches;
`spawnCombatAirPatrol` and `spawnAFAC` pass their side.

## Acceptance

- `test/lua/test_veafSpawn.lua`: the side is recorded at load; with one template per side, each side
  gets its own whichever candidate the draw picks; a neutral template serves both sides without
  letting the other side's back in; a side with no template falls back; a call with no side still
  sees every template; `-cap` and `-afac` pass their side.
- Without the fix, the side-recording, own-side, neutral and caller tests fail.
