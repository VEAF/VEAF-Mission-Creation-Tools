# 15 — A file under l10n/DEFAULT is backed up into .veaf-backups, not beside itself

Status: ⬜ ready

Files: `mission_tools/miz_backup.py`, tests.

## What happened

Caucasus Open Training v6, `tools/retours-vmct.md` point 7: `add_sound` left `dictionary.20260928-211647`
and `mapResource.…` in `src/mission/l10n/DEFAULT/`, where the build packs them into the `.miz`.
Cause, measured: `_mission_folder_of` looks for `mission.yaml` among the first **4** parents of the file,
and `src/mission/l10n/DEFAULT/<file>` is **5** levels below the folder, so the backup falls back to "next
to the file". `save_folder_mission` rewriting a `dictionary` lands in the same trap.

## Done when

- A file under `src/mission/l10n/DEFAULT/` of a mission folder is backed up into `.veaf-backups/`.
- Test through `add_sound` on a mission folder: nothing new in `l10n/DEFAULT/` but the sound.
