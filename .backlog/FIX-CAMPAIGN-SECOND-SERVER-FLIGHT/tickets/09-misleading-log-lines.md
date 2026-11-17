# 09 — Log lines that say the wrong thing

Status: ⬜ ready
Type: fix

## Found

- 21:33:01 `followRaid`: "bomber raid [red bomber Taftanaz] on [Payas] destroyed" — the Tu-22M3 has **no `kill`, `dead` or `crash` event**; its last event is an abort at 21:29:53, still on the ground (ticket 01). The group vanished; what removed it is unknown.
- 21:46:11 `arriveDeliveries`: "the red supply for [Aleppo] is lost: the zone is no longer theirs" — Aleppo was still red. The same `else` takes "zone lost" and "`reinforce()` found nothing to repair" (a supply helicopter had made the garrison whole 30 s earlier); the delivery is then thrown away.

## To do

- `followRaid` (and the other followers) tell "destroyed" (a death event seen) from "gone" (the group no longer exists without one), and say which.
- Find what removed the bomber (a DCS clean-up of a stuck AI aircraft? a script?), and write it down.
- `arriveDeliveries` tells "the zone is no longer theirs" from "nothing to repair"; in the second case the delivery is kept for the zone's next loss (or added to the stock), not lost.

## Done when

Tests cover the two branches of each; the debrief of the next evening can trust these lines.
