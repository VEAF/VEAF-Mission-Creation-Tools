# 01 — Airdrome table from committed runtime dumps

Status: ✅ done
Type: feat

## Tasks

- [x] Rewrite `veaf_build/dcs_data/airdromes.py`: `parse_airbase_dump` (`<id><TAB><name>`),
      `load_dumps` (per-theatre `.tsv`), `generate` merges dumps into `airdromes.yaml`
      (dumped theatre replaced, others preserved). Drop `parse_beacons`/`extract_all_airdromes`.
- [x] Commit `veaf_build/dcs_data/airdrome_dumps/Syria.tsv` (225 airbases, from
      `world.getAirbases()` via dcs-bridge, category AIRDROME, helipads included).
- [x] Regenerate `src/python/veaf-tools/veaf_libs/data/airdromes.yaml` (Syria replaced,
      Caucasus etc. preserved).
- [x] CLI: `--airdromes` no longer requires `--dcs-path`; reads committed dumps.
- [x] TDD: `test_dcs_data_airdromes.py` rewritten (parse/merge/preserve + committed-artifact
      assertions on exact Syria names).
- [x] Docs: `doc/developer/dcs-data.md` + `.en.md` (sourcing table, airdrome section,
      CLI examples); `veaf_libs/dcs_airdromes.py` docstring.
- [x] CHANGELOG `[Unreleased]`; version bump 6.10.0 → 6.10.1 (pyproject + plugin.json).

## Notes

The dump was captured live: mission-pont Syria (`dcs_bridge.enabled: true`) → `dcs-serve`
→ `exec_lua world.getAirbases()`. Reusable for other theatres.
