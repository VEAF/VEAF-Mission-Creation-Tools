# 02 — one shared base under QRA and AirWaves

Status: ✅ done — 2026-10-05
Type: refactor

Extract what both modules duplicate into `veafReactiveZone.lua`: zone geometry (trigger zone, or centre + radius), units in zone with the altitude filter, random group choice with bias, the spawn of a `[lat,lon]` command or an editor group, drawing and erasing the zone.
`VeafQRACore` and `AirWaveZone` keep their state machines, setters, messages and labels; they delegate to the base.

Done when:

- both modules spawn through the one function, and `test_wave_offset_axes.py` guards that one site
- the latent VMR-085 twin in `VeafQRACore:deploy` (`triggerZone.x` on a missing zone) is gone with the twin
- an AirWaves command wave spawns for the side **opposite** the players: today it passes a `nil` coalition, which `veaf.getCountryForCoalition` turns into red, so a red-player zone spawned red enemies
- the existing QRA and AirWaves Lua suites pass unchanged
