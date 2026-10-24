# 04 — Compare the toolkits on the 21 needs, and choose

Status: 🧑 waiting-human — David chooses (ADR 0022)

Between J1 and J2: the window cannot be started before the toolkit is chosen, and ADR 0021 chose Gio on scrolling one list.

## Done when

- Gio, Fyne, miqt and walk are rated on each of the 21 needs of the PRD, from their API or, where the API cannot settle it, from a spike — never from a feature list.
- Weight, build time and window time are set side by side, each with where it comes from.
- [ADR 0022](../../../docs/adr/0022-ui-toolkit-for-the-go-veaf-logs.md) holds the comparison and a recommendation; David's choice turns it to accepted and supersedes ADR 0021.

## Done so far (2026-10-24)

- The grid and the measurements are in ADR 0022. A walk spike (menus, tabs, a 1 M-row table with highlighted ranges, Windows 11 dark-mode calls) settled needs 3, 4 and 18: the table and the highlights work; the dark theme does not reach the menu bar, the tab strip or the header.
- miqt was not built: Qt for MinGW is not installed. Its weight is bounded from below by PySide6's Qt DLLs (26.6 MB).
- In the walk captures the tab strip shows no tab, in light mode too: likely the capture (`PrintWindow`) rather than walk, to confirm on screen before relying on it.
