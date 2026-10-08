# 02 — The watch, the split and the fight

Status: ⬜ ready

A `ConvoyUnitHandler` in `veafGroundAI`, beside the artillery one (PRD, *Design*, 1 to 5).

- The wide watch every 30 s and the close watch every 3 s; contact from an enemy in sight within 3 km, or from a shot or hit received (`S_EVENT_SHOOTING_START`, `S_EVENT_HIT`), never from a same-coalition initiator — a truck's explosion hits its neighbours.
- One contact per threat, not one per bullet.
- The split: unarmed vehicles respawned as their own group where they stand; the armed ones keep the original group and its name.
- Fight (halt, alarm red, weapons free) when the armed strength is at least 1.5 times the enemy's in sight; otherwise fall back.
- Unit tests on the mocks: the contact raised once from a burst of hits, no reaction to a same-coalition hit, the watch radius from the speed, the split's two groups, the options handed to the controller, the fight-or-flee decision for known strengths.
