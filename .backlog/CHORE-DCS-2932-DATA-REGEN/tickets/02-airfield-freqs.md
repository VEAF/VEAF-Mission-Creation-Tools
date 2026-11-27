# 02 — Capture the GermanyCW airfield frequencies again

Status: ✅ done
Type: chore
Files: `veaf_build/dcs_data/airfield_freq_dumps/GermanyCW.json`, generated frequency table, `presets.yaml` default collections `airports-germanycw`

`poetry run veaf-build update-dcs-data --airfield-freqs --capture --theatre GermanyCW --dcs-path "C:/jeux/DCS World"`, then `poetry run veaf-build update-dcs-data --airfield-freqs`. Expected: Targa HF 5.0 → 4.6 MHz and the 20 new airfields. Chojna RSBN/PRMG live in `beacons.lua`, not `Radio.lua`.

Captured 2026-11-26 on DCS 2.9.32.30490 (`dcs-serve` from the VEAF-dcs-bridge `.venv` put on the PATH: none was installed next to `veaf-tools.exe`). GermanyCW: 227 → 247 airfields (radio 119 → 139, none 108 → 108), TACAN 19 → 23; no airfield gone. Changed: Tagra (87) HF 5.0 → 4.6; Norvenich (48) TACAN 77X → 109X. Regenerated: `airfield-frequencies.yaml` (442 airfields), `veafAirfieldFrequencies.lua`, `airports-*` collections of the default `presets.yaml`.
