# FEAT-CAMPAIGN-SHOP-UPGRADES — air defence and the CAS and SEAD flights in the campaign shop

Status: ⬜ ready

David, 2026-11-19, during the third server evening of "Bouclier de l'Oronte": "pourquoi on peut pas acheter de défense aérienne dans la boutique ? Regarde dans Foothold tout ce qu'on pouvait faire."
The V1 kept a small shop of items VEAF already had (`FEAT-DYNAMIC-CAMPAIGN`, "a small shop of 6 to 8 items"); it holds 11 today (`veafCampaignEconomy.lua`): JTAC drone, illumination, smoke, intel, CAP, BARCAP, capture, resupply, bombers, escort, tanker.
Air defence can be bought only by a VEAF spawn command paid in credits (`-sam`, `-hawk`…), which nothing in the Campaign menu points to, and which does not join the zone's garrison.
Compared with Foothold's catalogue (`../FEAT-DYNAMIC-CAMPAIGN/foothold-analysis/05-economy-shop-ranks-missions.md`, §5), David chose two of its families (2026-11-19, "1 et 2"); the rest stays out (below).
The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [Zone upgrades: a permanent group bought on a friendly zone](tickets/01-zone-upgrades.md) |
| 02 | [CAS and SEAD flights in the shop](tickets/02-cas-and-sead-flights.md) |

## Prices

The shop prices are in credits; the units the campaign spawns are priced in resource points (`veafCampaign.UNIT_PRICES`, raised for air defence by FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 10), and `economy.credits_per_point` (6) converts one into the other.
Reco, a default decision: a zone upgrade costs **its units' spawn price × `credits_per_point`**, so a Hawk battery costs what spawning it costs and the two never drift apart; the flights get a fixed price next to the CAP's 400: CAS 500, SEAD 600. Estimates, to tune after an evening.

## Out (David, 2026-11-19)

Cruise missiles, TALD decoys, strikes on buildings, the strategic bomber with escort, Combined Arms groups for players, "advance capture", "fully upgrade a zone", the ranks: later or never.
