# FEAT-VEAF-LOGS-READABILITY — five things that stop veaf-logs being readable

Status: ✅ done · archived 2026-09-28

Reported 2026-09-01 after the first real sessions with `veaf-logs` (#853). None of these is a
bug: the tool does what it was built to do. They are the five places where reading a DCS log
still fights back.

## 1. The font is not adjustable

`QFont("Cascadia Mono", 9)` is written in three places — `ui/main_window.py` for the table and
for the detail label, `ui/model.py` for the `FontRole` — and the row height is a literal `18`.
Nine points on a 4K panel is unreadable, and there is no way to change it, not even a zoom.

## 2. Long lines are truncated with no way to reach the end

The Message column is set to `QHeaderView.ResizeMode.Stretch`, so it always matches the
viewport exactly and a horizontal scrollbar can never appear. A `stack traceback` line, a
long CTLD group name or a Skynet dump is elided and the end of it is simply unreachable.

## 3. The detail pane only opens for entries that carry a stack trace

`LogTab._on_selection` returns early unless `entry.continuations` is non-empty. So the one
place where a line is shown in full, unelided and selectable, is available only for script
errors — which are exactly the lines that were already the least truncated.

## 4. A search result has no context

Context exists only for *categories* in the ◐ state. A text filter narrows the view to the
matching lines and nothing else: searching for the name of a group shows the one line that
names it, without the lines that say what happened around it. `grep -C` has been the answer
to this since 1973 and the tool already implements the mechanism — it just does not offer it
to the search.

Point 4 also has a trap worth naming, because it is where a naive implementation goes wrong:
a context line pulled in around a hit must **not** resurrect a line the categories have set
to ✕. Context widens the search, it does not override the filters.

## 5. Nothing can be copied out

There is no copy at all. `QTableView` has no built-in `Ctrl+C`, so selecting rows and pressing
it does nothing — the text of a log cannot leave the tool, which is what one does with a log:
paste the failing lines into a ticket or a Discord thread.

Two granularities are needed and they want different widgets. **A range of lines** belongs to
the table, which already selects whole rows and already supports shift-click. **A range of
characters inside one line** cannot come from a table cell at all; it comes from the detail
pane of point 3, which is a real text widget. The two points therefore ship together: making
the detail pane show every entry is also what makes character-level copy possible.

## Definition of done

- [ ] Font family and size are choosable, zoomable by button, by shortcut and by `Ctrl`+wheel,
      and survive a restart
- [ ] Row height follows the font instead of a literal
- [ ] A long line can be read to its end
- [ ] The detail pane shows any selected entry, and cannot push the table off screen
- [ ] Search context is settable globally and per criterion, and obeys the category filters
- [ ] The default leaves today's behaviour unchanged: no search context until asked for
- [ ] A selected range of lines copies as text, continuations included
- [ ] A character range inside a line copies, and `Ctrl+C` in the detail pane is **not** stolen
      by the table's copy action — a window-level shortcut would do exactly that
- [ ] `LOGS.md` and `LOGS.en.md` updated, shortcuts table included

---

## Tickets, in full

## 01 — one font for every tab, and a way to change it

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](FEAT-VEAF-LOGS-READABILITY.md).

`QFont("Cascadia Mono", 9)` is built three times independently — `LogTab.view`, `LogTab.detail`,
`LogModel._mono` — and `verticalHeader().setDefaultSectionSize(18)` assumes the result. Change the
size in one of them and the rows stay 18 pixels tall.

So the first move is not the zoom, it is the single source of truth: one family and one size held
by the window, pushed to every tab that exists and to every tab opened afterwards. The row height
is then derived from the font metrics, never written down.

On top of that:

- menu **Affichage** — « Police… » (`QFontDialog`, monospace only), « Agrandir » `Ctrl++`,
  « Réduire » `Ctrl+-`, « Taille par défaut » `Ctrl+0`
- two `A−` / `A+` buttons in the top bar, for the people who do not read the menus
- `Ctrl`+wheel over the table
- bounded 6–36, so a wheel held down cannot make the tool unusable

Persisted in `session.json`. `Session.load` already drops unknown keys and fills missing ones from
the dataclass defaults, so new fields need **no** `SESSION_VERSION` bump — bumping it would throw
away every user's open files and filters for a font size.

Done when a size chosen in one tab holds in a tab opened afterwards, survives a restart, and the
rows are as tall as the glyphs.

---

## 02 — reach the end of a long line

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](FEAT-VEAF-LOGS-READABILITY.md).

`header.setSectionResizeMode(COL_MESSAGE, Stretch)` is why no horizontal scrollbar ever appears:
the column is defined as *exactly the viewport*, so there is nothing to scroll to. Switching it to
`Interactive` is one line — the question is what width to give it.

