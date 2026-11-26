# 03 — Sweep GermanyCW clear ground again

Status: 🧑 waiting for David (DCS must run)
Type: chore
Files: `src/python/veaf-tools/veaf_libs/data/clear-ground/GermanyCW.clear-ground.json`

The shipped catalogue is 6 km round the 25 combat zones of the Open Training GermanyCW mission, swept 2026-10-22 (316 758 bytes, 25 layers). Sweep again on 2.9.32 with `clear-ground-sweep GermanyCW --zones-from <OT GermanyCW .miz> --airfields false`; compare entries and bytes before and after.
