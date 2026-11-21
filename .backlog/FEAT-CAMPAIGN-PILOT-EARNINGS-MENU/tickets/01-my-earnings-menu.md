# 01 — A "My earnings" entry in the Campaign menu

Status: ⬜ ready
Type: feature

## To do

- A Campaign menu entry next to "Crédits", titled "Mes gains" / "My earnings" (`veaf.t`, both languages), added with `USAGE_ForGroup` as the shop's escort is, so the command knows the caller's unit and so his player name.
  In a multi-seat group, each pilot must read his own figures: use `veafRadio.addSubMenuPerPilot` (FEAT-BFR-V6-SUPPORT ticket 05) if a group can hold several players, or say in the code why one entry per group is enough.
- The message goes to the caller's group and says, for that pilot:
  1. the credits he earned this session, by reason (kills, kill credits banked at landing, deliveries…);
  2. the credits his aircraft holds now and will bank when he lands at a friendly airfield, FARP or carrier (`veafCampaignEconomy.held[<unit name>]`), or nothing when it holds none;
  3. his total since the start of the campaign (`veafCampaignEconomy.pilots[<player>].total`) and his rank among the pilots, by that total;
  4. his kills by category and his deaths, from `stats`, only the categories above zero;
  5. one line reminding that captures, tasks and network deliveries go to the whole team, with the team's total this session.
  A pilot with no books yet gets a short answer ("rien encore cette session"), not an error.
- The words a player reads: the categories in French and English as the sitac shows them, not the code's keys (`kill_held`, `Ground Units`).
- Where a session starts (the session's gains reset at each `CREDITS SUMMARY`): say in the message which period "this session" covers, or keep a per-pilot session counter that is not reset by the summary; choose the simplest that stays true after a summary said while players are still flying.
- Docs: `PERSISTENT_CAMPAIGN.md` / `.en.md` (the menu's entries) and the theatre dossier's player guide (`theatre_dossier`, the Campaign menu section).
- Demo mission: a step in `VEAF/VEAF-Demo-Mission-v6` `tour/steps.yaml` if the demo runs a persistent campaign; otherwise say so in the PR.
- Tests (TDD, `test_veafCampaignLive.lua` or a sibling): the entry exists with `USAGE_ForGroup`; a pilot with kills, held credits and a death reads each figure; a pilot with no books reads the short answer; two pilots read each their own; the team line.

## Done when

In a persistent campaign, a pilot opens F10 → Other → VEAF → Campaign → Mes gains and reads what he earned this session, what his aircraft holds, his campaign total and rank, and his kills; with tests.

## In-game check

1. On the Campagne server, kill a ground unit, then open Campaign → Mes gains before landing: the kill's credits show, and the held part as "à encaisser à l'atterrissage".
2. Land at a friendly airfield, open it again: the held part has moved into the session's gains.
3. A second player opens the same entry: he reads his own figures, not the first player's.
