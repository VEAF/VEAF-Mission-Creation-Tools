# 03 — Write a coordinate the way DCS shows it

Status: ✅ done
Type: doc

## What the pages already said

The PRD expected the documentation to be missing the seconds form. It is not: both
`doc/mission-maker/scripts/veafAirWaves.md` and its `.en.md` twin already showed
`zone_center_coordinates: "N41°00'00\" E044°00'00\""`, twice each — in the YAML example and in the
field table — and so do `src/defaults/mission-folder/mission.yaml`, `mission_template.py` and the
three test missions. The documented form was the right one all along; the tool was what broke on it.

So this ticket adds the part that was missing: **why the value looks like that, and the two ways YAML
lets you write it**. A reader who copies the coordinate out of DCS gets a string with two `"` in it,
and a double-quoted YAML scalar needs each one escaped. The single-quoted form needs no backslash but
doubles the minutes symbol instead. Both were checked to parse to the same string.

Also recorded there: spaces work as separators. `veaf.computeLLFromString` reduces `°`, `'`, `"`,
spaces, `:` and `-` to one separator (`veaf.lua:1060-1066`), so `N41 00 00 E044 00 00` is the same
position with no punctuation at all — worth knowing, and no longer the workaround it was on
2026-09-01.

Both pages carry the same explicit anchor, `{#coordinate-with-seconds}`, per the repository's
convention. `poetry run docs-check` is clean.
