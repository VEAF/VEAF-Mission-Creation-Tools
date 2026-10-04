# 01 — `-awacs`

Status: ✅ done — on the mocks; the in-game reading is ticket 04

Lot: [FEAT-AWACS-ESCORT-COMMANDS](../PRD.md)

`_spawn awacs` / `-awacs` spawns an AWACS on a race-track from the marker (#188).

## Done when

- The `awacs` role of `veafAircraftSpawn` gives the first waypoint the `AWACS` task, the datalink (`EPLRS`) unless `eplrs false`, and an `Orbit` of pattern `Race-Track` flown towards the second waypoint, `dist` along `hdg`.
- The group is built from its type (`veafAircraftSpawn.spawnAirplaneGroup`), with the fuel `AWACS_TYPES` gives it; E-3A for blue, A-50 for red, `type` for another.
- `skynet` defaults to `true` in the parser, so the shared tail of `executeCommand` adds it to its side's network.
- `alt` (30 000 ft), `speed` (Mach 0.5), `freq` (251 MHz AM) have defaults; an unknown `type` spawns nothing and lists the known ones.
- Tests in `test_veafAwacsEscort.lua` (`TestAwacsSpawn`), and `test_awacs_types.py` against `dcsUnits.yaml`.
