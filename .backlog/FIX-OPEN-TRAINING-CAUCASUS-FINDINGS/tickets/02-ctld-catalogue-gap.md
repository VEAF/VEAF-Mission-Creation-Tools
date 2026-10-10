# 02 — validate reports a CTLD catalogue gap, and a command fills it

Status: ⬜ ready

Files: `veaf_libs/ctld_config.py`, the validator, a `mission` subcommand, the CTLD page of the documentation FR/EN, tests.

## What happened

A mission's `ctld-config.yaml` is a complete snapshot of the CTLD catalogue, carrying the `configVersion` it was written against (ADR 0016).
The 6.29.0 release vendors catalogue `2.2.0`; the Caucasus OT v6 file said `2.0.0`.
CTLD noticed at mission start and printed it to every player: three settings absent, defaults used (`enableParachuteDrop`, `crateDropExtraDistance`, `crateSpawnGap`).
On the tools' side nothing reads `configVersion` (`git grep configVersion -- src/python` finds nothing), so `validate` and `build` were silent.
The fix was copying three keys from the catalogue embedded in `CTLD.lua` into the right sections and bumping `configVersion` by hand.

Below the top level, CTLD says nothing at all.
Syria-v6 and Caucasus-v6, both at `2.2.0` after the fix, still lack the scalar keys the 2.2.0 catalogue added inside `capabilitiesByType` entries (`crateSpawnSector` and `crateSpawnDistance` on five types, `maxVehicleWeight` and `loadableVehiclesBLUE`/`RED` on the Mi-8MT) and inside `spawnableCratesModels` (`load.size`, `dynamic.size`).
CTLD reads these entries whole, with no fallback to the catalogue (`CTLDConfig:load`, ADR 0011), so a mission keeps the 2.0 behaviour (radial crate placement, no vehicle in a Mi-8) without any message.
Adding them changes the game, so the command below does not do it; `validate` lists them apart, as new features the mission does not use.

The build never rewrites `ctld-config.yaml`, on purpose (`mission_builder_worker.py:1013`, the maker's file); this ticket keeps that.

## Done when

- `mission validate` compares the mission's `configVersion` with the vendored catalogue's and, when they differ, lists the settings the mission lacks, as a warning, not an error: CTLD runs fine on its defaults.
- A setting removed from the catalogue is listed apart: it is ignored, and the maker may want to drop it.
- An explicit command (for example `mission ctld-upgrade`) adds the missing settings at their catalogue default, in the section the catalogue puts them in, bumps `configVersion`, and changes no existing value. Lists are not touched: a missing list is an intentional removal.
- Tests: a 2.0.0 snapshot against a 2.2.0 catalogue gives the three settings above; after the command, `validate` is quiet and the existing values are byte for byte the same.
