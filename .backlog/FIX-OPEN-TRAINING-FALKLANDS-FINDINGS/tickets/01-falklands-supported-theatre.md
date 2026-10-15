# 01 — Falklands is a supported theatre

Status: ✅ done

Files: `veaf_libs/data/theatre-defaults.yaml`, `veaf_libs/data/theatre-bounds.yaml`, `test/python/veaf_libs/test_blank_mission.py`, `test/python/veaf_mission_mcp/test_geo.py`.

## What happened

`dcs-maps.yaml`, `airdromes.yaml` and `theatre_offsets.py` knew Falklands, `theatre-defaults.yaml` did not: `scaffold_mission`'s `theatre` enum (built from `supported_theatres()`) refused it, its folder came out without `src/mission/`, and `veaf-tools dcs terrain-sweep Falklands` answered « Unsupported theatre ».
`theatre-bounds.yaml` had no box for it, so `geocode` was not bounded to the map: « San Julian » came back in Jujuy, « Porvenir » in Maule, « Rio Grande » on a bank.

## Done when

- `Falklands` is in `theatre-defaults.yaml` (map centre and zero bullseyes, read in DCS), hence in the `theatre` enum of `scaffold_mission` and in `blank_mission`.
- `theatre-bounds.yaml` has a `falklands` box, lat −56.5..−48, lon −74..−56.
- Tests: the blank mission is generated and listed; the box holds Port Stanley, Ushuaia and Punta Arenas.
