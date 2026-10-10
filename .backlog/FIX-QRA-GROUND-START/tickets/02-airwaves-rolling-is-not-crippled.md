# 02 — An air-wave aircraft rolling to the runway is not crippled

Status: ✅ done

`AirWaveZone:isEnemyGroupDead` counted an airplane or helicopter alive only `inAir()`; anything else went to `handleCrippledEnemyUnit`, which destroys the unit.

- `deployWaves` records when the wave left (`waveDeployedAt`) and the units seen airborne since (`unitsSeenAirborne`).
- A unit never seen airborne, within `veafAirWaves.TAKEOFF_TIMEOUT` (600 s), is alive; one that flew and is back on the ground, or one past the delay, is crippled as before.
- Lua tests `TestVeafAirWavesGroundStart`: the first failed before the fix.
- Doc: the fighter-group section of the AirWaves page (FR + EN).
