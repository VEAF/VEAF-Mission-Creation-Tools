# 09 — Units revived by a delivery are paid at their spawn price

Status: 🧑 waiting-human — implemented, waits for the in-game check
Type: fix

## Found

dcs.log, 2026-11-19 21:22:44 UTC: the red supply helicopter (paid 15 points) landed at Aleppo, and the log says `zone [Aleppo]: group [Aleppo garrison] reinforced, 7 of 7 dead unit(s) back, 56 point(s)`.
The red stock did not move by 56: the `CAMPAIGN STATUS` lines show 166 at 21:19 and 186 at 21:24, the production alone.
Cause: `VeafCampaignZone:reinforce(points)` has no limit when `points` is nil, and `veafCampaign.deliver(zone, side, "helicopter")` called it without points; only the network deliveries pass their value (#1310).
David, 2026-11-19: "les unités qui sont remplacées quand un hélicoptère ravitaille une zone coûtent le prix qu'elles coûteraient si on les spawnait".
Added on David's decision, relayed by the controlling session on 2026-11-19.

## To do

Every unit a delivery brings back is paid from the side's resource stock at `veafCampaign.unitPrice`, cheapest first, as long as the stock pays; what it cannot pay stays dead; the helicopter's own price stays separate; the payment is logged.

## Implemented (2026-11-19)

`veafCampaign.deliver` reinforces through `reinforceFromStock`: `zone:reinforce(stock)` brings back the cheapest dead units the stock pays for, and `veafCampaignLogistics.pay(side, spent, "essential")` takes their price, logged as `zone [X]: N point(s) paid from the <side> stock for what the <how> brought back, M left`.
Tests: `TestCampaignReinforce` in `test_veafCampaignPersistent.lua` (a helicopter delivery debits the stock by the revived units' prices, cheapest first; nothing comes back when the stock cannot pay the cheapest; a side whose resources are not counted gets the whole group back).

The other callers:

- `deliver(zone, side, "crate")` and `deliver(zone, side, "troops")` — the players' "Zone supplies" crate and CTLD troops — go through the same function and pay the same way. None stays free: David's rule is about the units, whatever brings them, and a free path would make the crate the cheap way to refill a zone.
- `veafCampaignLogistics` (the supply network) already calls `reinforce(cost)` with the delivery's value, paid when it was sent: unchanged.
- A factory's building repaired by a delivery (`repairStructure`) costs nothing, as before: the rule is about units.
- A side whose resources are not counted (`veafCampaignLogistics` inactive) gets the whole group back, as before: it has no stock to pay from.

## To check in game

A red supply helicopter landing in a damaged zone: `dcs.log` writes the `point(s) paid from the red stock` line, and the next `CAMPAIGN STATUS` stock drops by that amount (beside the production).
