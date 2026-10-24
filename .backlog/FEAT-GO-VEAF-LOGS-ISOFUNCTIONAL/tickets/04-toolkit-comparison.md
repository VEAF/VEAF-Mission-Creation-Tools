# 04 — Compare the toolkits on the 21 needs, and choose

Status: 🧑 waiting-human — David chooses (ADR 0022)

Between J1 and J2: the window cannot be started before the toolkit is chosen, and ADR 0021 chose Gio on scrolling one list.

## Done when

- Gio, Fyne, miqt and walk are rated on each of the 21 needs of the PRD, from their API or, where the API cannot settle it, from a spike — never from a feature list.
- Weight, build time and window time are set side by side, each with where it comes from.
- [ADR 0022](../../../docs/adr/0022-ui-toolkit-for-the-go-veaf-logs.md) holds the comparison and a recommendation; David's choice turns it to accepted and supersedes ADR 0021.

## Done so far (2026-10-24)

- The grid and the measurements are in ADR 0022. A first walk spike (menus, tabs, a 1 M-row table with highlighted ranges) settled needs 3 and 4.
- Its dark-theme verdict was wrong: it applied a fraction of the recipe. David asked to dig; a second spike applies the whole of it and darkens the whole window, the standard message box and font chooser excepted (ADR 0022, *Dark theme on walk*).
- David set the condition: the dark theme is required. The recommendation is walk.
- miqt was not built: Qt for MinGW is not installed. Its weight is bounded from below by PySide6's Qt DLLs (26.6 MB).
- In the first spike's captures the Win32 tab strip showed no tab; irrelevant now, the tab strip is ours.
