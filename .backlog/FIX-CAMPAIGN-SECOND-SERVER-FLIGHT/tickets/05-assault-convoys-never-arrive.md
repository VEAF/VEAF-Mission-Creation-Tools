# 05 — Assault convoys never arrive, and turn back under fire

Status: ✅ done
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

## Done

- **The time**: an assault convoy's road is measured at its departure (`land.findPathOnRoads`, else the straight line × 1.3), its expected time computed at `assault_speed` plus 7 minutes to get moving, and it is retired after half as long again, `convoy_timeout` at least. Logged at departure: `assault convoy [X]: 55 km of road to [Menagh], about 89 min at 40 km/h; retired after 134 min`.
- **The speed**: `assault_speed` (40 km/h, was the 30 km/h default of `generateVehiclesRoute`); `DISPERSE_ON_ATTACK` off.
- **The progress**: every `convoy_report_seconds` (300 s), `assault convoy [X]: 33.4 km from [Menagh] after 25 min, on its way (4.1 km in 5 min)` — or `standing still`, or `turning back`.
- **Under fire**: an assault convoy (`veafGroundAI.setConvoyObjective`) hit by nothing it can answer — aircraft, a gun out of its reach — drives on instead of falling back; against a stronger ground force it still falls back (the existing rule and its test), and the campaign then retires it as "it fell back under fire", refunded, a failure for ticket 04's memory.
- A retirement on time counts as a failure too: two in a row to the same zone, and red sends no assault there for an hour (ticket 04).
- Not done: targets "within reach" (a cap on the road length): the time now follows the road, so a far target is slow but not hopeless.
- Tests: the time given by the road and the 45-minute timeout no longer retiring it; a fall-back ending the assault and counted; the progress lines; an assault under air attack driving on.

## In-game check

`grep "assault convoy" dcs.log`: each departure line with its road and time; the progress lines every 5 minutes; a convoy reaching its target (`captured by red`, or the assault absorbed) within its time; a convoy fired upon by a player's aircraft keeps `on its way`.
