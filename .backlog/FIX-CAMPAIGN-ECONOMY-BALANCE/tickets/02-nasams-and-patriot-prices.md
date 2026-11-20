# 02 — NASAMS and Patriot priced like Foothold's

Status: ✅ done (in-game check pending)
Type: fix

> **Superseded by [ticket 05](05-one-price-rule.md)** (2026-11-20): the hand prices below are gone; the NASAMS and the Patriot reach Foothold's prices at their spawn price, the SAM launchers priced as SAMs.

## Decided

David, 2026-11-20 (b): the NASAMS at Foothold's 2,000 credits, as the Patriot at 5,000.

## To do

- Default shop prices for the two zone upgrades whose spawn price undervalues them, their launchers pricing as guns: `nasams` 2,000 and `patriot` 5,000, in the upgrades' own defaults (a campaign's `economy.prices` still overrides them).
- Check the other upgrades the same way (Hawk ≈ 2,250, Avenger 162, Gepard 156 measured on 2026-11-20) and say in the ticket whether any other one is off; Foothold's Avenger is 1,000, its Gepard 750.
- The Oronte campaign's hand-set `economy.prices.patriot: 5000` (its `campaign.yaml`) can stay: it is the same value.
- Docs (the upgrades table of `PERSISTENT_CAMPAIGN.md`), tests.

## Done when

The shop shows the NASAMS at 2,000 and the Patriot at 5,000 credits with no campaign override, with tests.

## Done (2026-11-20)

- `veafCampaignEconomy.UPGRADES`: `nasams` `price = 2000`, `patriot` `price = 5000`. `upgradePrice` reads `economy.prices` first, then the upgrade's own `price`, then its units' spawn price; an upgrade whose group cannot be drawn is still refused.
- The theatre dossier's player guide gives the two prices (`theatre_dossier.UPGRADE_PRICES`, checked against the Lua by a test); an upgrade's entry of `economy.prices` is no longer listed as a shop item of its own in the guide (the Oronte campaign's `patriot: 5000` would have been, with no label).
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: the upgrades' prices.
- The Oronte campaign's `economy.prices.patriot: 5000` stays: the same value.

The other upgrades, against Foothold's (2026-11-20, default unit prices):

| Upgrade | Ours | Foothold's | Changed |
|---|---|---|---|
| Hawk | ≈ 2,250 | 2,000 | no: close |
| Avenger | 162 | 1,000 | no |
| Gepard | 156 | 750 | no |
| Infantry section | a few tens | 500 | no |
| Armour platoon | up to ≈ 250 | 1,000 | no |

The Avenger, the Gepard, the infantry and the armour cost five to ten times less than Foothold's.
Not changed: David decided the NASAMS and the Patriot (b), and the evening balance of ticket 03 is there to tell whether these cheap ones are bought out; a question for him after two evenings.

## In-game check

1. In a modern-era campaign with no `economy.prices` for them, F10 → Other → VEAF → Campaign → Shop → Zone upgrades → a zone: the NASAMS battery shows 2000 credits, the Patriot battery 5000.
2. Buy one: the balance drops by that much.
