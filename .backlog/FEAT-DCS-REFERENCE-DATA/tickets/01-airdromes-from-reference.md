# FEAT-DCS-REFERENCE-DATA-01 — airdromes from the reference data

Status: ⬜ ready
Type: feat
Files: `veaf_build/dcs_data/airdromes.py`, `veaf_libs/data/airdromes.yaml`, `veaf_libs/data/airdrome-positions.yaml`, `doc/developer/dcs-data.md` (+ `.en.md`), tests

## What

Generate `airdromes.yaml` and `airdrome-positions.yaml` in `veaf-build update-dcs-data --airdromes` from the reference package of a pinned `dcs-world-schema` release, instead of the runtime dumps under `veaf_build/dcs_data/airbase_dumps/`.
Keep the runtime dump for **TheChannel**, which the reference does not carry, until it does.

## Why

The dumps need DCS running, one theatre at a time; the reference gives the same 798 names and ids (measured identical, 2026-10-08) without it, so the files can be CI-guarded like `dcs-countries.yaml`.

## Open point

Whether to also ship the ILS of each runway (absent from `airfield-frequencies.yaml`) for the briefings and the ATIS (`FEAT-AIRFIELD-FREQS-IN-ATIS`): decide when the ticket is taken, not before.

## Done when

- `update-dcs-data --airdromes` regenerates both files from the pinned reference plus the TheChannel dump, byte-identical to the committed ones apart from the fields the reference adds.
- The CI drift guard covers them.
- Test: an airbase of a reference theatre and one of TheChannel carry their known ids.
