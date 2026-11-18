# 09 — Log lines that say the wrong thing

Status: ✅ done
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

## Done

- `veafCampaignOps.deaths`: every crash, death or kill of a unit of a campaign group is remembered, debug or not; `followRaid` and `followHelicopter` then say **"destroyed"** (a death seen) or **"gone"** (the group no longer exists, no death seen). A raid gone counts no raid shot down, and its intercept task is withdrawn, not paid.
- What removed the Tu-22M3: DCS removes an aborted AI aircraft about 3 minutes after its abort, with no event (Tacview, 2026-11-17) — written in `known-limitations.yaml` (`aborted-ai-aircraft-removed-after-three-minutes`) and the generated `dcs-runtime-traps.md`.
- `arriveDeliveries`: "lost: the zone is no longer theirs" only when it is no longer theirs; a delivery with nothing left to repair goes back to the stock ("has nothing to repair there: its N point(s) go back to the stock", counter `unneeded`).
- Tests: both branches of each.

## In-game check

The debrief's log lines: a raid or helicopter that never took off reads "gone", one shot down "destroyed"; no "is lost: the zone is no longer theirs" for a zone that is still theirs.
