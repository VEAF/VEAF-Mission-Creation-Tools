# FIX-CAMPAIGN-ECONOMY-BALANCE — what the players earn pays for what the shop sells

Status: ✅ done — merged in #1323 (2026-11-20), on `develop` with #1336 (2026-11-23), shipped in 6.39.0

Flight check: after an evening on the Campagne server, the `ECONOMY SUMMARY` block follows the `CREDITS SUMMARY` one and its balances match `CAMPAIGN STATUS`; compare it with the simulator's rates and tune the prices if they differ (tickets 03, 04 and 05's in-game checks).

David, 2026-11-20, after the shop got zone upgrades (FEAT-CAMPAIGN-SHOP-UPGRADES): "il faut que les gains permettent d'acheter les trucs. Niveau équilibrage, tu t'es inspiré de Foothold ?"
Only partly, and nothing was calibrated by measurement. Compared with Foothold's rewards (`../FEAT-DYNAMIC-CAMPAIGN/foothold-analysis/05-economy-shop-ranks-missions.md`, §3) and prices (§5):

| Gain | Foothold | Ours (`veafCampaign.DYNAMIC_DEFAULTS.economy`) |
|---|---|---|
| ground unit or infantry destroyed | 10 | 10 |
| SAM destroyed (`SAM SR`, `SAM TR`, `IR Guided SAM`) | 30 | 10, as any ground unit |
| aeroplane or helicopter shot down | 50 | 30 |
| building destroyed | 100 | 50, by the sappers only |
| pilot rescued | 200 | nothing |
| zone captured | 200 | 200 |
| supply crate delivered | 100 | 100 |

Measured on the server: the team earns about 2,000 credits an evening, mostly from captures (2026-11-17 and 2026-11-19). The NASAMS prices at about 700 credits from its spawn price, against 2,000 in Foothold, for the reason the Patriot did (its launchers carry no SAM attribute; the Patriot was set to 5,000 by hand in the Oronte campaign on 2026-11-20).
Decided by David on 2026-11-20: a, b and c below.
The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [Rewards aligned on Foothold's](tickets/01-rewards-like-foothold.md) (a) |
| 02 | [NASAMS and Patriot priced like Foothold's](tickets/02-nasams-and-patriot-prices.md) (b) |
| 03 | [An evening's balance: earned and spent](tickets/03-earned-and-spent-balance.md) (c) |
| 04 | [An economy simulator to test the balance](tickets/04-economy-simulator.md) (David, 2026-11-20, after Iron Gall's pacing report) |
| 05 | [One price rule, fixed at its source](tickets/05-one-price-rule.md) (David, 2026-11-20, option a; replaces ticket 02's hand prices) |
