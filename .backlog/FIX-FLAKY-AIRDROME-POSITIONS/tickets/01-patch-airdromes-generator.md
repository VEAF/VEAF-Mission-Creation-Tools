# 01 — patch the airdromes generator in the dispatch tests

Status: ✅ done — 2026-10-31

`TestUpdateDcsDataDispatch._run` patches `veaf_build.dcs_data.airdromes.generate`, `airdromes.reference_airbases` and `reference.open_reference`, and a new test asserts that `update-dcs-data --all` leaves the mtime of every file under `veaf_libs/data` unchanged.

## Acceptance

- The guard test fails on `develop` and passes with the patch.
- `poetry run pytest` green.
