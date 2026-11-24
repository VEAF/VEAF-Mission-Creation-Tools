# 02 — No repair with the enemy at the gates

Status: 🧑 waiting-human — the flight check
Type: fix

## To do

- First, a failing test: a delivery due for a zone with an enemy ground group (an assault convoy, armour) within `network.threat_radius` of its centre waits, even when the zone lost nothing for longer than `network.under_fire_seconds`; with no enemy that near, it arrives as today.
- `veafCampaignLogistics.arriveDeliveries` (line 415): a second gate beside the last loss, "an enemy ground unit alive within `threat_radius`". Reco: 5 km by default (the convoy that killed Minakh's repair stood 1.1 to 4.3 km out), read from the campaign's convoys and any enemy ground group the campaign knows, not a world search every beat. Log it like the first gate, once per delivery: `the blue supply for [Menagh] waits: an enemy convoy 2.2 km away`.
- Settings: `network.threat_radius` in `dynamic_settings.py`, the shipped defaults and their comment.
- Docs: the campaign page where the repairs are described; CHANGELOG entry.

## Done when

A zone is never repaired while an enemy ground force stands at its gates; with tests.

## Flight check

On the Campagne server: a `waits: an enemy convoy … away` line for a zone under assault, and the repair arriving once the convoy is gone.

## Done (2026-11-23)

- `veafCampaignLogistics.enemyAtTheGates(zone, side)`: the distance to the nearest living vehicle of an enemy convoy (`veafCampaign.convoys`, not ended, other side, `convoyUnits`) within `network.threat_radius` of the zone's centre.
  The campaign's own convoys only, no world search: they are the enemy ground forces the campaign sends at a zone; a player's CTLD troops or a `_spawn` group are not read.
- `arriveDeliveries`: a second gate after the last loss's, logged once per delivery: `the blue supply for [Menagh] waits: an enemy convoy 2.2 km away`.
- `network.threat_radius`: 5000 m (the convoy that killed Menagh's repair stood 1.1 to 4.3 km out), in `DYNAMIC_DEFAULTS`, `dynamic_settings.py` (natural number) and the shipped `campaign-folder-persistent/campaign.yaml` with its comment.
- Tests: `test_a_delivery_waits_while_an_enemy_convoy_stands_at_the_gates` (waits, said once, arrives once the convoy has ended), `test_an_enemy_convoy_beyond_the_threat_radius_holds_nothing` (one beyond the radius, one friendly inside), and the Python settings tests.
- Docs: *Persistent campaign*, the network section and the settings table (FR/EN).
