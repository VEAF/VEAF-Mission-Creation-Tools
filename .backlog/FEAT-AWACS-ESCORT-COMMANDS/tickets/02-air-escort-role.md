# 02 — The `air_escort` role, and `-awacs, escort`

Status: ✅ done — on the mocks; the in-game reading is ticket 04

Lot: [FEAT-AWACS-ESCORT-COMMANDS](../PRD.md)

Fighters cloned from a `veafSpawn-` template escort an airplane group and defend it.

## Done when

- The `air_escort` role puts the template's first-waypoint options, then ROE `OPEN_FIRE`, then the DCS `Escort` task (the escorted group's runtime id, 60 km, `Air`) on a single waypoint 3 km behind the charge, at its altitude.
- A charge that is gone refuses the role, and `VeafAircraftSpawn:spawn` then spawns nothing — it used to fall back to the template's own route.
- The escort is named `<escorted> escort`, `veafMove`'s convention (which cannot act on it: a spawned group has no editor record); a second escort gets a free name rather than replacing the first.
- `-awacs, escort <template>` spawns one for the new AWACS.
- Tests in `test_veafAwacsEscort.lua` (`TestAirEscort`).
