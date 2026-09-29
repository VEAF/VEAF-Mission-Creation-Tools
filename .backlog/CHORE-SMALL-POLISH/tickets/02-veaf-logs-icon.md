# 02 — an icon on `veaf-logs.exe`

Status: ⬜ ready

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
