# 01 — Zone upgrades: a permanent group bought on a friendly zone

Status: ⬜ ready
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
