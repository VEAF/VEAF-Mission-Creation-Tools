# 01 — the shipped spawnables sit under the CJTF countries

Status: ✅ done 2026-10-02

[#985](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/985): 14 of the 51 templates of
`src/defaults/mission-folder/src/spawnables.yaml` were filed under `USA` (6), `France` (2) and `USSR`
(6). The injector adds a template's country to its side without checking the other, so a blue `France`
template in a mission where France is red lists France on both sides — the constraint the dynamic-slot
catalogue already pins (`test_dynslot_catalogue_invariants.py`).

## What was done

- The three country blocks directly followed `CJTF Blue` / `CJTF Red`, so dropping their three key
  lines merged them: 15 blue under `CJTF Blue`, 36 red under `CJTF Red`, 51 in all, ids unchanged.
- The six USSR MiG templates carried bare-number callsigns (`174`, `175`…), the Russian-style form
  `aircraft_identity.py` documents; a CJTF aircraft carries `{1, 2, 3, name}`. They now read
  `Springfield11` … `Springfield62`, family 2, one flight per template.
- `ShippedSpawnablesCountryTest` pins both: one country per side, western-shaped callsigns. Run against
  the old file it fails on all 14 templates and their 12 MiG callsigns.
- `smoke-test-mission`, `verify-mission-a` and `verify-mission-c` carried byte-identical copies of the
  old default; they get the new one. `demo-mission` has its own catalogue and is left alone.
