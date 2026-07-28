# 03 — Apply the v5 posture to the ten Foothold missions

Status: ✅ done
Type: chore

## What was applied

Per David's decision — **menu hidden, passwords restored**:

| Setting | Value |
|---|---|
| `mission.silence_atc_on_all_airbases` | `true` (the v5 `VEAF_common.lua` last line) |
| `security.password_hashes` | SHA-1 of `veaf_foothold_2026` |
| `security.password_mm_hashes` | SHA-1 of `veaf_foothold_gamemaster` |
| `modules.SECURITY` | `true` (was commented out) |
| `modules.RADIO.init.create_menus` | `false` |

Verified on all ten by generating the config Lua through the real pipeline
(`_normalize_mission_yaml` → `generate_config_lua`): `veafRadio.initialize(true, true)`,
`password_L1` + `password_L9`, `password_MM`, `veaf.silenceAtcOnAllAirbases()`,
`veaf.SecurityDisabled = false`. All ten validate.

## Two incidents worth recording

**The sync script corrupted eight files.** `Get-Content`/`Set-Content` without an explicit
encoding do not round-trip UTF-8 on Windows PowerShell 5.1: eight `mission.yaml` came back with
18 `U+009D` characters each, in the em-dash and box-drawing comments of the `modules:` block. No
functional data was touched, but the files no longer parsed as YAML. Both scripts now read and
write through `[System.IO.File]::ReadAllLines/WriteAllLines` with an explicit UTF-8 encoding, and
the eight files were repaired by re-injecting the clean block from the reference.

**Normandy needed hand work, as designed.** The sync skips it (different conversion profile), and
its `modules:` block must stay its own — the `foothold-ww2` profile leaves the VEAF CTLD
available, so copying Caucasus's block would have wrongly disabled it. `security:` and
`create_menus` were applied surgically instead.

## Tasks

- [x] Apply the five settings to the Caucasus reference, validate.
- [x] Add `security` to the sync script's default key set.
- [x] Propagate to the eight other `foothold` missions.
- [x] Apply `silence_atc_on_all_airbases` per mission (it sits in `mission:` beside the name).
- [x] Hand-apply `security` + `create_menus` to Normandy without touching its module set.
- [x] Fix the UTF-8 round-trip in both PowerShell scripts; repair the eight damaged files.
- [x] Re-verify the generated Lua and `validate` on all ten.