Asking Qt (`resizeColumnToContents`) samples rows and gives a width that jumps around as one
scrolls, on a model that can hold a million rows. Instead the store already holds what is needed:
`_head` is the header-line length and `_msg_at` the offset of the message inside it, both written
for every line at indexing time. Keeping a running maximum of `_head - _msg_at` costs one
comparison per line and is exact for a monospace font.

Width applied = `max(what the longest message needs, the space left by the other columns)`, so a
log of short lines still fills the window instead of leaving a gap. It grows while the background
indexer runs, and must not fight a width the user has dragged by hand.

Also `setHorizontalScrollMode(ScrollPerPixel)`: per-item horizontal scrolling on a five-column
table jumps a whole column at a time.

Done when a `stack traceback` line can be read to its last character, and a log of short lines has
no scrollbar and no empty column.

---

## 03 — the detail pane shows any entry

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](FEAT-VEAF-LOGS-READABILITY.md).

`LogTab._on_selection` hides the pane unless `entry.continuations` is non-empty. Show whatever is
selected instead.

The widget has to change with it. Today it is a `QLabel` with `setWordWrap(True)`: a forty-line
stack trace makes the label forty lines tall and pushes the table off the bottom of the window,
which is survivable only because the pane almost never opens. Once it opens for every line, that
becomes the normal case.

A read-only `QPlainTextEdit` in a vertical `QSplitter` with the table instead — it scrolls inside
its own box, the height is the user's to set, and it is a real text widget, which is what
[ticket 05](FEAT-VEAF-LOGS-READABILITY.md) needs for character-level selection.

Visible on selection, hidden when nothing is selected, per David 2026-09-01. A toggle in the
**Affichage** menu for the people who want the whole height for the table, remembered in the
session.

Done when clicking any line — an ED `INFO`, a CTLD line, a warning — shows it in full underneath.

---

## 04 — context around a search hit, without overriding the filters

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](FEAT-VEAF-LOGS-READABILITY.md).

`evaluate()` classifies each entry from its categories, then lets every text filter narrow the
result, then widens it back for the categories left in ◐. The search itself only ever narrows.

Give it the same two-level setting the categories already have, so there is one model to learn and
not two:

- `FilterSet.search_context_lines` — the common value, a spinbox in the side panel under the one
  for the categories, which gets relabelled so the two are told apart
- `TextFilter.context_lines: int | None` — the override for one criterion, a small `±` spinbox in
  the search bar, empty meaning "the common value", exactly like `CategoryRow.span`. It travels
  with the chip when the criterion is added, and shows in `describe()`

Several criteria active: the **widest** span wins, the rule `_classify` already applies when two
categories disagree. An inverted criterion (`≠`) has no hits to surround and does not count.

The part to get right is that context must not undo a filter. Snapshot what the categories allow
**before** the text filters run; the search context may only pull entries back from that snapshot.
A line hidden by level, source or noise family stays hidden however close it is to a hit.

The category context then runs after, on the widened set, so the two compose:
`test_le_contexte_se_combine_avec_la_recherche` must still pass unchanged.

Default 0 — no context until asked for, per David 2026-09-01 — so no existing search changes its
result and no existing profile changes meaning.

Done when a search with ±2 shows the two lines on each side of each hit, and turning a level to ✕
removes those of its lines from the context too.

---

## 05 — copy a range of lines, or a range of characters

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](FEAT-VEAF-LOGS-READABILITY.md).

Nothing copies today. `QTableView` ships no `Ctrl+C` handler of its own, so the shortcut is simply
inert, and a log one cannot paste into a ticket is half a tool.

**A range of lines** — the table. `SelectionBehavior.SelectRows` and the default
`ExtendedSelection` already give shift-click and ctrl-click; what is missing is the action.
`Ctrl+C` and a context menu copy the selected entries in log order, each as its full text —
`Entry.text`, so a stack trace comes along with the error it explains, which is the whole point of
having attached it. The context menu also offers the message alone, without the DCS header, for
the case where one wants the line and not the timestamp.

**A range of characters** — the detail pane from [ticket 03](FEAT-VEAF-LOGS-READABILITY.md). A
table cell cannot select characters; a `QPlainTextEdit` can, and it already has its own copy.

The trap is that these two collide. A `Ctrl+C` `QAction` registered on the window — which is what
`_action()` does today, it calls `self.addAction()` — wins over the focused widget, so the table's
copy would fire while the cursor is in the detail pane and the user's character selection would be
silently replaced by the whole line. Scope the action to the view
(`WidgetWithChildrenShortcut`) so focus decides.

Done when a shift-selected block of lines pastes as those lines, a character selection in the
detail pane pastes as those characters, and neither steals the other's `Ctrl+C`.

---
