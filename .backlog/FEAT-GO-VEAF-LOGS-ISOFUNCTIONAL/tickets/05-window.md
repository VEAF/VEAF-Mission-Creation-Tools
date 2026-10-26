# 05 — J2: the window, on walk

Status: ✅ done — 2026-10-24

Milestone J2 (ADR 0022: walk, dark theme required).
Plan validated by David on 2026-10-24 with the recommendations a–d: only the menus that work, logic in pure Go packages plus a Windows smoke test, one PR, the Go CI on Windows.

## Scope

The inventory items of the window that do not need the filters panel, the profiles, the session, the remote journals or the analysis (J3–J5):

- Window (A1–A4): title, size, icon, dark theme everywhere, status bar.
- Menus (M1, M2, M4–M13): *Fichier* — current DCS log, open files (with the member choice of a `.zip`), close tab, quit; *Edition* — copy, copy without the header, select all; *Affichage* — follow, go to the end, font, zoom in and out and default size, detail panel.
- Tabs (T1): closable, reorderable by drag, tooltip with the location; a tab strip of our own.
- Table (T2–T5, T7, T8): virtualised, the catalogue's colours, folded traces, column widths, context menu, Ctrl + wheel zoom.
- Detail panel (T6), indexing in slices with progress and interruption (T9), follow and rotation (T10, T11), sources O1, O2, O4.
- Our own dialogs where Windows' stay light: message box, font chooser, list chooser.

## Done when

- The logic lives in pure Go packages with their tests: the tab document (index, follow, visible rows, copy text, status), the appearance, the tab strip model.
- `cmd/veaf-logs` is the walk window; the Gio window and its dependencies are gone.
- The `Go CI` job runs on Windows, and a smoke test opens a journal in the built executable, waits for the index, and exits cleanly.
- Measured against the Python: executable size, window time, indexing of the 130 MB journal.
