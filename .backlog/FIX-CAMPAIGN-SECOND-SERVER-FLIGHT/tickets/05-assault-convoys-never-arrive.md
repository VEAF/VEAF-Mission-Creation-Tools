# 05 — Assault convoys never arrive, and turn back under fire

Status: ⬜ ready
Type: fix

## Found

Four red assault convoys tonight, four retired after 45 minutes without arriving (`convoy_timeout`, survivors refunded — #1293's fix works): Taftanaz → Afrin and Aleppo → Menagh (20:07 → 20:52, still 53 km and 33 km short at 20:42), Jisr al-Shughur → Hatay (20:57 → 21:42), Idlib → Reyhanli (21:12 → 21:57).
Each was sent again at once on the same route (ticket 04's memory of failures).
On 2026-11-16 a convoy was 37 km short after 22 minutes.
A player (Paluche) saw the convoy for Hatay **turn back towards its base as soon as he fired at it**.
Nothing in the campaign makes a convoy turn back (`retireConvoy` destroys it); `FEAT-CONVOY-UNDER-FIRE` (#1099) makes a convoy under fire fall back to the safest place, and DCS's own `DISPERSE_ON_ATTACK` takes vehicles off the road.

## Measured in Tacview (2026-11-18)

From the server's recording, distance to the target over time:

| Convoy | Straight-line distance | Covered in 45 min | Speed |
|---|---|---|---|
| Aleppo → Menagh | 42 km | 13 km | ≈ 17 km/h |
| Taftanaz → Afrin | 60 km | 16 km | ≈ 22 km/h |
| Idlib → Reyhanli | 38 km | 14 km | ≈ 24 km/h |
| Jisr al-Shughur → Hatay (2nd) | 61 km | 15 km in 40 min | ≈ 23 km/h |

Each also stood still for its first 3 to 7 minutes. At about 20 km/h on roads longer than these straight lines, **no assault convoy can arrive within the 45-minute `convoy_timeout`**: the timeout retires every one of them by construction, attacked or not. The remedy is in the numbers — a timeout derived from the road length and the speed, faster convoys, or targets within reach — not only in the behaviour under fire.

The first Jisr al-Shughur → Hatay convoy is the one Paluche fired upon: at 21:22:07 its two unarmed lorries split off ("assault unarmed #2", `FEAT-CONVOY-UNDER-FIRE`), and the armed part, 53.8 km from Hatay at 21:23:56, **was driving back** at 21:32 (54.9 km, closer to its source). The fall-back of `FEAT-CONVOY-UNDER-FIRE` turned an assault convoy around, as he saw.

## To do

- Measure an assault convoy's progress: distance to its target every few minutes in the log, and in Tacview where it stops or turns.
- An **assault** convoy does not fall back like a supply convoy: it presses on, or its fall-back ends the assault (retired, refunded) instead of driving home; dispersal under attack off for it, or limited.
- Its expected travel time, from the road length and the speed, is logged at departure, so a timeout can be told from a stuck convoy.

## Done when

The log says why an assault convoy did not arrive (stopped, fell back, too slow), an assault convoy fired upon keeps its target, and a convoy reaches a target in the next evening's check.
