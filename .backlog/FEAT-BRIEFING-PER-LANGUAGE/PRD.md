# FEAT-BRIEFING-PER-LANGUAGE — a mission briefing in each language of a bilingual mission

Status: ⬜ ready

Origin: the demo mission's kneeboard step (VEAF/VEAF-Demo-Mission-v6#11, 2026-10-26).
The demo builds every weather variant twice, a `_FR` and an `_EN` mission (`build_variants`, profiles `FR` and `EN`), and wants `build_mission_briefing` to put its pages in the kneeboard of both.
It cannot: the action has one language and writes everywhere.

## Problem

Read in `mission_briefing/mission_briefing_worker.py` (develop, ce247729):

- The language is `mission.language` of `mission.yaml` (`_mission_language`); no parameter changes it.
- The pictures and the kneeboard pages go into **every** archive `built_archives` returns: the build's own `.miz` and every `missions/*.miz`, whatever its language.
- They also go into the mission folder (`l10n/DEFAULT/briefing-*.jpg`, `KNEEBOARD/IMAGES/0N-briefing-*.jpg`), and the deck and PDF into `docs/briefing.pptx` and `docs/briefing.pdf`.

So an `_EN` mission gets French maps and kneeboard pages, and a second call with English words would overwrite the French missions' pages as well as the French deck.

## What to build

One ticket: [01 — a `language` parameter, writing only the archives of that language](tickets/01-language-parameter.md).

Done when: two calls, one per language, leave every archive with the pages of its own language, the folder and the deck of the mission's language untouched by the other call, with tests; the catalogue page and the objective prompt say how to brief a bilingual mission.
