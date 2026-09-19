# INVESTIGATE-SKYNET-AWACS-BLIND — three red A-50s covering sixteen SAM sites, and not one contact

Status: ⬜ ready

Origin: found while diagnosing The Reaper's report of 2026-09-17
(`VEAF_OpenTraining_Caucasus_v6_20260917_debug_skynet_1705.miz`, same `dcs.log`). Not what he
reported, and it makes his report worse.

## The measurement

Session of 19:12, 286 status cycles (24 minutes), red network, `debug_red` on:

| element | cycles | cycles with ≥1 contact | max contacts |
|---|---|---|---|
| `RED-AirQuake-1-1` (A-50) | 286 | **0** | 0 |
| `A2-Overlordsky-2-1` (A-50) | 286 | **0** | 0 |
| `Pilot #288` (A-50) | 286 | **0** | 0 |
| `[r]-54th Hawk Fighters#10263 / EWR 55G6 #1` | 106 | 14 | 14 |
| `-38` (Tall Rack) | 286 | 37 | 5 |
| `-41` (Tall Rack) | 164 | 15 | 6 |
| `-39` (Tall Rack) | 161 | 8 | 1 |

All three A-50s were `ACTIVE: true`, all three logged `GOING LIVE` at startup, and each lists
16 SAM sites under its coverage. The ground radars saw up to 14 aircraft at instants when the
airborne ones saw none.

## Why it matters beyond the oddity

An EWR that covers a site keeps that site **non-autonomous** — that is `setToCorrectAutonomousState`
— whether or not it ever feeds it a contact. So a blind AWACS holds sixteen batteries under network
control while contributing nothing to waking them. It is an amplifier of
the last line of defense (`FEAT-LAST-LINE-OF-DEFENSE` in [VEAF/Skynet-IADS](https://github.com/VEAF/Skynet-IADS)), not a duplicate of it.

## Nobody upstream can help — this is ours

Asked of Flogas on 2026-09-18: he has never seen it, and says it is pure VEAF. That fits the code.
**Skynet never enrols an AWACS on its own** — upstream expects a mission author to add one
explicitly. It is `veafSkynetIadsHelper.lua:1817` that makes every aircraft carrying the DCS `AWACS`
attribute eligible, automatically, for its coalition's network. So the situation this lot
investigates only exists in VEAF missions, and the investigation is entirely on us.

## Hypotheses to test, in order of cheapness

1. **The range filter.** `SkynetIADSAbstractRadarElement:getDetectedTargets` keeps only targets that
   pass the element's own `isTargetInRange`, which is built from a range read **once** by
   `setupRangeData` out of `getSensors()`. A zero or absurdly small reading discards everything the
   controller returns. Against it: `veafSkynet.checkRadarRange` logged no `RADAR RANGE ZERO` for any
   A-50 in that session, so the reading was not zero — but it does not tell us what it *was*. Cheap
   to settle: log the measured range for airborne elements, or read one live through the DCS bridge.
2. **Geometry.** The A-50s may simply have orbited far from the traffic for the whole session.
   Settle by reading their positions against the contacts the ground radars held at the same
   timestamps. If this is the answer, the lot closes as "no defect".
3. **The wrapper.** `SkynetIADSAWACSRadar` maintains its own coverage updates as the aircraft moves
   (`isUpdateOfAutonomousStateOfSAMSitesRequired`). If an airborne element's radar unit is wrapped
   differently from a ground one, the filter in 1 or the controller call could be reading the wrong
   object.

## Definition of done

Either a named cause with the measurement behind it and a fix, or a documented "not a defect" with
the geometry that explains it. Do not close it on a plausible story: hypothesis 2 is the one that
looks most like an excuse and it is also the cheapest to check, so check it first.
