---
status: proposed
---

# The UI toolkit of the Go `veaf-logs`, chosen on what the application needs

Lot: [FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL](../../.backlog/FEAT-GO-VEAF-LOGS-ISOFUNCTIONAL/PRD.md), ticket 04.
Measured on DAVID-BUREAU (Windows 11, display scaled), 2026-10-24, Go 1.27.3.
Once a decision is taken, it supersedes [ADR 0021](0021-gio-for-the-go-veaf-logs-proof-of-concept.md), whose choice of Gio rested on scrolling one list.

## Context

The goal is the same program as the Python viewer — menus, tabs, panels, profiles, filters, analysis — as a native binary (decisions of 2026-10-24: pure GUI toolkits only, no web view; Windows only).
The PRD lists 21 needs any toolkit must meet.
Four candidates: **Gio** (immediate mode, pure Go), **Fyne** (retained mode, cgo), **miqt** (bindings to Qt Widgets, cgo), **walk** (native Win32 controls, pure Go).
`lxn/walk` has had no commit since January 2021; its maintained fork, `tailscale/walk` (last push 2026-07-02, used by Tailscale's Windows client), is the candidate.

## How each need was established

From the libraries' own API (`go doc`, sources at the versions below), and, where the API could not settle it, by a spike.
**✓** the toolkit provides it; **◐** feasible with work of our own; **✗** not available.

Versions: Gio v0.10.3 and `gioui.org/x` v0.10.3, Fyne v2.8.2, `tailscale/walk` 2026-07-02, miqt (not built: no Qt for MinGW on the machine).

| # | Need | walk | Gio | Fyne | miqt |
|---|---|---|---|---|---|
| 1 | Menu bar, mnemonics, checkable entries, shortcuts | ✓ native menus, `Action.SetShortcut`, `SetCheckable` | ◐ no menu bar: built from `x/component` popup menus and key filters | ◐ menu drawn by Fyne, shortcut per item; no mnemonics found in the API (to confirm) | ✓ the Qt menus of today |
| 2 | Tabs, closable and reorderable | ◐ Win32 tab control: neither, both to build | ◐ to build | ◐ `DocTabs` closes, does not reorder | ✓ |
| 3 | Virtualised table, 1 M rows, resizable columns, multi-row selection | ✓ owner-data list view; **spike: 1 M rows** | ◐ virtual list/grid (`outlay.Grid`), columns and selection to build | ◐ virtual `Table`, but **single-cell selection** only (`Select(TableCellID)`) | ✓ |
| 4 | Several highlighted ranges in a cell | ✓ `CellStyle.Canvas`; **spike** (text measured with GDI: walk's `MeasureText` does not measure) | ✓ `x/styledtext` | ◐ `RichText` segments in cells, cost in a large table not measured | ✓ the delegate of today |
| 5 | Splitters, remembering a hidden pane | ✓ `Splitter` (hiding not tested) | ◐ `x/component` resizer | ✓ `container.Split` | ✓ |
| 6 | Read-only selectable text view | ✓ `TextEdit` | ✓ `widget.Selectable` | ◐ to confirm | ✓ |
| 7 | Spin box with prefix/suffix and special value; three-state button with its own glyph and colour | ◐ `NumberEdit` with prefix/suffix; a coloured button needs owner drawing | ◐ to build | ◐ no spin box; `Check` has a fixed partial state | ✓ |
| 8–11 | Scroll panel with groups, chips, progress bar, status bar | ✓ | ◐ (progress bar ✓) | ◐ | ✓ |
| 12 | Standard dialogs: multi-file open with filter, font chooser, prompt, list chooser, boxes | ◐ native multi-file open (`ShowOpenMultiple`) and boxes; `ChooseFont` through `win`; prompt and list chooser to build | ✗ for files: `explorer.ChooseFiles` returns readers, not paths — a followed file and a saved session need the path, so a Win32 call of our own; the rest to build | ◐ Fyne-drawn file dialog, one file at a time; no font chooser | ✓ |
| 13 | Custom modal dialog | ✓ | ◐ modal layer | ✓ | ✓ |
| 14–16 | Clipboard, open with the default application, timers and background work | ✓ | ✓ / ◐ / ✓ | ✓ | ✓ |
| 17 | Ctrl + mouse wheel | ◐ to confirm | ✓ | ◐ | ✓ |
| 18 | **Dark theme** | **✗ measured**: dark title bar only; menu bar, tab strip and table header stay light, even with Windows 11's dark-mode calls; dark everywhere means owner-drawing them, the menu bar through undocumented messages | ✓ our own palette | ✓ built in | ✓ the Fusion palette of today |
| 19–20 | Icon and geometry; fonts chosen at runtime, metrics | ✓ GDI fonts, system fonts | ◐ / ✓ system fonts (to confirm) | ◐ fonts must be bundled TTF (to confirm) | ✓ |
| 21 | Windows | ✓ (Windows only) | ✓ | ✓ | ✓ |

## Weight and speed

| | Executable | Build | Window | Source |
|---|---|---|---|---|
| walk | **6.4 MB** with menus, tabs and the 1 M-row table | 1 s, incremental (cold not measured) | created 54 ms after `main` starts (not the first painted frame) | spike, 2026-10-24 |
| Gio | 8.5 MB (one list); 12.3 MB for the proof-of-concept window with SFTP | 7.5 s | 0.27 s warm to a top-level window | ADR 0021 |
| Fyne | 23.7 MB (one list) | 4 min 05 s, cgo | 0.25 s warm | ADR 0021 |
| miqt | **at least 26.6 MB of Qt DLLs** beside the executable (`Qt6Core`, `Qt6Gui`, `Qt6Widgets`, the `qwindows` platform and a style, measured on PySide6's Qt 6, an MSVC build); one file only with a Qt rebuilt static with MinGW | not built | not measured | PySide6 install |
| Python (reference) | 47.2 MB | — | 2.1 s | POC-GO-VEAF-LOGS |

The window times are not measured the same way and only order the candidates roughly.

## Reading

- **Fyne is dominated.** It is neither native (it draws its own widgets) nor small (23.7 MB, a four-minute cgo build), and it misses multi-row selection, a native or multi-file open dialog, a spin box, a font chooser and tab reordering.
- **miqt is the shortest port and the least risk**: the same widgets as the Python, so `ui/` translates almost line for line and the look is unchanged. It gives up most of the size the rewrite is for (Qt comes back: 26.6 MB of DLLs at least, a folder rather than one file unless Qt is rebuilt static), and it brings a Qt-for-MinGW toolchain to the machine and to CI.
- **walk is the smallest and the most native**: real Windows controls, 6.4 MB with the hardest widgets in, pure Go. Its cost is the dark theme — not available for the menu bar, the tabs and the header without owner drawing, part of it through undocumented messages — and the tab close and reorder to build.
- **Gio gives full control and a dark theme for free**, at 9–12 MB, but every standard widget — menu bar, tabs, combo box, spin box, dialogs, column headers, selection — is ours to build, keyboard navigation and accessibility included. It is the largest piece of work by far.

## Decision

Pending: the choice belongs to David, and it turns on one question the code cannot answer — **must the Go viewer keep the dark theme?**
The application sets a fixed dark palette today (inventory A3); a native Windows look would follow the system's light theme instead.

- If a native light look is acceptable: **walk**.
- If the dark theme is required: **Gio** for a small binary at the price of the largest UI work, or **miqt** for the shortest port at the price of Qt's weight and toolchain.

## Consequences

To be written with the decision.
