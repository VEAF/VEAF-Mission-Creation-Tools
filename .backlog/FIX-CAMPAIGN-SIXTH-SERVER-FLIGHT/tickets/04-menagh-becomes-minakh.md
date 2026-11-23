# 04 — Menagh becomes Minakh

Status: ⬜ ready
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
