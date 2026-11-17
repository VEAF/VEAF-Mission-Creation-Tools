# 11 — The Campaign menu's admin commands sort last

Status: ⬜ ready
Type: fix

## Found

David, 2026-11-17: the admin commands of the **Campaign** menu are still on its first page, and the last two other entries on the second, "alors que j'avais dit que c'était les menus admin qui devaient être sur la deuxième page".
#1293 (`veafCampaign.buildAdminMenu`, commit 6bae4d93) added the admin commands **last** so they would fall to page 2, but `veafRadio` **sorts a menu's entries by label** (`sortKey or title`, `veafRadio.lua` around lines 930 and 984): the order of insertion has no effect. "Auto-contrôle (admin)" and "Compteurs (admin)" sort near the top, "Remettre la campagne à zéro (admin)" near the end, and the last two entries in alphabetical order go to page 2.
The test of #1293 checked the order of insertion, not the order rendered.

## To do

- A `sortKey` on the three admin commands that sorts them after every other entry, in every language.
- A test on the **rendered** order of the Campaign menu (what `_buildChildren` produces), admin commands last.
- Visible to everyone stays: a DCS submenu is one object for all (`FEAT-ROLE-AWARE-RADIO-MENU`, wontfix); they ask the admin level.

## Done when

The rendered Campaign menu ends with the three admin commands, on its second page when it paginates.
