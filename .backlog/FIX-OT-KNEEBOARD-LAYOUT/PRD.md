# FIX-OT-KNEEBOARD-LAYOUT — the kneeboard pages of an Open Training

Status: ✅ done

Origin: the eight Open Trainings regenerated with VMCT 6.37.0 and their recon photos (2026-11-17/18), on branches `feat/kneeboard-6.37.0` of the OT repositories; the pages `build_mission_briefing` writes with `kneeboard_only`.

## Scope

| # | Ticket | Status |
|---|---|---|
| 01 | [A long page title is wrapped](tickets/01-wrapped-title.md) | ✅ |
| 02 | [The "Commandes" sheet holds on one page](tickets/02-commands-sheet-one-page.md) | ✅ |
| 03 | [An OT zone's one photo under its zoom](tickets/03-photo-under-zoom.md) | ✅ |
| 04 | [The photo caption in DDM](tickets/04-caption-ddm.md) | ✅ |
| 05 | [A zone entry is never cut between two pages](tickets/05-zone-entry-whole.md) | ✅ |

## Decisions

- Ticket 03: a landscape photo already took the page's full width, so it could not grow on a page of its own. An Open Training's one photo of a zone goes under the zoom, the map drawn at the aspect of the half left to it: the pilot sees both at once and the kneeboard loses a page per zone (Falklands 67 → 40 pages, Caucasus 62 → 36). What it costs: the zoom is drawn on about half a page, its zone circle about two thirds as large. A zone with two photos, and every one-shot mission, keep their photo page.
- Ticket 02: the prompt's text is untouched; the space between two blocks of a text page is half a line instead of a blank line, on every text page.
