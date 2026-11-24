# FEAT-TRAINING-BRIEFING-PAGES — The training versions in the mission briefing

Status: ✅ done · archived 2026-11-24

David, 2026-11-03, after [`FEAT-ROLE-TRAINING-VARIANTS`](FEAT-ROLE-TRAINING-VARIANTS.md) (#1232): the training versions of *Marteau du Golan* go on Privé 1 and Privé 2 tonight, and "the briefing must be rebuilt with the training pages".
Asked which pages, he chose one page per version.

## The need

A pilot opening the briefing must find, for each training version, what it is for, what it takes out, what stays, what is drawn again at every launch, and which file to load — without reading `mission.yaml`.

## What the lot delivers

When the mission's `mission.yaml` holds a `training:` block, `build_mission_briefing` adds one page per version (A2G, CAP, SEAD, common) at the end of the deck and of its PDF.
Each page is computed with the build's own rules (`mission_builder.training_variants.plan_variant`), so it says what the `.miz` holds, and never drifts from it.

## Decisions — 2026-11-03

| # | Question | Decision |
|---|---|---|
| D1 | Which pages | One per version (David) |
| D2 | Where | At the end of the deck and of the PDF, after the target sheets: the night's briefing stays as it was, the training pages follow it |
| D3 | Names on the pages | A combat zone by its `friendly_name`, a QRA by its name, an on-demand CAP by its `menu_name`, groups by their names; a draw by its candidates |
| D4 | Kneeboard | None: a pilot in a training version needs the night's kneeboard, which the version keeps |

## Tickets

| # | Ticket | Status |
|---|---|---|
| 01 | [One briefing page per training version](FEAT-TRAINING-BRIEFING-PAGES.md) | ✅ |

## Tickets, in full

## 01 — One briefing page per training version

Status: ✅ done

### Done when

- A mission with a `training:` block gets four more pages at the end of `briefing.pptx` and `briefing.pdf`, numbered like the others; a mission without one gets the same deck as before (test).
- Each page has a table — taken out, kept, drawn at every launch — and the file to load, `<mission>_TRAINING_<ROLE>.miz`.
- The rows come from `plan_variant`: a test checks a CAP page lists the A2G zones as taken out with their air defences kept, and a SEAD page lists no draw of armour.
- A `training:` block the build would refuse is a warning of the briefing, not a crash.
- FR/EN wording in the locales; the catalogue and the briefing doc mention the pages.
