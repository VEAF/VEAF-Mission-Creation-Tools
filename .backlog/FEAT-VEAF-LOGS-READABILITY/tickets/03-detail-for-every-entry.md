# 03 — the detail pane shows any entry

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](../PRD.md).

`LogTab._on_selection` hides the pane unless `entry.continuations` is non-empty. Show whatever is
selected instead.

The widget has to change with it. Today it is a `QLabel` with `setWordWrap(True)`: a forty-line
stack trace makes the label forty lines tall and pushes the table off the bottom of the window,
which is survivable only because the pane almost never opens. Once it opens for every line, that
becomes the normal case.

A read-only `QPlainTextEdit` in a vertical `QSplitter` with the table instead — it scrolls inside
its own box, the height is the user's to set, and it is a real text widget, which is what
[ticket 05](05-copy-lines-and-characters.md) needs for character-level selection.

Visible on selection, hidden when nothing is selected, per David 2026-09-01. A toggle in the
**Affichage** menu for the people who want the whole height for the table, remembered in the
session.

Done when clicking any line — an ED `INFO`, a CTLD line, a warning — shows it in full underneath.
