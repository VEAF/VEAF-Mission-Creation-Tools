# 04 — Menagh becomes Minakh

Status: ✅ done
Type: chore (campaign data, no code)

## Read

The zone is named `Menagh` in `D:\dev\_VEAF\tmp\dynamic-syria\campaign.yaml` (`{ name: Menagh, at: { airfield: Minakh }, … }`); DCS calls the airfield Minakh, and David wants Minakh everywhere (WP2, map labels, messages). The zone's name is also in the save: the zone's entry, its group names (`Menagh garrison`, `Menagh upgrade 1 nasams`), and the convoys heading for it (`Aleppo - Menagh assault`).

## To do (the control session, at the next deploy)

1. Rename the zone in `campaign.yaml`, then `campaign validate` and `campaign next`.
2. With the server stopped, rewrite `Menagh` as `Minakh` in `persistent.state` (every occurrence: the zone, its groups, the convoys' names and destinations), backing up the save first; check the count of occurrences before and after.
3. Build, deploy, and check in the log that the campaign resumes from its save with a zone named `Minakh` and its garrison.

No code change: the name is the campaign's data.

## Done when

WP2 and every label read Minakh, and the save resumed with Minakh's garrison intact.

## Done (2026-11-23, the control session)

- `campaign.yaml`, `campaign-state.yaml` and `briefing.yaml` of `D:\dev\_VEAF\tmp\dynamic-syria`: `Menagh` → `Minakh` (backups `*.before-minakh`); `campaign validate` clean, `campaign next` run. The mission's briefing text (`src/mission/mission`, 4 occurrences in the descriptions) renamed too: `campaign next` does not rewrite it.
- The save, server stopped: 10 occurrences of `Menagh` → `Minakh`, none left; uploaded and checked by hash (4937997CDD8E).
- Mission built from `develop` (62f4fac1), hash DB2DCD9E6AB1, deployed on 2026-11-23 at 16:04 UTC: the campaign resumed from its save, Skynet initialized, no VEAF error. The `Menagh` left in `veaf-scripts.lua` are code comments.
