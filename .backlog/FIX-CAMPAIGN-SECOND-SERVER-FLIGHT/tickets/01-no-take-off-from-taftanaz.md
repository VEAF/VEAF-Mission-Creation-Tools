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

## To do

- `canTakeOffFrom` (or the choice of the departure field) refuses a field an aeroplane cannot leave: from the runway length DCS gives (`Airbase:getRunways()`) against what the type needs, or from the airbase category (helipad, FARP); helicopters keep using it.
- A flight still on the ground N minutes after its spawn is logged, and taken away with its price refunded, as a convoy is after `convoy_timeout`.
- A measured note in `known-limitations.yaml` if Taftanaz turns out to be a DCS trap (§9 item 8).

## Done when

A red flight is never sent from a field it cannot leave; a test covers the refusal; the in-game check (red air activity from Aleppo or Kuweires instead) is written for the next evening.
