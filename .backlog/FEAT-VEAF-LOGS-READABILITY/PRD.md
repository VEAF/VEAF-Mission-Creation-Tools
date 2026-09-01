# FEAT-VEAF-LOGS-READABILITY — five things that stop veaf-logs being readable

Status: ✅ done

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
