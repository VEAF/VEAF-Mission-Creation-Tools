# 02 — Falklands data delivered: frequencies, parking, presets

Status: ✅ done

Files: `veaf_libs/data/airfield-frequencies.yaml`, `src/scripts/veaf/veafAirfieldFrequencies.lua`, `src/defaults/mission-folder/src/presets.yaml` (`airports-falklands`), `veaf_build/dcs_data/airfield_freq_dumps/Falklands.json`, `veaf_build/dcs_data/airbase_dumps/parking/Falklands.json`, `veaf_libs/data/parking/Falklands.json`, `known-limitations.yaml`.

## What happened

`describe_airfield_channels` failed (« no airfield frequency is known for theatre 'Falklands' ») and `add_air_group` refused every ramp or runway start (no parking capture).
Both were captured in DCS on the workstation: 26 airfields out of 27 for the frequencies (Cullen, id 28, has none), 350 stands on 27 airfields for the parking.

## Done when

- The three generated files are the output of `veaf-build update-dcs-data --airfield-freqs` from the dump: regenerated here, byte for byte the same, no hand edit.
- The parking dump is slimmed into `veaf_libs/data/parking/`; the known limitation `no-parking-data-outside-three-theatres` lists Falklands among the five theatres that ship one.
- **Not delivered, on purpose**: the elevation grid. No theatre ships one (`~/.veaf/terrain/`, swept per workstation, 4–10 MB each), so the sea and slope checks on Falklands work only where `terrain-sweep Falklands` has run. A decision for David if it should ship.
