# FEAT-OBJECTIVE-BRIEFING-QUALITY — an objective mission's briefing a squadron can brief from

Status: ✅ done

David's review of the briefing `build_mission_briefing` wrote for "Marteau du Golan" (Syria, VMCT 6.33.0, flown 2026-10-29), six points.
Measured on that mission's `docs/briefing.pptx`: the ATO ran over six slides listing the 61 aircraft types each of the two bases offers in dynamic slots; the overview was 715 × 628 px beside a legend taking half the slide; the targets page was a list of names and DMS; the kneeboard flight cards were mostly the radio presets the build had already put in the cockpits.

| # | David's point | Ticket |
|---|---|---|
| 1 | With dynamic slots the ATO lists every type a base offers: say "dynamic slot", the base and the flights' callsigns | 01 |
| 2 | The overview is unreadable: framed on the useful area, free orientation with a north arrow, a much higher resolution, a compact legend | 02 |
| 3 | A locator inset on each objective zoom; target sheets rather than a bare list | 03 |
| 4 | A "strategic situation" page, and prose accepted in the existing headings | 04 |
| 5 | The flight plan step by step, as the DCS kneeboard does, and a "deployment and coordination" page | 05 |
| 6 | No radio plan on the kneeboard flight cards: the presets are already in the cockpits | 06 |

Decided with the brief (2026-10-28): every existing parameter keeps its meaning; every new text is optional and its page is left out when it is empty; fonts Google Slides knows (Calibri); the PDF follows the deck; the action's documentation and the objective prompts follow in the same lot; a test for each point.

One branch, one PR.
