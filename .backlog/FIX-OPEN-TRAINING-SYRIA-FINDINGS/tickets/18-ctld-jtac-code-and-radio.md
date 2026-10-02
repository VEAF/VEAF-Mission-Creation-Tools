# 18 — CTLD JTAC: an imposed laser code taken twice, the ASSETS frequency ignored

Status: 🧑 waiting-human — the fix belongs in VEAF/CTLD; David decides when to run that lot

Files (VEAF/CTLD, `src/CTLD_jtac.lua`): `CTLDJTACManager:spawnJTAC`, `_initLaserPool`, `_assignLaserCode`,
`_freeLaserCode`, `CTLDJTAC:new`; then the vendored `src/scripts/community/CTLD.lua` here, verbatim.

## What happened

Found in game on the Syria Open Training v6 (dcs-serve, 2026-10-02), filed by the Syria session and
validated by David. `modules.ASSETS` declares Reaper 1 with `jtac: 1688`, `freq: 36.0` FM;
`CTLDJTACManager.jtacs` also holds the shipped catalogue's `veafSpawn-MQ9 - AFAC - JTAC - DRONE`, on 1688.

Checked in the vendored rc11 and on `VEAF/CTLD` develop (2026-10-02):

1. An imposed `cfg.laserCode` is never removed from `_laserPool`, `_assignLaserCode` hands out the highest
   code first, and `_initMMJTACs` registers every group named "jtac" at CTLD's start, before
   `veafAssets.initialize` imposes its codes: the catalogue drone takes 1688 first. `_freeLaserCode` also
   puts an imposed code back into the pool when its JTAC dies.
2. `CTLDJTAC:new` always sets `self.radio` from the laser code (`calculateFMRadio`), so the radio
   `veafSpawn.JTACAutoLase` passes is dropped, and a code above `jtacLaserCodeMax` gets none.
3. `_initLaserPool` fills 1111..1688 without leaving out the codes DCS refuses (a digit 9 or 0, e.g. 1199).

## Done when

- In VEAF/CTLD: an imposed code leaves the pool, whatever the registration order; a radio passed in is
  kept, the code-derived one only when none is given; the pool holds valid codes only. Tests: two JTACs,
  one imposed on 1688 and one automatic, get distinct codes in either order; a JTAC given a radio has it.
- A CTLD release taken here verbatim (`vendored.yaml`), and `ctld-jtac-imposed-code-and-radio` in
  `known-limitations.yaml` gets its `fixed_in`.

Until then the limitation is in `known-limitations.yaml`, with the Syria mission's workaround.
