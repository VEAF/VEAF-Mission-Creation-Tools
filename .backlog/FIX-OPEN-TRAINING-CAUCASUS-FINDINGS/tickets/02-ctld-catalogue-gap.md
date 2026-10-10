# 02 — validate reports a CTLD catalogue gap, and a command fills it

Status: ⬜ ready

Files: `veaf_libs/ctld_config.py`, the validator, a `mission` subcommand, the CTLD page of the documentation FR/EN, tests.

## What happened

A mission's `ctld-config.yaml` is a complete snapshot of the CTLD catalogue, carrying the `configVersion` it was written against (ADR 0016).
The 6.29.0 release vendors catalogue `2.2.0`; the Caucasus OT v6 file said `2.0.0`.
CTLD noticed at mission start and printed it to every player: three settings absent, defaults used (`enableParachuteDrop`, `crateDropExtraDistance`, `crateSpawnGap`).
On the tools' side nothing reads `configVersion` (`git grep configVersion -- src/python` finds nothing), so `validate` and `build` were silent.
The fix was copying three keys from the catalogue embedded in `CTLD.lua` into the right sections and bumping `configVersion` by hand.

The build never rewrites `ctld-config.yaml`, on purpose (`mission_builder_worker.py:1013`, the maker's file); this ticket keeps that.

## Done when

- `mission validate` compares the mission's `configVersion` with the vendored catalogue's and, when they differ, lists the settings the mission lacks, as a warning, not an error: CTLD runs fine on its defaults.
- A setting removed from the catalogue is listed apart: it is ignored, and the maker may want to drop it.
- An explicit command (for example `mission ctld-upgrade`) adds the missing settings at their catalogue default, in the section the catalogue puts them in, bumps `configVersion`, and changes no existing value. Lists are not touched: a missing list is an intentional removal.
- Tests: a 2.0.0 snapshot against a 2.2.0 catalogue gives the three settings above; after the command, `validate` is quiet and the existing values are byte for byte the same.
