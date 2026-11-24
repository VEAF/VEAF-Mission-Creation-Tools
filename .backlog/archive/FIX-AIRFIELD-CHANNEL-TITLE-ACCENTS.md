# FIX-AIRFIELD-CHANNEL-TITLE-ACCENTS — `content airfield-channels --apply` rewrites the author's title with the DCS name

Status: ✅ done — fixed on branch `fix/airfield-channel-title-accents` · archived 2026-11-24

Found on 2026-10-01 applying the twelve GermanyCW v6 Open Training bases with the develop tool (after
FEAT-AIRFIELD-CHANNELS-FROM-DCS): `Büchel` became `Buchel / 118X`, `Nörvenich` became `Norvenich / 77X`.
The frequencies were right; the name the pilot reads in the cockpit and on the kneeboard lost its accent —
the very thing CHORE-SMALL-POLISH fixed on the kneeboard side. The mission restored both titles by hand,
and the next `--apply` will undo it again.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [keep the author's spelling of the airfield name, and match it accent-insensitively](FIX-AIRFIELD-CHANNEL-TITLE-ACCENTS.md) | ✅ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**`content airfield-channels --apply` rewrites the author's title with the DCS name.** Found 2026-10-01 on GermanyCW v6: `Büchel` became `Buchel / 118X`, `Nörvenich` `Norvenich / 77X`; and the name matching does not fold accents, so a channel known only by an accented title would be duplicated. One ticket

## Tickets, in full

## 01 — keep the author's spelling of the airfield name, and match it accent-insensitively

Status: ✅ done — fixed on branch `fix/airfield-channel-title-accents`

### Measured (2026-10-01, GermanyCW v6 Open Training, VMCT develop `a41477d7`)

- `plan_bases` (`presets_injector/airfield_channels_manager.py`) always writes
  `channel_title(entry["name"], tacan)`: the title is rebuilt from the DCS name, which is ASCII
  (`Buchel`, `Norvenich`). An existing title is dropped even when it names the same field.
- `_normalise` keeps `[0-9a-z]` after `casefold()` without folding accents: `Büchel` -> `bchel`,
  `Buchel` -> `buchel`. A channel found by its **title** alone (`Büchel`, under an alias that is not
  `Base-Buchel`) is therefore not matched, and `--apply` adds a second `Base-Buchel` beside it. On
  GermanyCW the aliases were `Base-Buchel` / `Base-Norvenich`, which is why the match held.

### Done when

- `_normalise` folds accents (`unicodedata` NFKD, combining marks dropped) before filtering, so
  `Büchel`, `Buchel` and `Base-Buchel` compare equal; `Nörvenich` / `Norvenich` too.
- When the existing channel's title, TACAN suffix dropped, normalises to the DCS name, `plan_bases` keeps
  that spelling and only refreshes the TACAN suffix: `Büchel` -> `Büchel / 118X`, `Büchel / 118X` stays.
  A title that names something else (normalises differently) is still replaced by the DCS name.
- The same rule in the MCP action `set_airfield_channels`, which shares `plan_bases`.
- Tests: accented title kept with TACAN added; accented title under a foreign alias matched, not
  duplicated; unrelated title replaced.
