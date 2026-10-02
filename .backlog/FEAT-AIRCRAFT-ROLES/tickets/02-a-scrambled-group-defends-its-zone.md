# 02 — A scrambled group with no air engagement defends its zone

Status: ⬜ ready

Type: feat

`VeafQRACore:deploy` and `AirWaveZone:deployWaves` clone a DCS group with its editor route. When that
route has no air engagement task (`EngageTargets` / `EngageTargetsInZone` whose target types are
aircraft), the clone gets the `zone_defense` role instead: first waypoint at the spawn spot with the
template's own options, a race-track centred on the zone along the spawn → centre axis, and the CAP
watchdog bounded by the zone. A route that does engage air is used as the mission maker wrote it.

Ground groups are not concerned.

## Definition of done

- [ ] `veafAircraftSpawn.routeEngagesAir(route)` — the rule, tested on the shapes found in real
      missions (Open Training v5 CAP, ME auto task, the `create_qra` single point)
- [ ] QRA and AirWaves: what `coalition.addGroup` receives, for a group without and with engagement
