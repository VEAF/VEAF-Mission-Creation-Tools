# 08 — Ship the Normandy parking capture and (decide) the elevation grid

Status: ✅ done — the elevation grid is still David's decision
Type: data
Files: `src/python/veaf-tools/veaf_libs/data/parking/Normandy.json` (new), `veaf_build/dcs_data/airbase_dumps/parking/Normandy.json`, known limitation `no-parking-data-outside-three-theatres`, `veaf_libs/terrain_elevation.py`

## What happens

`describe_known_limitations` says no ramp or runway start works through the MCP outside Caucasus, Persian Gulf, Syria and Sinai (Falklands data exists as an untracked file in the checkout). On Normandy every QRA starts in the air and a client slot at a parking needs a hand edit, until someone runs the capture.

Captured on 2026-10-13 with `veaf-tools dcs capture-map --parking` (3 716 stands on 90 airfields), slimmed with `veaf_build.dcs_data.parking.slim_dump` and installed in this workstation's checkout, **untracked** (`parking/Normandy.json`, 411 574 bytes): with it `create_qra` starts from the runway, and `add_air_group(start="parking-hot", airfield="Tangmere")` gives stand 8. Same state as `SinaiMap.json` was in FEAT-SINAI-PARKING-DATA.

Two things the Normandy session also hit, both already in the Sinai retours (entry 8, entry 3):

- `capture-map --parking` writes the raw format that `add_air_group` does not read; the maker has to call `slim_dump` from a VMCT checkout by hand. The command could write the slim file or say how.
- The elevation grid is not shipped (« a theatre weighs some 5.5 MB at 250 m »): `Normandy.terrain` is 1.2 MB here (3 061 121 cells, ground 0-667 m). Deciding whether to ship the grids is the Sinai ticket's question; the Normandy file is the smallest one so far.

## Done when

`Normandy.json` (parking) is committed and the known-limitation list says four-plus-two theatres; the decision on the grid is written down.

## Done

`veaf_libs/data/parking/Normandy.json` is committed (3 716 stands on 90 airfields, checked by a test); the known limitation `no-parking-data-outside-three-theatres` says six theatres. `capture-map --parking` now ends with the command that slims the dump (`veaf-build update-dcs-data --parking`, from a VMCT checkout), instead of leaving the maker with a raw file `add_air_group` does not read. The raw dump itself is not committed, as for Sinai.

Decision left to David, as for Falklands: the Normandy elevation grid (1.2 MB, the smallest so far) is **not** delivered; no theatre ships its grid today.
