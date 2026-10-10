# 05 — The build names its community scripts

Status: ✅ done

Type: fix

`summarize_active_modules` read `lua_modules` (or `modules`) only. The build hands it the normalised `mission.yaml`, where `_normalize_mission_yaml` has moved CTLD, CSAR, STTS and the other community scripts into `community_scripts`, lowercased — so the "active modules" line never named them, while they were injected.
Same trap as FIX-SCRATCH-MISSION-FINDINGS ticket 09 for QRA: the existing tests fed the raw file.

Fix: also read the enabled entries of `community_scripts`, uppercased, without duplicating an id already listed. Tested on the normalised dict, and on the report itself.
