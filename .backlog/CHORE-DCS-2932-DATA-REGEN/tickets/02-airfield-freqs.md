# 02 — Capture the GermanyCW airfield frequencies again

Status: 🧑 waiting for David (DCS must run)
Type: chore
Files: `veaf_build/dcs_data/airfield_freq_dumps/GermanyCW.json`, generated frequency table, `presets.yaml` default collections `airports-germanycw`

`poetry run veaf-build update-dcs-data --airfield-freqs --capture --theatre GermanyCW --dcs-path "C:/jeux/DCS World"`, then `poetry run veaf-build update-dcs-data --airfield-freqs`. Expected: Targa HF 5.0 → 4.6 MHz and the 20 new airfields. Chojna RSBN/PRMG live in `beacons.lua`, not `Radio.lua`.
