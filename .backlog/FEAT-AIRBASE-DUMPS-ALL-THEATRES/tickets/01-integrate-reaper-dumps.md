# 01 — Integrate Reaper's 7 captures

Status: ✅ done
Type: feat

## Tasks

- [x] Sanity-check the 7 JSON files (schema, int ids, no duplicate names, theatre field vs
      filename) — all passed; three Afghanistan FOBs have null coordinates (kept, see PRD).
- [x] Commit them under `veaf_build/dcs_data/airbase_dumps/`.
- [x] `veaf-build update-dcs-data --airdromes` → **14 theatres, 810 airbases**.
- [x] Spot-check a known airfield per new theatre (Nellis=4, Manston=5, Bodo=7,
      Baghdad International=2, Port Stanley=1, Kabul=17, Rota=9).
- [x] Helper procedure (FR/EN): all maps ticked, contributors credited, and the two cases
      that would still call for a capture spelled out.
- [x] Developer doc: coverage stated (14 theatres / 810).
- [x] CHANGELOG + version bump.
