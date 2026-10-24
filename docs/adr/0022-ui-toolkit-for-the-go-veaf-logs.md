---
status: accepted
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
| 18 | **Dark theme** | **◐ measured, all but two dialogs**: see *Dark theme on walk* below — the whole window goes dark, partly through undocumented Windows entry points; the message box and the font chooser stay light and are to be replaced by dialogs of our own | ✓ our own palette | ✓ built in | ✓ the Fusion palette of today |
| 19–20 | Icon and geometry; fonts chosen at runtime, metrics | ✓ GDI fonts, system fonts | ◐ / ✓ system fonts (to confirm) | ◐ fonts must be bundled TTF (to confirm) | ✓ |
| 21 | Windows | ✓ (Windows only) | ✓ | ✓ | ✓ |

## Dark theme on walk

A first spike concluded the dark theme was out of reach: it only switched the title bar and set the app mode *after* creating the window.
David questioned it; the second spike applies the whole recipe Win32 applications use (the technique of the `win32-darkmode` and dark menu bar sample projects; not re-verified against their code here), measured on Windows 11 26H2 with the system in dark mode:

| Element | Result | How |
|---|---|---|
| Title bar | ✓ | `DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE)` |
| Drop-down menus, context menus | ✓ | `SetPreferredAppMode(ForceDark)` and `FlushMenuThemes`, **undocumented** `uxtheme` ordinals 135 and 136, called before any window exists |
| Menu bar | ✓ | painted by us on the **undocumented** `WM_UAHDRAWMENU` / `WM_UAHDRAWMENUITEM` messages, plus the one-pixel line under it on `WM_NCPAINT` |
| Table rows, area past the last column, scroll bars | ✓ | cell style, `LVM_SETBKCOLOR`, `DarkMode_Explorer` theme |
| Table header | ✓ | painted by us on `WM_PAINT` (its themes keep their own text colour, and its custom-draw notifications never reached the list view's subclass: counted 0) |
| Tabs | ✓ | a tab strip of our own, which the closable and reorderable tabs need anyway |
| Search field, mode combo box and its drop-down list, spin box, push button | ✓ | walk's own colours, `DarkMode_CFD` / `DarkMode_Explorer`, `WM_CTLCOLORLISTBOX` for the list |
| Detail panel, scroll panel, labels, status line | ✓ | walk's colours, `DarkMode_Explorer` for the scroll bars |
| Progress bar | ✓ | theme removed, then `PBM_SETBARCOLOR` / `PBM_SETBKCOLOR` |
| Open-file dialog | ✓ here | it follows the **system** theme: dark on this machine; on a Windows left in light mode it would be light (to confirm) |
| Message box, font chooser | ✗ | light even with Windows in dark mode: replaced by dialogs of our own (a text and buttons; a list of monospaced fonts and sizes) |
| Group box caption, the square where two scroll bars meet | ✗ small | a label instead of the group box caption; the square to paint (non-client area) |
| Tooltips | not tested | |

The dark-mode code of the spike is about 270 lines, a dead end included.
The undocumented parts degrade, they do not break: a missing ordinal leaves the light theme, an unhandled UAH message leaves Windows' own menu bar.
Found on the way: `GetOpenFileName` changes the process's current directory unless `OFN_NOCHANGEDIR` is passed — the spike's relative paths landed in `Documents`; the application must use absolute paths or pass the flag.

## Weight and speed

| | Executable | Build | Window | Source |
|---|---|---|---|---|
| walk | **6.4 MB** with menus, tabs and the 1 M-row table; **6.8 MB** with the dark theme, a detail panel, a progress bar and the side panel | 1 s, incremental (cold not measured) | created 54 ms after `main` starts (not the first painted frame) | spikes, 2026-10-24 |
| Gio | 8.5 MB (one list); 12.3 MB for the proof-of-concept window with SFTP | 7.5 s | 0.27 s warm to a top-level window | ADR 0021 |
| Fyne | 23.7 MB (one list) | 4 min 05 s, cgo | 0.25 s warm | ADR 0021 |
| miqt | **at least 26.6 MB of Qt DLLs** beside the executable (`Qt6Core`, `Qt6Gui`, `Qt6Widgets`, the `qwindows` platform and a style, measured on PySide6's Qt 6, an MSVC build); one file only with a Qt rebuilt static with MinGW | not built | not measured | PySide6 install |
| Python (reference) | 47.2 MB | — | 2.1 s | POC-GO-VEAF-LOGS |

The window times are not measured the same way and only order the candidates roughly.

## Reading

- **Fyne is dominated.** It is neither native (it draws its own widgets) nor small (23.7 MB, a four-minute cgo build), and it misses multi-row selection, a native or multi-file open dialog, a spin box, a font chooser and tab reordering.
- **miqt is the shortest port and the least risk**: the same widgets as the Python, so `ui/` translates almost line for line and the look is unchanged. It gives up most of the size the rewrite is for (Qt comes back: 26.6 MB of DLLs at least, a folder rather than one file unless Qt is rebuilt static), and it brings a Qt-for-MinGW toolchain to the machine and to CI.
- **walk is the smallest and the most native**: real Windows controls, 6.8 MB with the hardest widgets and the dark theme in, pure Go. Its costs: the dark theme rests partly on undocumented Windows entry points (they degrade to the light theme if they ever go), two dialogs to write ourselves, and a tab strip of our own.
- **Gio gives full control and a dark theme for free**, at 9–12 MB, but every standard widget — menu bar, tabs, combo box, spin box, dialogs, column headers, selection — is ours to build, keyboard navigation and accessibility included. It is the largest piece of work by far.

## Decision

**walk** (`tailscale/walk`), decided by David on 2026-10-24 after running the second spike: "the concept looks proven" — the spike's layout was rough, the dark theme was what it had to show.
He had set the condition first: the dark theme is required. walk meets it, with the smallest and most native binary; **Gio** would build every standard widget itself, **miqt** would bring Qt's weight and toolchain back.
This supersedes [ADR 0021](0021-gio-for-the-go-veaf-logs-proof-of-concept.md).

## Consequences

- **Windows only, and so is its CI.** walk builds on Windows alone, so the window's packages carry no other target and the `Go CI` job that compiles them runs on a Windows runner; the core (`internal/logcore`, `internal/sshlog`) stays portable and keeps its tests wherever they run today.
- **The Gio window of the proof of concept goes.** `cmd/veaf-logs` is rewritten on walk, and the Gio dependencies and their Linux build packages leave the module and the workflow.
- **A dark-theme layer of our own**, in one place: the app mode set before any window, the dark title bar, the themes per control, the menu bar on the UAH messages, the header painted on `WM_PAINT`, the combo box list on `WM_CTLCOLORLISTBOX`. Every undocumented entry point is looked up at run time and skipped when absent, so a Windows that drops one shows the light theme rather than failing.
- **Widgets of our own** where Win32 has none or cannot be darkened: the tab strip (closable, reorderable), the three-state category buttons, the message box, the font chooser, the text prompt and the list chooser.
- **Absolute paths everywhere**, or `OFN_NOCHANGEDIR` on the open dialog: `GetOpenFileName` otherwise moves the process's current directory.
- **The manifest resource** (`rsrc.syso`, common controls v6 and DPI awareness) is generated and committed with the window: walk needs it to start.
- **Not settled by the spikes, to check in J2:** tooltips in dark, the square where two scroll bars meet, and the open dialog on a Windows left in light mode.
