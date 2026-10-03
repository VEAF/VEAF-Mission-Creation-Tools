# 03 — Floor every aircraft given a role at a clearance above the ground

Status: ✅ done — verified in game 2026-10-03
Type: fix

Ticket 02's answer (DCS does not lift a too-low aircraft, 2026-10-03) turned into a floor: David's call
the same day, a floor rather than MiST's random band, at 150 m. What was done and why is in the
[PRD](../PRD.md#ticket-03-the-floor-2026-10-03).

## To see in game

`_spawn cap, side red, alt 2` over flat ground: the MiG appears about 150 m above the ground, does not
crash, and its `dcs.log` line reads `altitude … is too close to the ground, raised to …`.

## Seen in game (2026-10-03, second pass)

`_spawn cap, side red, alt 2, altdelta 1` over 20 m ground: both MiG-23 at **168 m** above the ground,
still flying more than 30 s later (this morning the MiG-21 crashed within a second). The first try
without `altdelta 1` drew an altitude above the floor and proved nothing — `altdelta 0` reads as
"not given", the ±2 000 ft default.
