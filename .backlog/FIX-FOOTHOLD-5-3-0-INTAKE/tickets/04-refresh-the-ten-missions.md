# 04 — Refresh and rebuild the ten missions

Status: ✅ done

The ten `VEAF-Foothold-*` repositories refreshed to Lekaa 5.3.0 with tickets 01–03, built, and committed in each repository with its `convert-other-state.yaml`.

Run from this branch's environment (the shipped 6.30.0 has neither fix), against the shared 6.30.0 `published/` scripts in `D:\dev\_VEAF\_foothold-toolchain`, with the archives copied under the folder names.

Done when: each mission validates and builds, its report and `mission.yaml` diff are read, `hercules: false` is gone, and the built `.miz` name keeps its `_ICAO_<code>`.

Done on 2026-10-17: all ten validated and built, each `.miz` embeds `zoneCommanderv2.lua` and no `zoneCommander.lua` (read in the archives), committed as `chore: update to Foothold 5.3.0` on each repository's `main`.
Reviewing the diffs found one more defect, fixed in this lot: the batch's `Write-Utf8Lines` turned an LF `mission.yaml` into CRLF when it removed `build.scripts_path` (Caucasus).
Left to David: try one mission in DCS, then deploy to foothold2.
