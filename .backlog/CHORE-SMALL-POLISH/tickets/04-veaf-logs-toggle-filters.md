# 04 — `veaf-logs`: a button to show or hide the filter panel

Status: ✅ done

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

## Closed (2026-09-29)

- A checkable *Panneau des filtres* action (`Ctrl+B`, the usual "toggle side bar" key, free here) in
  the *Affichage* menu, carried by a button at the start of the profile bar.
- **Measured:** `QSplitter` already gives a hidden widget its width back, a window resize in between
  included — a hand-written width memory was removed once the test passed without it. The one case
  Qt does not cover is a panel collapsed with the handle, which would come back at zero width: it is
  given the default 320 px. `sizes()` still reads zero right after `setVisible(True)`, hence the
  `splitter.refresh()` before the check.
- **The chips bar is not enough** to say filters are active: it only shows text filters, not levels,
  sources or ED noise. The status bar's "N masquees par les filtres" already covers all of them, so
  nothing was added.
- Remembered across restarts (`Session.filters_visible`), like the detail pane.
- Tests (`TestPanneauDesFiltres`, 6), each checked to fail when its guard is removed. Docs: `LOGS.md`
  / `LOGS.en.md`.
