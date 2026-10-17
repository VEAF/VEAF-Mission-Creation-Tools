# FIX-FOOTHOLD-5-3-0-INTAKE — what refreshing the ten Foothold missions to Lekaa 5.3.0 found

Status: ✅ done

Asked by David on 2026-10-17: update every Foothold mission VEAF uses to [Lekaa's 5.3.0 release](https://github.com/leka1986/Lekas-Foothold/releases/tag/v5.3.0) (10 archives, one per map, published 2026-10-10).
The documented procedure is `tools/Convert-FootholdBatch.ps1 -Update -Build`, run against `D:\dev\_VEAF`, where the ten `VEAF-Foothold-*` repositories live beside the Open Training and demo missions.
It failed three ways, none of them visible before running it:

1. **The batch matched no folder** (ticket 01).
   It reads the theatre of each adopted folder from `src/mission/mission`, and the regex only accepted DCS's `["theatre"] = "…"`.
   An adopted folder's exploded table is written with bare keys (`theatre = "Afghanistan"`), so all ten were "unknown" and the first one started a fresh adoption into a new folder.
   The test fixture wrote the DCS form, so the test passed and the real folders did not.
   Once that was fixed, 7 archives of 10 were still ambiguous: Open Training and demo missions on the same maps were counted as candidates.
2. **`--update` kept loading the previous release's engine** (ticket 02).
   5.3.0 renames `zoneCommander.lua` to `zoneCommanderv2.lua` on all ten maps (plus `MA_Setup_CA` → `MA_Setup_CAv2` on Caucasus and `footholdSyriaSetupv2` → `footholdSyriaSetup` on Syria).
   `--update` preserves `mission.yaml` and only reconciled `delay_seconds`, so `custom_scripts:` still listed the old file — still on disk, so `validate` passed — and never the new one.
   Built as is, every mission would have run the 4.x campaign engine against the 5.3.0 config.
   The missions predate `convert-other-state.yaml`, so the converter could not even tell the old file was upstream's.
3. **`validate` failed on all ten for `hercules: false`** (ticket 03).
   The Hercules Cargo script was withdrawn in 6.18.0 (#843); the line that disabled it stayed in every Foothold `mission.yaml` and became an unknown module, an error.

| # | Ticket | Status |
|---|--------|--------|
| 01 | [The batch finds the adopted folder of a release](tickets/01-batch-finds-the-folder.md) | ✅ |
| 02 | [`--update` rewrites `custom_scripts:` to what the release loads](tickets/02-update-rewrites-the-script-list.md) | ✅ |
| 03 | [A withdrawn module is a warning, not an error](tickets/03-retired-module-warning.md) | ✅ |
| 04 | [Refresh and rebuild the ten missions](tickets/04-refresh-the-ten-missions.md) | ✅ |

One branch, one PR for the tools; ticket 04 commits in each mission repository.
