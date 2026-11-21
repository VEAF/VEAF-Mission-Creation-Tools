# 02 — A counter-attack goes where the players are not

Status: ⬜ ready
Type: feature

## Decided

David, 2026-11-21 (option c, "si c'est pas trop compliqué"): a counter-attack prefers a zone the players are not defending, so attacking a red base costs something on the other side of the front, and defending everywhere is not possible.

Cost, estimated: one ticket. The positions come from the same player list as ticket 01; only the choice of the target in `veafCampaign.attackTarget` changes.

## To do

- Today `attackTarget(side)` takes, among the enemy zones the side borders, the one with the lowest `strengthPercent()`.
- New rule: a zone is **defended** when a player counted by ticket 01 (armed to stop a convoy) is within `defended_radius` of its centre (setting, 30 km by default), in the air or on the ground. The counter-attack takes the weakest **undefended** zone; when every bordered zone is defended, the weakest one, as today.
- The players' positions are read when the counter-attack is decided; a convoy already on the road keeps its target.
- The players still hear of the convoy as today (the warning the other side gets once the convoy has left), so they can turn back: the rule makes them choose, it does not hide the attack.
- A `[CAMPAIGN DECISION]` debug line naming the zones skipped as defended.
- Tests (TDD): no player, one player near the weakest zone (the next one taken), every zone defended (the weakest), a fighter armed for air-to-air only near the zone (not a defender), the radius.
- Setting in the tools' validator (`dynamic_settings.py`) and `PERSISTENT_CAMPAIGN.md` / `.en.md`.

## Done when

A counter-attack skips the zones with a ground-attack player within 30 km while another bordered zone has none, with tests.

## In-game check

1. Fly a striker over Hatay; wait for red's next counter-attack: `dcs.log` names Hatay as skipped (defended) and the convoy leaves for another blue zone on the front.
2. With an F/A-18C armed for air-to-air only over Hatay, Hatay is not skipped.
