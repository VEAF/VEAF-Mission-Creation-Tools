# FIX-CAMPAIGN-ASSAULT-ORDER-OPEN — every player can order a paid blue assault

Status: 🔄 in-progress

Rex, relayed by David on 2026-11-21: "ça serait pas mal d'avoir des convois bleus, soit payants soit automatiques".

## Measured (2026-11-21)

- The Campaign menu has an "Assauts" submenu (`veafCampaign.buildAssaultMenu`): one entry per blue zone and neighbour it does not hold; `veafCampaign.orderAssault` sends a blue assault convoy at once, for `economy.assault` (300 credits) in a persistent campaign, refunded if no convoy leaves.
- The entry is added with `veafRadio.addSecuredCommandToSubmenu`, at the default level (`veafSecurity.LEVEL_SENIOR_PILOT`). Security is on on the Campagne server (`veaf.SecurityDisabled=[false]` in its `dcs.log`, 2026-11-20): an ordinary player sees the entry prefixed with "+" and cannot run it without the VEAF password.
- The shop's commands (`veafCampaignEconomy`) are not secured.
- No blue assault convoy in the Campagne server's log since 2026-11-17.
- Automatic convoys come from red only (`dynamic.attacks: [red]` in the Oronte campaign), on purpose: on 2026-11-16 blue's AI sent a free convoy to Menagh three minutes after the players had paid 300 credits for the same assault.

## Decided

David, 2026-11-21 (option a): in a persistent campaign the assault order is a purchase, paid in credits like the shop's items; it is open to every player of the players' side, and players can find it. Automatic blue convoys (option b): no.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [The paid assault order open to every player](tickets/01-assault-order-open-to-players.md) |
