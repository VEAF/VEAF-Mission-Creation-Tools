# FIX-AIRFIELD-CHANNEL-TITLE-ACCENTS — `content airfield-channels --apply` rewrites the author's title with the DCS name

Status: ⬜ ready

Found on 2026-10-01 applying the twelve GermanyCW v6 Open Training bases with the develop tool (after
FEAT-AIRFIELD-CHANNELS-FROM-DCS): `Büchel` became `Buchel / 118X`, `Nörvenich` became `Norvenich / 77X`.
The frequencies were right; the name the pilot reads in the cockpit and on the kneeboard lost its accent —
the very thing CHORE-SMALL-POLISH fixed on the kneeboard side. The mission restored both titles by hand,
and the next `--apply` will undo it again.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [keep the author's spelling of the airfield name, and match it accent-insensitively](tickets/01-keep-author-spelling.md) | ⬜ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**`content airfield-channels --apply` rewrites the author's title with the DCS name.** Found 2026-10-01 on GermanyCW v6: `Büchel` became `Buchel / 118X`, `Nörvenich` `Norvenich / 77X`; and the name matching does not fold accents, so a channel known only by an accented title would be duplicated. One ticket
