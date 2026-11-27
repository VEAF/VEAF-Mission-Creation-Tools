# 01 — Zone upgrades: a permanent group bought on a friendly zone

Status: ✅ done
Type: feature

## Asked

David, 2026-11-19: buy air defence in the shop, as Foothold's "Zone Upgrades" did.

## To do

- A shop category "Renforcer une zone" / "Zone upgrades" on the player side, with a zone selector of the side's own zones (as the shop's `zones = "own"` items have):
  - air defence: Hawk, NASAMS, Patriot (one per zone at most), Avenger, Gepard;
  - ground: an infantry section, an armour platoon;
  - each from a template VEAF already has (the `veaf-units.yaml` groups, the spawn aliases), picked by the campaign's era like the garrison draw.
- The bought group **joins the zone's garrison**: drawn, placed with the garrison's placement (scenery-aware since FIX-CAMPAIGN-SECOND-SERVER-FLIGHT ticket 07), recorded in the save, put to sleep and woken with the zone, reinforced at its spawn price like the rest (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 09), lost with the zone if it is taken.
- At most **2 bought upgrades per zone**, as Foothold (a setting); the shop refuses a third, and a second Patriot on the same zone, with a message saying why.
- Price: the units' spawn price × `economy.credits_per_point` (PRD), shown in the item's label as the other items.
- Logged (`[CAMPAIGN SHOP]`), counted in the buyer's ranking if it counts purchases, and on the sitac as part of the garrison counts.
- Docs FR/EN (`PERSISTENT_CAMPAIGN.md`), the player document's shop list, CHANGELOG, tests (TDD).

## Done when

A pilot buys a Hawk on Hatay from the Campaign menu, the battery appears in the zone, survives a restart, and a third upgrade on Hatay is refused; with tests, and the in-game check written.

## Done (2026-11-20)

- Campaign → Shop → Zone upgrades → one of the players' zones → the upgrades of the campaign's era, each with its price (`veafCampaignEconomy.buildUpgradesMenu`, `buyUpgrade`).
- Catalogue `veafCampaignEconomy.UPGRADES`: Hawk, NASAMS, Patriot (`once`), the `avenger_squad` group, a Gepard section (veaf-units.yaml has no Gepard group: three Gepards and an M 818), an infantry section and an armour platoon drawn by `veafCasMission`'s generators. Eras: Hawk and Gepard cold war and modern, NASAMS, Patriot and Avenger modern only (the 1980 reference of `LONG_RANGE_AIR_DEFENSE_GROUPS`), infantry and armour every era.
- The group joins the garrison through `VeafCampaignZone:addUpgrade`: placed by `placeGarrisonGroup`, the same position filter as the garrison draw, recorded with an `upgrade` field, spawned at once when the zone is awake, queued when it is waking, recorded only when asleep. Save, sleep, wake, reinforcement and loss go through the garrison's own code.
- `economy.upgrades_per_zone` (2), checked by the tools; the third upgrade and a second Patriot are refused with a message, nothing charged.
- Price: the units' spawn price × `economy.credits_per_point`, on a composition drawn once a mission (`upgradeOffer`), so the menu's price is the group placed; `economy.prices.<id>` overrides it.
- Logged: `bought the upgrade [...]`, and `[CAMPAIGN SHOP]` under `dynamic.debug`. Not counted in a ranking: the shop's commands are the coalition's, no buyer is known.
- The theatre dossier and kneeboard give the rule and the limit (`shop_lines`).

Prices measured with the default unit prices (DCS's unit database, `veafCampaign.unitPrice`): Hawk 369–381 points (≈ 2,250 credits), Patriot 148–170 (≈ 950), NASAMS 107–136 (≈ 700), Avenger 27 (162), Gepard 26 (156), infantry and armour from a few tens to about 250 credits.
A Patriot costs less than a Hawk: its launchers, like the Hawk's, carry no SAM attribute and price as guns (8 points), and the Hawk has six radars at 40 against one.
That is the spawn price's own reading, which this lot does not change; `economy.prices` fixes a price by hand.

## In-game check

1. Fly a slot of the players' side; F10 → Other → VEAF → Campaign → Shop → Zone upgrades → Hatay → Hawk battery.
2. The message says "Bought: Hawk battery (Hatay …)"; on the F10 map, the battery stands in Hatay's circle, off the runway and the buildings.
3. Restart the mission: the battery is back in Hatay (asleep then awake with the zone).
4. Buy two more upgrades on Hatay: the second is accepted, the third refused ("already holds its 2 bought upgrades"), the balance unchanged.
