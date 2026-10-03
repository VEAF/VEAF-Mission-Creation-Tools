# 01 — keep the author's spelling of the airfield name, and match it accent-insensitively

Status: ✅ done — fixed on branch `fix/airfield-channel-title-accents`

## Measured (2026-10-01, GermanyCW v6 Open Training, VMCT develop `a41477d7`)

- `plan_bases` (`presets_injector/airfield_channels_manager.py`) always writes
  `channel_title(entry["name"], tacan)`: the title is rebuilt from the DCS name, which is ASCII
  (`Buchel`, `Norvenich`). An existing title is dropped even when it names the same field.
- `_normalise` keeps `[0-9a-z]` after `casefold()` without folding accents: `Büchel` -> `bchel`,
  `Buchel` -> `buchel`. A channel found by its **title** alone (`Büchel`, under an alias that is not
  `Base-Buchel`) is therefore not matched, and `--apply` adds a second `Base-Buchel` beside it. On
  GermanyCW the aliases were `Base-Buchel` / `Base-Norvenich`, which is why the match held.

## Done when

- `_normalise` folds accents (`unicodedata` NFKD, combining marks dropped) before filtering, so
  `Büchel`, `Buchel` and `Base-Buchel` compare equal; `Nörvenich` / `Norvenich` too.
- When the existing channel's title, TACAN suffix dropped, normalises to the DCS name, `plan_bases` keeps
  that spelling and only refreshes the TACAN suffix: `Büchel` -> `Büchel / 118X`, `Büchel / 118X` stays.
  A title that names something else (normalises differently) is still replaced by the DCS name.
- The same rule in the MCP action `set_airfield_channels`, which shares `plan_bases`.
- Tests: accented title kept with TACAN added; accented title under a foreign alias matched, not
  duplicated; unrelated title replaced.
