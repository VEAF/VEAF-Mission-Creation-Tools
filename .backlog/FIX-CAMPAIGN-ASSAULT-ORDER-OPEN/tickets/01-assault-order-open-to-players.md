# 01 — The paid assault order open to every player

Status: ✅ done
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

## Done

- `veafCampaign.buildAssaultMenu`: where the order is charged (a persistent campaign, `assaultEconomy()`), the entries are added with `veafRadio.addCommandToSubmenu`, `USAGE_ForAll` like the shop's items, and the submenu is titled with its price (`Assauts (300 cr.)`); elsewhere they stay secured at the default level. `orderAssault` is unchanged: refused before any charge when the order no longer makes sense, refunded when no convoy leaves.
- The convoy cap (`convoyRoom`) is called only by the pending automatic assaults and the counter-attacks; `orderAssault` calls `sendConvoy` directly, so a paid order is never held back. Said in `orderAssault`'s comment.
- Theatre dossier's player guide: the shop's assault line reads "Convoi d'assaut (Campagne → Assauts) : 300 crédits", the price from `economy.prices.assault` over `SHOP_PRICES`, which `test_the_shop_prices_are_the_runtime_s` already checks against `veafCampaignEconomy.PRICES`.
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: a paragraph under the shop's table — where to order, the price, open to every player, refund and refusal, the cap that does not apply.
- Tests: `TestCampaignAssaultOrder` (`test_veafCampaignLive.lua`) — entries unsecured, `USAGE_ForAll`, the price in the title, an order paid and a convoy sent, too few credits sends nothing; `test_the_blue_menu_lists_each_blue_zone_towards_each_neighbour_it_does_not_hold` keeps them secured outside a persistent campaign; `test_the_shop_says_where_the_assault_is_ordered_and_its_price` for the guide.
- The in-game check above is left for the next evening on the Campagne server.
