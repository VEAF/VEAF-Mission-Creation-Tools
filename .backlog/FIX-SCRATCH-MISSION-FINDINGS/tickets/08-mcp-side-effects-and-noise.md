# 08 — MCP side effects: backups in the source, needless rewrites, a false alarm, garbled output

Status: ⬜ ready
Type: fix
Files: `mission_tools/miz_backup.py`, `veaf_mission_mcp/mission_folder.py`, `airbase.py`,
`remove_group.py`, `build_tools.py`, tests

1. **Backups inside `src/mission/`.** `backup_before_write` drops `mission.<timestamp>` next to the
   file — 45 to 51 copies in one GermanyCW session — plus `mission.<ts>.yaml` at the folder root. They
   sit in the directory the build packs and the mission maker commits. Move them out of the source
   (a gitignored `.veaf-backups/`, or a temp area) and cap their number.
2. **`set_airbase_coalition` rewrites `mission`** and backs it up although it only changes
   `warehouses`; the only diff is LF → CRLF. It also **forces `dynamicSpawn = true`**, including on a
   red base the maker wants no slot on — GermanyCW had to reset 40 red bases by script. Make it a
   parameter.
3. **`remove_group` false alarm**: "Combat zone 'QRA_Stendal' captures groups by name prefix" for a
   trigger zone that is a QRA zone. Only the zones listed in `modules.COMBATZONE.combat_zones` capture.
4. **`build_mission` output** is returned truncated to its last lines and decoded as cp1252
   (« CrÃ©Ã© »). The warnings the maker needs (METAR failure, « 0 aéronefs ») were cut off; the agent
   had to rerun the build by hand to see them. Return the full log, or its warnings, as UTF-8.

## Done when

- Each point tested; a session of 50 actions leaves `src/` with only what the maker wrote
