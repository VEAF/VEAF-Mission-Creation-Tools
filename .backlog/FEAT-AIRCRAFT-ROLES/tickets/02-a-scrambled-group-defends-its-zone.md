# 02 — A scrambled group with no air engagement defends its zone

Status: ✅ done

Type: feat

`VeafQRACore:deploy` and `AirWaveZone:deployWaves` clone a DCS group with its editor route. When that
group is tasked `CAP` or `Intercept` in the editor and its route has no air engagement task
(`EngageTargets` / `EngageTargetsInZone` whose target types are aircraft), the clone gets the
`zone_defense` role instead: first waypoint at the spawn spot with the template's own options, a
race-track centred on the zone along the spawn → centre axis, and the CAP watchdog bounded by the zone.
A route that does engage air is used as the mission maker wrote it, and so is the route of any other
task — a bomber or assault wave flies its mission (David, 2026-10-02).

A group that starts on the ground keeps its take-off point as the first waypoint, untouched, and climbs
to 27 000 ft for the leg (David, 2026-10-02: ground starts included).

Ground groups are not concerned.

## Definition of done

- [x] `veafAircraftSpawn.routeEngagesAir(route)` — the rule, tested on the shapes found in real
      missions (Open Training v5 CAP, ME auto task, the `create_qra` single point)
- [x] QRA and AirWaves: what `coalition.addGroup` receives, for a group without and with engagement,
      and for a strike group — each test proven to fail with the wiring removed
