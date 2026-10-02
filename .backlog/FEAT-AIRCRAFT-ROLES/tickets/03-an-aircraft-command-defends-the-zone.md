# 03 — An aircraft command run by a QRA or a wave defends that zone

Status: ✅ done

Type: feat

A QRA or wave entry such as `-cap mig29` spawns a CAP that patrols around the zone centre with its
own 60 NM zone. After the command, every group it spawned that carries a fighter role is re-assigned
`zone_defense` on the QRA / wave zone — through the watchdog registry, so it keeps one watchdog.

## Definition of done

- [x] Test: a QRA command spawning a CAP ends with the zone_defense route and the QRA zone in the
      registry, and one watchdog scheduled
- [x] Same wiring for an air wave, both tests proven to fail with it removed
