# 03 — A front that moves on its own: counter-attacks, supply, CTLD 2

Status: 🧑 waiting-human — code and tests done on `feature/dynamic-campaign-v1` (2026-11-15); the in-game check of the test mission is David's

Reopened 2026-11-15: this ticket was marked 🚫 on 2026-10-06 because its capture rule moved to `FEAT-MULTI-MISSION-CAMPAIGN` ticket 04, which built it (`VeafCampaignZone:checkCapture`, `holdsGround`, CTLD 2 crates counted).
What is left here is what makes the front move without a game master (analysis note 01 §4, §6, §7, note 07 §7–§8).

## Already there, reused as is

Neutral state, timed capture by any ground presence (120 s, contested clock, cancelled when nobody is left), airbase coalition that follows the owner (so the dynamic slots follow), assault convoys towards a neutral neighbour, the F10 map and the situation menu.

## Added

- **Enemy counter-attacks.** Every `dynamic.attack_seconds` (900 s) a side with `dynamic.attacks` on picks, among the enemy zones connected to one of its own, the weakest (lowest strength), and sends an assault convoy from its neighbour; at most `dynamic.max_convoys` (2) convoys per side on the road.
  The convoy fights the garrison; a garrison destroyed turns the zone neutral and the convoy in it captures it (existing rule).
  Blue's attacks are off by default (`dynamic.attacks: [red]`): the players are blue's offensive.
- **Reinforcement by supply.** `VeafCampaignZone:reinforce()` brings back the dead units of the first damaged group of the garrison, in their places; called by each supply delivery to a friendly zone.
- **CTLD 2 troops.** Troops deployed in a neutral zone capture it (existing rule); deployed in a friendly damaged zone, they are a supply delivery: the zone is reinforced and the troops are removed.
- **Supply crates.** A CTLD 2 crate whose description is `dynamic.supply_crate` ("Zone supplies") set down in a friendly damaged zone is consumed and reinforces it; set down in a neutral zone, it holds the ground like any crate.
  The persistent example mission declares that crate in its `ctld-config.yaml`.
- Every capture and every delivery is announced to the side that made it, and credited (ticket 06).

## Done when

Lua tests: counter-attack target choice (weakest, connected, enemy), convoy cap, `reinforce` (first damaged group, places kept, materialized or dormant), troops and crate as supply, crate of another description ignored.
In game: a red convoy leaves for the weakest blue zone; a "Zone supplies" crate set down in a damaged blue zone brings its dead units back.
