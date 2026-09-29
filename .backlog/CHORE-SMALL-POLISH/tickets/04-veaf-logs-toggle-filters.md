# 04 — `veaf-logs`: a button to show or hide the filter panel

Status: ⬜ ready

David, 2026-09-29: a button in `veaf-logs` to show or hide the filter panel on the left, to give the
log text more width.

## Where it sits

`MainWindow` puts `self.side` (`SidePanel`, `veaf_logs/ui/panels.py` — levels, sources, ED noise,
context width) and the right-hand column in a horizontal `QSplitter`
(`veaf_logs/ui/main_window.py`, `splitter.setSizes([320, 1180])`). Dragging the handle to the edge
already collapses it, but nobody finds that, and it does not come back at a known width.

## To settle while doing it

- A checkable action, in the toolbar or the profile bar, with a keyboard shortcut; hiding the panel
  hands its width to the text, showing it restores the width it had before.
- Whether the state is remembered across restarts, like the open tabs are (`veaf_logs/session.py`).
- The filters keep applying while the panel is hidden, and something visible says so (the chips bar
  already shows the active filters — check it is enough).

## Done when

- A test toggles the action and asserts the panel's visibility and the width restored.
- `doc/mission-maker/LOGS.md` and `LOGS.en.md` mention the button and its shortcut.
