# FEAT-TRAINING-BRIEFING-PAGES — The training versions in the mission briefing

Status: ✅ done

David, 2026-11-03, after [`FEAT-ROLE-TRAINING-VARIANTS`](../FEAT-ROLE-TRAINING-VARIANTS/PRD.md) (#1232): the training versions of *Marteau du Golan* go on Privé 1 and Privé 2 tonight, and "the briefing must be rebuilt with the training pages".
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
| 01 | [One briefing page per training version](tickets/01-training-pages.md) | ✅ |
