# 01 — Per-line header formats

Status: ✅ done

Replace the single `HEADER_PATTERN` of `veaf_logs/parser.py` by an ordered list of header formats
(DCS first, so a `dcs.log` pays one match per line as before), each with the same named groups and
its own level table. `store.py` keeps the matched format per entry (one byte, like the other
columns); the format decides the source shown for non-DCS lines, through `rules.json` sources that
carry a `formats` key instead of a `match`. Noise families take the same key, so a DCSSB family is
never searched in a `dcs.log` (without it, indexing a 13 MB production `dcs.log` went from 747 to
916 ms; with it, 792 ms).

A line matching no format is a continuation only of an entry that had a recognised header. Found on
the way: an entry followed by more than 65 535 unheaded lines overflowed the `H` continuation
counter and stopped the indexing (`OverflowError` on DCSSB's `async_errors.log`, before this lot).
The overflow line now opens an entry that inherits the format, level and source.

`rules.json`: noise families for DCSSB (mission events, polling) and LotAtc (configuration dump,
airport status, client life cycle), hidden by default. `ui/panels.py`: list a noise family only
once met, title "Bruit".
