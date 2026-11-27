# 03 — Sweep GermanyCW clear ground again

Status: ✅ done
Type: chore
Files: `src/python/veaf-tools/veaf_libs/data/clear-ground/GermanyCW.clear-ground.json`

The shipped catalogue is 6 km round the 25 combat zones of the Open Training GermanyCW mission, swept 2026-10-22 (316 758 bytes, 25 layers). Sweep again on 2.9.32 with `clear-ground-sweep GermanyCW --zones-from <OT GermanyCW .miz> --no-airfields`; compare entries and bytes before and after.

Swept 2026-11-26 on DCS 2.9.32.30490 from `VEAF_OpenTraining_GermanyCW_ICAO_ETAR_20261123.miz` with `--no-airfields --restart` (the sweep state kept in `~/.veaf/clear-ground/sweep-GermanyCW` dated from 2026-09-28, before 2.9.32, and had to be thrown away), 1 510 106 cells probed. Layers 25 → 26 (`combatZone_Hunsrueck_SAR` added to the mission since), 15 of the 25 former layers changed; 316 758 → 331 770 bytes (+4.7 %). FEAT-CLEAR-GROUND-COVERAGE sets no ceiling yet. The `clear-ground-covers-what-was-swept` limitation now says 26 zones.
Found on the way: the first sweep run, stopped by the stale state, stopped its `dcs-serve`, and the running survey mission did not reconnect to the next one: the mission had to be loaded again. `dcs-serve` also logs `malformed handshake: 'frameworks' is list, not an object` with the bridge carried by the mission, without effect on the calls.
