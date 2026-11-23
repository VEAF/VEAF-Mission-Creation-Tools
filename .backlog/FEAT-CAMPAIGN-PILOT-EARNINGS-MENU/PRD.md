# FEAT-CAMPAIGN-PILOT-EARNINGS-MENU — each pilot sees in game what he earned

Status: 🧑 waiting-human

David, 2026-11-21, after the evening on the Campagne server: "il me semblait que j'avais demandé à avoir un menu pour savoir chaque pilote qu'est-ce qu'il a gagné".

## Measured (2026-11-21)

- What each pilot earns is recorded, but nowhere a player can read it from the cockpit:
  - `dcs.log`: one `CREDITS <pilot> +<amount> (<reason>)` line per gain, and a `CREDITS SUMMARY` block when the last player leaves (FIX-CAMPAIGN-SECOND-SERVER-FLIGHT ticket 10);
  - the save: `veafCampaignEconomy.pilots[<player>]` = `{ total, reasons, stats }`, `stats` by Foothold's names (`Air`, `Helo`, `SAM`, `Ground Units`, `Infantry`, `Structure`, `Deaths`, `Warehouse delivery`);
  - the sitac's "Ranking" page (http://dcs.veaf.org:8080/foothold/map/foothold2_server, FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 03): every pilot of the campaign, with his points and kills; it lists 17 pilots on 2026-11-21.
- The session's gains by pilot are in `veafCampaignEconomy.sessionGains` until the next summary.
- The credits a kill holds until landing (`economy.landing_share`) are in `veafCampaignEconomy.held[<unit name>]` = `{ player, amount, kinds }`.
- The Campaign menu's "Crédits" entry (`veafCampaignEconomy.reportCredits`) gives the side's balance only.
- On 2026-11-21 one pilot (RexAttaque, in a JF-17) earned every personal credit of the evening; the others had only the team's gains (tasks, captures), and nobody could see this without the log.

## Decided

David, 2026-11-21: a menu in the Campaign menu where each pilot reads his own earnings.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [A "My earnings" entry in the Campaign menu](tickets/01-my-earnings-menu.md) |
