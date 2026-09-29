# 02 — Set the briefing picture, and keep a new `mapResource` key

Status: ⬜ ready
Type: feat + fix
Files: `src/python/veaf-tools/veaf_mission_mcp/` (a `set_briefing_picture` action,
`mission_folder.save_folder_mission`), tests, AI catalogue doc

## Origin

Caucasus-v6, 2026-09-29, `tools/retours-vmct.md` n° 14 and 15.

## Measured

- DCS shows a briefing picture when the mission's `pictureFileNameB`, `pictureFileNameR` and
  `pictureFileNameN` hold a `mapResource` key whose file sits in `l10n/DEFAULT/`. GermanyCW-v6 and
  Caucasus-v6 both use `ResKey_ImageBriefing_carte = "carte.jpg"`, written by script.
- `add_sound` does the copy-and-declare for `.ogg` / `.wav` only.
- `save_folder_mission` (through `write_mission_folder`, `miz_tools.py:280`) writes `mission`,
  `warehouses` and `l10n/DEFAULT/dictionary`, not `mapResource`: a key added to
  `map_resource_content` is lost in silence — the same fail-silent `warehouses` had before
  FIX-EMPTY-WAREHOUSES. The Caucasus script had to write `mapResource` itself,
  with the serialization `add_sound` uses.

## Done when

- `set_briefing_picture` takes a `.jpg` / `.png`, copies it into `l10n/DEFAULT/`, declares it in
  `mapResource`, and references it from the three `pictureFileName*` (or the sides asked), on a
  folder or a `.miz`, backed up to `.veaf-backups/` — not next to the file, which `add_sound` does
  today and which ends up in the `.miz`.
- `save_folder_mission` writes `mapResource` when it changed, or refuses a changed one; tested.
- Ticket 01 calls it, so one command both renders and installs the map.
