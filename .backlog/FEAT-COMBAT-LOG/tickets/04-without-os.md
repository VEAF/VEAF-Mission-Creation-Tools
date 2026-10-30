# 04 — Write the file where `os` is removed

Status: ✅ done

dcs.veaf.org's `MissionScripting.lua` removes `os` and keeps `io` and `lfs` (read over SSH on 2026-10-30, before deploying the TRAINING build of Marteau du Golan). The module required all three, so on the very servers it was written for it logged one warning and wrote nothing.

`os` only gave the real date and time of the file name and `VEAF_EXPORT_DIR`. Without it, the file is `veaf-combat-log-<mission date>-<n>.jsonl` in the DCS write folder, `<n>` the first number whose file does not exist yet, and the `start` line has no `real_time`.

Done when `test_veafCombatLog.lua` writes two files with `os` removed, numbered `-1` and `-2`.
