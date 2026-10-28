# 01 — A shooting copy of a built mission

Status: ✅ done

`recon-photos prepare <mission.miz>` writes `<mission>_RECON.miz` beside it: clear sky (no cloud, fog, dust or precipitation, maximum visibility), the start time given (`--time HH:MM`, default 11:30), every combat zone activated at start, and `veaf.HideNamesFromSpawnedGroups = false` so the live groups carry their zone's name and can be matched to a shot.
The original is never touched.

Done when: the derived mission's weather, start time and `veaf-config.lua` are covered by tests on a fixture `.miz`.

## Result

`derive_recon_mission` and `recon-prepare`; tested on a fixture `.miz`. The in-game pass found the immediate activation loop spawning every zone two or three times: it now runs 5 s later, once per name, skipping active zones.
