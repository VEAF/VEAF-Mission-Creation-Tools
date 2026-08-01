# 05 — port the four VEAF modules to the v2 manager APIs

**Status:** ✅ done — ported against CTLD `develop`; the vendored rc2 predates the two discovery settings, so re-vendoring is what turns their scaffold assertion on.

Depends on 04 **and** on the CTLD-side lots `FEAT-VMCT-INTEGRATION` + `FIX-SHIP-ZONE-ANCHOR-PARITY`
shipping in a rc3. Do not start before: the beacon API does not exist yet.

## The bridges, one by one

| Site | v1 | v2 |
|---|---|---|
| [veafSpawnAircraft.lua:289](../../../src/scripts/veaf/veafSpawnAircraft.lua) | `ctld.JTACAutoLase(g, code, false, "all", nil, radio)` | `CTLDJTACManager.getInstance():autoLase(…)` — same signature |
| [veafSpawnAircraft.lua:223](../../../src/scripts/veaf/veafSpawnAircraft.lua), `:669` | `ctld.cleanupJTAC(g)` | `CTLDJTACManager.getInstance():stopAutoLase(g)` |
| [veafGrass.lua:1000](../../../src/scripts/veaf/veafGrass.lua) | `builtFOBS` + `logisticUnits` inserts | `CTLDZoneManager.getInstance():registerFOBAsLogistic(name, point, radius, coalition)` |
| [veafSpawnGround.lua:186](../../../src/scripts/veaf/veafSpawnGround.lua) | same, plus beacon + `fobBeacons` | `registerFOBAsLogistic` + the new beacon API |
| [veafSpawnEffects.lua:32](../../../src/scripts/veaf/veafSpawnEffects.lua) | `logisticUnits` insert | `registerFOBAsLogistic` |
| [veafGrass.lua:1302](../../../src/scripts/veaf/veafGrass.lua) | `spawnRadioBeaconUnit` + `createRadioBeacon` | `CTLDBeaconManager.getInstance():createAtPoint(point, coalition, country, opts)` |

Use the **v2 APIs, never `legacy_api.lua`** (PRD decision 8): each wrapper logs a `DEPRECATED` line
on every call, and `JTACAutoLase` is called on every JTAC spawn.

Three v1 state tables have no equivalent and must go, not be re-created VEAF-side:

- `ctld.builtFOBS` — `CTLDFOBManager` owns FOB state (`getFOBsForCoalition`, `listFOBs`).
- `ctld.fobBeacons` / `ctld.beaconCount` — the beacon returned by `createAtPoint` carries its own
  `vhf` / `uhf` / `fm`; read them from it where VMCT displays frequencies, and let the manager own
  the numbering. **Check every VEAF read of `fobBeacons`** before deleting it — the FOB beacon
  frequencies are shown to pilots somewhere.

Pair each `registerFOBAsLogistic` with `unregisterLogistic` where VEAF destroys the FOB. v1 leaked
these entries; v2 gives us the means not to, and a stale logistic zone on a destroyed FOB is a
gameplay bug.

## Acceptance

- A FARP built in game is a working logistic point, carries its beacon, and its frequencies are
  displayed as before.
- Destroying it removes the logistic zone.
- A spawned JTAC lases and stops lasing.
- No `DEPRECATED` line from CTLD in the log of a normal mission.

## Tests

- Lua per bridge, against an updated v2 CTLD mock.
- Live DCS check (this is spawn-and-beacon behaviour; the unit tests cannot see it) — hand the list
  of four scenarios to David rather than driving his session.
