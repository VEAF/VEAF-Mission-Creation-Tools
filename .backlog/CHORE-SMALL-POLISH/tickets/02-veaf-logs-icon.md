# 02 — an icon on `veaf-logs.exe`

Status: ✅ done

David, 2026-09-29: put an icon on the `veaf-logs` executable.

`veaf-logs.spec` builds the `EXE(...)` with no `icon=` argument, and no `.ico` exists in the
repository today. So the work is: an `.ico` (with the sizes Windows asks for, 16 to 256 px), the
`icon=` argument in the spec, and the same icon as the Qt window icon so the taskbar and the title
bar match the file.

## Done when

- The built `veaf-logs.exe` shows the icon in Explorer, and the running window shows it in the
  taskbar.
- Where the icon comes from is written down (drawn for the project, or taken from VEAF's own
  artwork with the right to use it).

## Closed (2026-09-29)

- **Where the icon comes from: drawn for the project** with Pillow — a log page titled DCS, with
  level-coloured lines (grey, amber, red), under a magnifier. David chose it over a Flaticon icon,
  which would have needed an author credit. No existing artwork was used.
- `src/python/veaf-tools/veaf_logs/veaf-logs.ico`, sizes 16, 24, 32, 48, 64, 128 and 256 px.
  `veaf-logs.spec` puts it on the executable (`icon=`) and ships it next to the module like
  `rules.json` (`datas`); `run()` sets it as the application's window icon
  (`veaf_logs.appearance.APP_ICON_PATH`); `pyproject.toml` ships it in the wheel.
- **Checked on a built `dist/veaf-logs.exe`:** PyInstaller logs "Copying icon to EXE", and the icon
  Windows extracts from the file (`ExtractAssociatedIcon`, 32 px) is this one. The running window's
  taskbar icon was **not** looked at; `test_icon.py` checks that Qt loads the icon with its 16 px size.
