# 01 — Red aircraft never take off from Taftanaz

Status: ⬜ ready
Type: fix

## Found

No red aeroplane spawned at Taftanaz took off all evening: the SEAD of 20:27, the CAPs of 20:35 and 20:42, then at 20:57 a second SEAD and the whole raid on Payas (MiG-29A ×2, MiG-27K ×4, Tu-22M3).
Each has an `engine startup` at Taftanaz and **no `takeoff`**; the raid's "waits at its hold: bomber 6 km away at 314 m" did not change for 30 minutes (314 m is the field's elevation).
At 21:05 three MiG-29A of three different CAPs, the oldest spawned 30 minutes earlier, made `ai abort mission` in the same millisecond: still there, still on the ground.
Meanwhile the Su-25 spawned "Parking Area Hot" at Aleppo took off in 3 minutes, and every Mi-8 took off.
About **880 points** of red's stock paid for aircraft that never flew.

## Probable cause (to measure)

Taftanaz is a helicopter base with a short strip; an aeroplane spawned "From Runway" there does not take off, or the flights pile up on the strip.
`veafCampaignOps.canTakeOffFrom` only asks whether the zone has an airbase and no enemy air defence covers it.
Check in Tacview (Taftanaz, 20:27–21:30 UTC) before writing the remedy.

## Measured in Tacview (2026-11-18)

The server's own recording (`Documents\Tacview\foothold2_server\Tacview-20261117-132513-DCS-Host-…txt.acmi`, positions readable; the clients' recordings scramble them) settles it:
- **every red aeroplane sent from Taftanaz spawned at the very same point**, 35.9735 N 36.7860 E, the two of a flight 9 m apart, and **moved 0 m** for its whole life, at 313 m (the ground): SEAD 20:27, CAP 20:35, CAP 20:42, SEAD ×2 + CAP + bomber 20:57 — 15 aircraft stacked on one spot;
- the first SEAD pair did not move either, when the spot was still free: the field itself, or that spawn point, does not let an aeroplane roll; every later flight then spawned onto the ones already stuck there;
- **DCS removes an aborted AI aircraft 3 minutes after its abort**: the MiG-29 #2 of three CAPs aborted at 21:05:41 and were removed at 21:08:41, the Tu-22M3 aborted at 21:29:53 and was removed at 21:32:53 — which `followRaid` then reported as "destroyed" (ticket 09).

So also: two flights must never spawn on the same point (check the spot is free, or space them), whatever the field.

## To do

- `canTakeOffFrom` (or the choice of the departure field) refuses a field an aeroplane cannot leave: from the runway length DCS gives (`Airbase:getRunways()`) against what the type needs, or from the airbase category (helipad, FARP); helicopters keep using it.
- A flight still on the ground N minutes after its spawn is logged, and taken away with its price refunded, as a convoy is after `convoy_timeout`.
- A measured note in `known-limitations.yaml` if Taftanaz turns out to be a DCS trap (§9 item 8).

## Done when

A red flight is never sent from a field it cannot leave; a test covers the refusal; the in-game check (red air activity from Aleppo or Kuweires instead) is written for the next evening.
