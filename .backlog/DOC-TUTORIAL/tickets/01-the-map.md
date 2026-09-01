# 01 — The map: one page, the whole territory

Status: ✅ done

Type: docs · Files: `doc/mission-maker/DISCOVER.md` + `.en.md` (name it as you see fit), `mkdocs.yml`

## What it is

Ten minutes of reading that answer "what is this thing, and how do the pieces fit". Not how to do
anything — that is tickets 02 and 03.

Cover, with one short example each: the mission folder and what lives in it, what `build` actually
does, `mission.yaml` and its `modules:`, `custom_scripts:`, radio presets, dynamic slots, combat
zones, and where the VEAF Lua scripts come in at runtime.

The reader should finish able to say what each piece is for, and follow a link to the card that
teaches it.

## Definition of done

- [x] One page, both languages, in the `nav` with its `nav_translations`
- [x] Every concept named links to its card (ticket 02) or to the reference
- [x] No version number written by hand
- [x] `poetry run docs-check` passes
