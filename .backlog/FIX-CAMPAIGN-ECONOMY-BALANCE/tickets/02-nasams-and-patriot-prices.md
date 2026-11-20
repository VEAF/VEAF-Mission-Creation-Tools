# 02 — NASAMS and Patriot priced like Foothold's

Status: ⬜ ready
Type: fix

## Decided

David, 2026-11-20 (b): the NASAMS at Foothold's 2,000 credits, as the Patriot at 5,000.

## To do

- Default shop prices for the two zone upgrades whose spawn price undervalues them, their launchers pricing as guns: `nasams` 2,000 and `patriot` 5,000, in the upgrades' own defaults (a campaign's `economy.prices` still overrides them).
- Check the other upgrades the same way (Hawk ≈ 2,250, Avenger 162, Gepard 156 measured on 2026-11-20) and say in the ticket whether any other one is off; Foothold's Avenger is 1,000, its Gepard 750.
- The Oronte campaign's hand-set `economy.prices.patriot: 5000` (its `campaign.yaml`) can stay: it is the same value.
- Docs (the upgrades table of `PERSISTENT_CAMPAIGN.md`), tests.

## Done when

The shop shows the NASAMS at 2,000 and the Patriot at 5,000 credits with no campaign override, with tests.
