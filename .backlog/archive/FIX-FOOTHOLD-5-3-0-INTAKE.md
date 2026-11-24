# FIX-FOOTHOLD-5-3-0-INTAKE — what refreshing the ten Foothold missions to Lekaa 5.3.0 found

Status: ✅ done · archived 2026-11-24

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
| 01 | [The batch finds the adopted folder of a release](FIX-FOOTHOLD-5-3-0-INTAKE.md) | ✅ |
| 02 | [`--update` rewrites `custom_scripts:` to what the release loads](FIX-FOOTHOLD-5-3-0-INTAKE.md) | ✅ |
| 03 | [A withdrawn module is a warning, not an error](FIX-FOOTHOLD-5-3-0-INTAKE.md) | ✅ |
| 04 | [Refresh and rebuild the ten missions](FIX-FOOTHOLD-5-3-0-INTAKE.md) | ✅ |

One branch, one PR for the tools; ticket 04 commits in each mission repository.

## Tickets, in full

## 01 — The batch finds the adopted folder of a release

Status: ✅ done

`Resolve-MissionFolder.ps1` matches a release archive to the folder of the same theatre.

- `Get-MissionTheatre` reads both key forms: `["theatre"] = "…"` (inside a `.miz`) and `theatre = "…"` (an adopted folder's exploded table).
- Only folders `convert-other` adopted are candidates: they carry `convert-other-state.yaml`.
  The Open Training and demo missions in the same folder no longer make a theatre ambiguous.

Left as it is: Sinai and Sinai North are two Foothold missions on one map (`SinaiMap`), so they stay ambiguous; their archives are copied under the folder names, which the name rule picks first.
Documented in the batch's help and in `doc/mission-maker/FOOTHOLD.md`.

The first refresh after this lot still needs the renamed archives: the state file did not exist before, and is written by that refresh.

Tests: `test/python/tools/test_foothold_batch_folder_matching.py` (normalized form, a non-adopted folder on the same map).

## 02 — `--update` rewrites `custom_scripts:` to what the release loads

Status: ✅ done

`convert-other --update` used to preserve the `custom_scripts:` list and only reconcile `delay_seconds`.
A script the release renamed stayed listed under its old name, and its successor was never loaded.

Now (`reconcile_custom_scripts` in `mission_builder/other_converter.py`):

- the entries the release loads are written in its load order, a new one with its upstream `delay_seconds`;
- an entry the previous release loaded and this one does not is removed;
- every other entry is the mission maker's: kept, after the upstream ones, in its own order, lines untouched;
- the file is edited as text (comments, quoting, line endings survive), and each change is named in the report.

What the previous release loaded comes from `convert-other-state.yaml`, or, for a mission adopted before that file existed, from the `mapResource` of the exploded base it left (`read_previous_upstream_scripts`), read before the extraction overwrites it.
Measured on the ten VEAF missions on 2026-10-17: every `custom_scripts:` entry was in the old `mapResource`, so none is a maker's script.

The review item asking to remove the stale entries by hand is gone: the converter removes them.

Tests: `TestUpdateReconcilesTheScriptList`, `TestPreviousUpstreamScripts` in `test/python/mission_builder/test_other_converter.py`.

## 03 — A withdrawn module is a warning, not an error

Status: ✅ done

`hercules: false` sat in all ten Foothold `mission.yaml` after the Hercules Cargo script was withdrawn in 6.18.0 (#843).
As an unknown `modules:` key it was an error, and `validate` — so the batch — refused to build any of them, for a line that switched nothing on.

`yaml_validator.py` now keeps a `_RETIRED_MODULES` table (`HERCULES` → `6.18.0`): such a key is a warning naming the release that withdrew it and asking to delete the line.
A misspelt module stays an error.

The ten missions also lose the line (ticket 04).

Test: `test_a_retired_module_is_a_warning_naming_the_release` in `test/python/test_yaml_validator.py`.

## 04 — Refresh and rebuild the ten missions

Status: ✅ done

The ten `VEAF-Foothold-*` repositories refreshed to Lekaa 5.3.0 with tickets 01–03, built, and committed in each repository with its `convert-other-state.yaml`.

Run from this branch's environment (the shipped 6.30.0 has neither fix), against the shared 6.30.0 `published/` scripts in `D:\dev\_VEAF\_foothold-toolchain`, with the archives copied under the folder names.

Done when: each mission validates and builds, its report and `mission.yaml` diff are read, `hercules: false` is gone, and the built `.miz` name keeps its `_ICAO_<code>`.

Done on 2026-10-17: all ten validated and built, each `.miz` embeds `zoneCommanderv2.lua` and no `zoneCommander.lua` (read in the archives), committed as `chore: update to Foothold 5.3.0` on each repository's `main`.
Reviewing the diffs found one more defect, fixed in this lot: the batch's `Write-Utf8Lines` turned an LF `mission.yaml` into CRLF when it removed `build.scripts_path` (Caucasus).
Left to David: try one mission in DCS, then deploy to foothold2.
