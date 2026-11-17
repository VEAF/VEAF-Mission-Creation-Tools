# 05 — Assault convoys never arrive, and turn back under fire

Status: ⬜ ready
Type: fix

## Found

Four red assault convoys tonight, four retired after 45 minutes without arriving (`convoy_timeout`, survivors refunded — #1293's fix works): Taftanaz → Afrin and Aleppo → Menagh (20:07 → 20:52, still 53 km and 33 km short at 20:42), Jisr al-Shughur → Hatay (20:57 → 21:42), Idlib → Reyhanli (21:12 → 21:57).
Each was sent again at once on the same route (ticket 04's memory of failures).
On 2026-11-16 a convoy was 37 km short after 22 minutes.
A player (Paluche) saw the convoy for Hatay **turn back towards its base as soon as he fired at it**.
Nothing in the campaign makes a convoy turn back (`retireConvoy` destroys it); `FEAT-CONVOY-UNDER-FIRE` (#1099) makes a convoy under fire fall back to the safest place, and DCS's own `DISPERSE_ON_ATTACK` takes vehicles off the road.

## To do

- Measure an assault convoy's progress: distance to its target every few minutes in the log, and in Tacview where it stops or turns.
- An **assault** convoy does not fall back like a supply convoy: it presses on, or its fall-back ends the assault (retired, refunded) instead of driving home; dispersal under attack off for it, or limited.
- Its expected travel time, from the road length and the speed, is logged at departure, so a timeout can be told from a stuck convoy.

## Done when

The log says why an assault convoy did not arrive (stopped, fell back, too slow), an assault convoy fired upon keeps its target, and a convoy reaches a target in the next evening's check.
