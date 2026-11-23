# 02 — No repair with the enemy at the gates

Status: ⬜ ready
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
