# FIX-BRIEFING-PARITY-MARTEAU-2 — what the retest of #1210 still found

Status: ✅ done · archived 2026-11-24

A second regeneration of "Marteau du Golan"'s briefing (2026-10-28, develop 36e3722b, with #1210) found D1 and D3 to D9 fixed and D2 partly: the overview and a few finishes stay below the hand-made deck.
This lot closes them, so that the mission's hand-written scripts (`docs/build/`) can be retired.

| # | What | Ticket | Status |
|---|---|---|---|
| 1 | The overview shows the departure bases and the enemy's QRA bases and frames them, the tankers' flight levels, and no second helicopter route from a drawing | 01 | ✅ |
| 2 | The combat map: the key covers no label, objectives named as the flight plan names them, no QRA arcs | 02 | ✅ |
| 3 | Frequency blocks with distinct headings: which flights carry them on which radio | 03 | ✅ |
| 4 | An objective can be marked prerequisite (`objectives[].status`) | 04 | ✅ |
| 5 | The kneeboard flight card is a table, with the altitudes | 05 | ✅ |
| 6 | The ATO gives the tankers' flight levels, and the JTAC, the fat cow, the GCI when the parameters give them (`support`) | 06 | ✅ |

Decided with the brief (2026-10-28): backward compatible, everything new optional; a test for each point; documentation in the same lot; texts with their accents.
One branch, one PR.

## Tickets, in full

## 01 — Bases, flight levels and one helicopter route on the overview

Status: ✅ done

No departure base nor QRA base, Ramat David out of the frame, no tanker level, a second blue helicopter route from the mission's drawing in the key.

Done when: covered by a test, and the documentation says it.

## 02 — A combat map the key does not cover

Status: ✅ done

The key covered SA-11 and W8, the objectives' titles ran into one another, the QRA arcs were scattered dashes.

Done when: covered by a test, and the documentation says it.

## 03 — Frequency blocks with headings of their own

Status: ✅ done

Two blocks were both headed 'Radio 1 / 2 — Ninja, Arctic, Archer, Jedi, Blade'.

Done when: covered by a test, and the documentation says it.

## 04 — A prerequisite objective

Status: ✅ done

The SA-6 the helicopters wait for was 'secondary' because it is outside the operation; the hand-made deck called it a prerequisite.

Done when: covered by a test, and the documentation says it.

## 05 — The kneeboard flight card as a table

Status: ✅ done

The flight card was a list without the altitudes.

Done when: covered by a test, and the documentation says it.

## 06 — Levels, JTAC, fat cow and GCI in the ATO

Status: ✅ done

The ATO had no tanker level, no JTAC, no fat cow, no GCI: a documented known limitation.

Done when: covered by a test, and the documentation says it.
