# 03 — The sitac ranks the pilots, as Foothold's does

Status: ⬜ ready
Type: feature

## Decided

David, 2026-11-19, following the reco of the Foothold comparison (PRD): the sitac gets Foothold's ranking page.

## To do

- VMCT: the `sitac` block gets a `playerStats` table keyed by player name: the credits earned (the per-pilot totals ticket 10 of FIX-CAMPAIGN-SECOND-SERVER-FLIGHT keeps in the save), the deaths, and the kills by category — air, SAM, ground, infantry, helicopter, structure — counted from the kills `[CAMPAIGN FLIGHT]` already sees, plus the captures. Keep Foothold's field names where the meaning is the same (`Points`, `Deaths`, `Air`, `SAM`, `Ground Units`, `Infantry`, `Helo`, `Structure`, `Zone capture`), so the ranking page reads them unchanged.
- The totals survive a restart (kept in the save, as the credits already are) and start from zero on a campaign reset.
- foothold-sitac: the VEAF reader fills the model the ranking page uses.

## Done when

After an evening, the sitac's ranking page lists each pilot of the campaign with his credits and kills, with tests on both sides.
