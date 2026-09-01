# 05 — copy a range of lines, or a range of characters

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](../PRD.md).

Nothing copies today. `QTableView` ships no `Ctrl+C` handler of its own, so the shortcut is simply
inert, and a log one cannot paste into a ticket is half a tool.

**A range of lines** — the table. `SelectionBehavior.SelectRows` and the default
`ExtendedSelection` already give shift-click and ctrl-click; what is missing is the action.
`Ctrl+C` and a context menu copy the selected entries in log order, each as its full text —
`Entry.text`, so a stack trace comes along with the error it explains, which is the whole point of
having attached it. The context menu also offers the message alone, without the DCS header, for
the case where one wants the line and not the timestamp.

**A range of characters** — the detail pane from [ticket 03](03-detail-for-every-entry.md). A
table cell cannot select characters; a `QPlainTextEdit` can, and it already has its own copy.

The trap is that these two collide. A `Ctrl+C` `QAction` registered on the window — which is what
`_action()` does today, it calls `self.addAction()` — wins over the focused widget, so the table's
copy would fire while the cursor is in the detail pane and the user's character selection would be
silently replaced by the whole line. Scope the action to the view
(`WidgetWithChildrenShortcut`) so focus decides.

Done when a shift-selected block of lines pastes as those lines, a character selection in the
detail pane pastes as those characters, and neither steals the other's `Ctrl+C`.
