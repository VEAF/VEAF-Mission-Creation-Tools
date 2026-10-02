# 16 — save_folder_mission writes mapResource

Status: ⬜ ready

Files: `mission_tools/miz_tools.py` (`write_mission_folder`), tests.

## What happened

Caucasus Open Training v6, `tools/retours-vmct.md` point 15: a key added to `map_resource_content` is lost
in silence on a folder save. Measured: `write_mission_folder` writes `mission`, `warehouses` and
`dictionary`, never `mapResource` (`write_miz` does write it).

## Done when

- `write_mission_folder` writes `l10n/DEFAULT/mapResource` when its content changes (compared by content,
  like the dictionary), and creates it when the mission carries resources and the folder has no file.
- Tests: a key added survives a save; an unchanged table leaves the file untouched.
