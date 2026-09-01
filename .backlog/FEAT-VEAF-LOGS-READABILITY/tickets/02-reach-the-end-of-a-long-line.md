# 02 — reach the end of a long line

Status: ✅ done

Part of [FEAT-VEAF-LOGS-READABILITY](../PRD.md).

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
