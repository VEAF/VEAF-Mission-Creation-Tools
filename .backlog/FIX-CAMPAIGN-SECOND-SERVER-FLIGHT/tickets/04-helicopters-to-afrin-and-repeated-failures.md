# 04 — AI helicopters never reach Afrin, and red repeats what fails

Status: ✅ done
Type: fix

## Found

Four red supply helicopters sent from Aleppo to capture Afrin (20:17, 20:27, 20:47, 20:57): each made `ai abort mission` **16 s after its engine startup**; the first crashed on the ground without taking off (`crash` and `pilot dead`, no `hit`, CSAR "Pilot hasn't taken off"), the three others took off and landed back 2 km from Aleppo 3 minutes later ("landed 47 km from it, 2 km from [Aleppo]").
The helicopters sent from the same field to Menagh did not abort at the start; one landed in Menagh after 18 minutes.
On 2026-11-16 already two Mi-8 for Afrin landed back at Aleppo; the `REACTION_ON_THREAT = EVADE_FIRE` set by #1293 did not change it.
Red sent one every 10 minutes regardless: 60 points for nothing.

## Probable cause (to measure)

The destination, not the spawn point: the AI judges the `Land` task towards Afrin impossible, or sees a known threat on the route from the start (a blue air defence near Afrin or on the way), which `EVADE_FIRE` does not cover.
The abort of the Menagh helicopter at 20:30:43 came 7 s before an Apache killed it: `ai abort mission` also means "under threat", so the Afrin aborts must be read with the blue units then near the route (Tacview, Aleppo → Afrin, 20:17–21:01 UTC).

## Measured in Tacview (2026-11-18)

In the server's recording, the three Afrin helicopters that took off flew **the very same track**, to the metre: up to about 65 m above Aleppo (452 m), a 2.6 km loop to the east, and down again 1 km west of Aleppo's centre after 3 minutes; the distance to Afrin never went below 47.9 km. The first did not climb above 12 m and crashed on the spot.
The Menagh helicopter, from the same spawn point, climbed to 643 m and flew straight at the zone at constant speed (passing 14.8 km from Afrin).
A threat met on the way would not give four identical tracks starting 16 s after the spawn: **the AI rejects the Afrin task itself at once**. Afrin is a town (a point in its centre) where Menagh is an airfield: the `Land` point in the town — the "nearest clearing" `veafAircraftSpawn` finds, or fails to find — is the first suspect. Log the landing point chosen, and check it is a clear, flat spot.

## To do

- Find the cause in game or in Tacview, then fix it (route, landing point, threat reaction option such as `NO_REACTION`), with the measurement in `known-limitations.yaml` if it is a DCS behaviour.
- **Red remembers what fails**: after N failures on the same route (helicopter or assault convoy, see ticket 05), it does not send that order again for a while, or tries another source or target. Reco: 2 failures, then 1 hour.

## Done when

A helicopter sent to Afrin from Aleppo reaches it in the next evening's check, or red stops sending it after the second failure; a test covers the memory of failures.

## Done

- The landing point, the first suspect: a supply helicopter is now sent to `veafCampaignOps.landingSpot` — an airfield zone's field as before (Menagh worked), any other zone the clear spot nearest its centre within 60 % of its radius (`veaf.findSpawnPoint`, 30 m of clearance, the Mi-8's), else the centre. `dcs.log` says where: `supply helicopters land in [Afrin] at x=… z=…, N m from its centre`, or that no clear spot was found.
  Before, the named point was the zone's centre and `veafAircraftSpawn`'s own search looked only 300 m around it; in a town it found nothing and the `Land` task went to the centre among the buildings.
- The cause is not proven: no DCS here. If the four identical tracks come back with a clear landing spot, the next suspect is the threat reaction (`NO_REACTION`); the in-game check below tells.
- Red remembers what fails (reco: 2 failures, then 1 hour), `route_failures` / `route_failure_seconds`: a supply helicopter landed away, timed out or gone, and an assault convoy retired on `convoy_timeout` (ticket 05), count against `kind side target`; two in a row and the side sends none of that kind there for an hour (`supplyTarget`, `attackTarget`, the planned assaults); a helicopter that lands in its zone clears the count, the zone taken by the other side meanwhile counts nothing.
- No `known-limitations.yaml` entry: the DCS behaviour is not measured yet.
- Tests: the landing spot of a town and of an airfield; two failures to a zone, then none sent there for an hour, the other side's memory apart.

## In-game check

`grep "land in \[Afrin\]\|supply helicopter" dcs.log`: the spot chosen for Afrin, and the next red Mi-8 for Afrin landing there ("captured" or "delivered"), or after two failures `red sends no helicopter to [Afrin] for 3600 s`. In Tacview, the helicopter's track goes towards Afrin, not the 2.6 km loop.
