# FEAT-DCS-REFERENCE-DATA-01 — airdromes from the reference data

Status: ✅ done — 2026-10-08
Type: feat
Files: `veaf_build/dcs_data/reference.py`, `veaf_build/dcs_data/airdromes.py`, `veaf_build/cli.py`, `veaf_libs/data/airdromes.yaml`, `veaf_libs/data/airdrome-positions.yaml`, `.github/workflows/dcs-data-consistency.yml`, `doc/developer/dcs-data.md` (+ `.en.md`), tests

## What

Generate `airdromes.yaml` and `airdrome-positions.yaml` from the reference database of a pinned `dcs-world-schema` release, instead of the runtime dumps under `veaf_build/dcs_data/airbase_dumps/`.
Keep the runtime dump for **TheChannel**, which the reference does not carry.

## Measured (2026-10-08, `v0.5.0`)

- Names and ids: 798 of 798 identical to the dumps; `airdromes.yaml` regenerates with its header changed only.
- Positions: the reference point sits on the runways' centre (median 0 m from the mean of the runway thresholds, on all 13 theatres); `Airbase:getPoint()`, what the dumps held, lands 300 m to 1.4 km away (medians per theatre). The reference's lat/lon match its own `x`/`z` through our projection to 0.1 m.
- The Afghanistan dump had FOB Clark at (0, 0); the reference places it.

## Done

- `veaf_build/dcs_data/reference.py` downloads the SQLite asset at a pinned release and checks its SHA-256. The repository's JSON copy was not used: some of its paths exceed the Windows path limit once checked out.
- The reference wins for a theatre it knows; a dump fills a theatre it lacks. The dumps stay committed: `airfield_freqs` reads airbase names from them.
- `--airdromes` joins the no-flag / `--all` run and the CI drift guard.
- ILS per runway was left out: no consumer yet.
