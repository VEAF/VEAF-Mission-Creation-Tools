# FIX-MCP-LIST-CATALOG-COMPACT-CAP — `list_catalog` exceeds the compact response cap

Status: ⬜ ready

Found by the session of FIX-MCP-REPLAY-FINDINGS on 2026-11-27, already true on `develop` before that lot: in the compact profile `list_catalog` answers 7 921 characters with the response cut, because the raw list of the 77 actions is 8 228 characters and the cap is 8 000. A model with a 65 536-token context then sees a truncated catalogue.
David, 2026-11-27 (relayed by the local-model test session): its own ticket, outside the PR of FIX-MCP-REPLAY-FINDINGS, and not implemented before his go.

Two more points came from the review of PR #1357 (made by the Cherry session on the merged diff, 2026-11-27) and were left out of the small correction PR of `list_airfield_aircraft`'s description (David, relayed by the local-model test session). They are about the same compact guide and catalogue budget, so they join this lot:
- The recipe of the guide keeps real values (`country_name: "Israel"`, `Merkava_Mk4`, a JTAC `1511` / `35.55`, `"language": "fr"`); the anti-replay test only checks some keys (folder, map, place, name, date), so a model can still copy Israel into a Caucasus mission. → ticket 02.
- The compact default guide is 7 848 characters for a cap of 8 000 (the test margin was raised from 7 600 to 7 900): one more line breaks the cap. → ticket 03.

Three tickets, one PR. Not implemented before David's go.
