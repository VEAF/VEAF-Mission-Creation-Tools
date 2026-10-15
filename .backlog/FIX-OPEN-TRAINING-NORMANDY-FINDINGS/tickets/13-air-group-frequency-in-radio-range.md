# 13 — `add_air_group` writes 251 MHz on every group: the Mission Editor refuses to save a WW2 player group

Status: ✅ done
Type: fix
Files: `veaf_mission_mcp/add_air_group.py`, `veaf_mission_mcp/aircraft_identity.py` (or wherever `frequency` is set), `presets_injector/data/dcs-radio-specs.yaml`, tests

## What happens

Seen by David on 2026-10-13 opening the Normandy test mission in the Mission Editor and saving it: « Mission cannot be saved due to errors! TEST P-51D Tangmere: Invalid frequency 251 MHz — Arène rouge Fw 190 A-8: Invalid frequency 251 MHz — Arène rouge Fw 190 D-9: Invalid frequency 251 MHz ».

`add_air_group` gives every group `frequency = 251.0`, `modulation = 0` (read in `src/mission/mission`). The editor checks a **player** group's frequency against the radio of its type: P-51D 100-156 MHz, Fw 190 38.4-42.4 (`dcs-radio-specs.yaml`, `human_radio.min_mhz/max_mhz`), so the three client groups above cannot be saved. A modern UHF aircraft accepts 251; a mission built by the build alone (no save in the editor) runs, which is why the build, `validate` and 1 800 lines of checks did not see it.

The Normandy folder fixes it after the fact with `tools/fix_frequencies.py` (rewrites the table with `human_radio.default_mhz`: 35 groups).

## What ships

- `add_air_group` (and `add_player_slot`) set the group frequency to the type's `human_radio.default_mhz` when the type is in `dcs-radio-specs.yaml`, falling back to 251.0 only for a type with no spec; clamp into `[min_mhz, max_mhz]` otherwise.
- `validate` reports a group whose frequency is outside every range of its type's radios (warning for AI, error for a `Client`/`Player` group).

## Done when

A P-51D and a Fw 190 `Client` group created by `add_air_group` carry 124.0 and 38.4 and save in the Mission Editor without error; `validate` flags a P-51D at 251.

## Done

`veaf_mission_mcp/aircraft_radio.py`: a new group takes 251 MHz **when its airframe can tune it**, else the type's own `default_mhz` (124 for a P-51D, 38.4 for a Fw 190) — the ticket's « always `default_mhz` » would have moved a F-16 from 251 to 305 MHz for no reason. `add_air_group`, `add_player_slot` and the composites (`create_qra`, `create_cap_mission`) use it; an explicit frequency the airframe cannot tune is refused for a `Client` or `Player` group and warned about for an AI one. `validate` warns (not an error: the preset step rewrites a player group's frequency, so the source table is not always the last word) about a group whose frequency its airframe cannot tune.

Not done: the Mission Editor was not opened on a built mission; the claim is that the three groups of the report now carry 124.0 and 38.4, which a test holds.
