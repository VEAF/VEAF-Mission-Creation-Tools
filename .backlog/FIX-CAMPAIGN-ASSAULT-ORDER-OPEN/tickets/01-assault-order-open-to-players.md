# 01 — The paid assault order open to every player

Status: ⬜ ready
Type: fix

## To do

- `veafCampaign.buildAssaultMenu`: in a persistent campaign with an economy (the order is charged), add the entries with an unsecured command, as the shop does; outside it (a mission where the order is free), keep them secured as today.
  Choose the usage (`USAGE_ForAll` or `USAGE_ForGroup`) so the credits are charged and the messages reach the players' side as today; the shop's commands are the model.
- Make it findable: the shop (or its help line) and the theatre dossier's player guide (`theatre_dossier`, the guide's shop section) say that an assault convoy can be ordered from Campaign → Assauts, and its price, read from `economy.assault` over the defaults (checked against the Lua by a test, as the other prices are).
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: the assault order, its price, who can order it.
- Tests (TDD): in a persistent campaign the entries are unsecured and an order charges the credits; outside it they stay secured; the guide gives the price.
- Check that the cap of FEAT-CAMPAIGN-CONVOYS-FOLLOW-STRIKERS does not apply to a paid blue order (it caps the automatic convoys only), and say so in the code comment.

## Done when

On a server with security on, a player of the players' side without the VEAF password orders an assault from Campaign → Assauts, pays its price, and a blue convoy leaves; with tests.

## In-game check

1. On the Campagne server, as a player who has not logged in to VEAF security: F10 → Other → VEAF → Campaign → Assauts: the entries have no "+".
2. Pick one with 300 credits or more: the message says the convoy leaves, the balance drops by 300, `dcs.log` shows `blue assault convoy [...] left`.
3. With fewer than 300 credits: refused, nothing leaves.
