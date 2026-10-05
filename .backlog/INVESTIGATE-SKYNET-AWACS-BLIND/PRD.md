# INVESTIGATE-SKYNET-AWACS-BLIND — three red A-50s covering sixteen SAM sites, and not one contact

Status: ✅ done — closed 2026-10-05 as not a defect (see [Outcome](#outcome))

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

## Findings, 2026-10-05

### The evidence that survives

The `dcs.log` of 2026-09-17 is gone: the server keeps only the current logs, and the transcripts of the session that measured it no longer exist.
So the table above can no longer be re-read, and neither can the contacts' positions.
The mission survives on dcs.veaf.org, as uploaded, under `Saved Games/DCS.missions/PourLeServeurPrivé/The_Reaper/OpenTraining/.dcssb/VEAF_OpenTraining_Caucasus_v6_20260917_debug_skynet_1705.miz.orig`.

| group | late activation | start | orbit (x, y, m) | options at WP1 |
|---|---|---|---|---|
| `AWACS - AirQuake` | no | 0 | (83 288, −203 200) → (82 632, −271 282), 7 925 m | AWACS, unlimited fuel |
| `A2-Overlordsky-1` | no | 0 | (−30 655, 855 923) → (13 812, 756 261), 7 925 m | AWACS, unlimited fuel, reaction on threat = 2, ECM = 2 |
| `A2-Overlordsky-2` | no | 0 | (105 227, 312 353) → (106 278, 391 390), 7 925 m | same as Overlordsky-1 |

No late activation, no radar option: they fly from t = 0 with their radar on.

### Measured in game (DAVID-BUREAU, `develop` at `f0b54231`)

Mission `D:\dev\_VEAF\tmp\dcs-session-2026-10-05-awacs\Skynet-awacs-blind_20261005.miz`: a red A-50 in a race-track at 26 000 ft, a red 55G6, a blue KC-135 82 km from the A-50, and, spawned at runtime, a blue E-3A, a C-130 and two more KC-135s. Read through the fiddle hook with `probe-awacs.lua` and `probe3.lua` in the same folder.

| reading | value |
|---|---|
| A-50 sensor `Shmel`, `detectionDistanceAir` (all four hemispheres/aspects) | **204 462 m** |
| 55G6 sensor, same | 267 496 m |
| range Skynet stores for the A-50 (`searchRadars[1].maximumRange`) | 204 462 m — read correctly |
| A-50 `getDetectedTargets(Controller.Detection.RADAR)`, t = 239 s | E-3A, C-130, second KC-135 |
| Skynet's own `getDetectedTargets()` on the A-50 element, t = 239 s | **3** |
| same, t = 269 s | the first KC-135 too — 5 in all |

So an A-50 enrolled by the helper does detect by radar, Skynet does keep its contacts, and the five functions on that path — `SkynetIADSAWACSRadar:setupElements`, `SkynetIADSAbstractRadarElement:getDetectedTargets` and `:isTargetInRange`, `SkynetIADSSAMSearchRadar:setupRangeData` and `:isInRange` — are byte-identical between the version that ran on 2026-09-17 (vendored at `bcce928c`) and today's.
**Hypotheses 1 and 3 are refuted by measurement.**

Two traps met on the way, recorded so the next reading does not fall into them:

- **The `RADAR` flag of a contact comes and goes.** The first KC-135 was in the A-50's list from t = 6 s, but flagged `DLINK` only in every reading up to t = 239 s, and `RADAR` at t = 269 s. Read at t = 6 and t = 78 alone, it looked like "an AWACS only reports datalink contacts", which is false: one reading is not a measurement of a flag.
- **The 55G6 saw only the E-3A**, not the C-130 nor the KC-135s at 60 km. Not explained, and not needed here: it is the comparison radar, not the subject.

### What this does to the reasoning above

**The inference "at least 579 km" written earlier the same day was wrong.**
It rested on the table's "each lists 16 SAM sites", which cannot hold for `AWACS - AirQuake`: with a range of 204 km it covers none of the 53 red SAM-eligible groups, all at 579 km or more.
The figure of 16 came from the lost log and can no longer be checked.

**Hypothesis 2 — geometry — fits every number left.** Minimum distance from each orbit to the blue airfields of Georgia, against the 204 km of the A-50 and the 267 km of the 55G6:

| radar | Batumi | Kobuleti | Senaki | Kutaisi | Tbilisi | Vaziani |
|---|---|---|---|---|---|---|
| A-50 `Overlordsky-1` | 394 | 351 | 314 | 302 | 287 | 291 |
| A-50 `Overlordsky-2` | 515 | 490 | 466 | 489 | 657 | 664 |
| A-50 `AirQuake` | 932 | 931 | 927 | 961 | 1 169 | 1 176 |
| 55G6 `-38` | 320 | 278 | **240** | **237** | 327 | 333 |
| 55G6 `-39` | 350 | 311 | 279 | **253** | **200** | **204** |
| 55G6 `-41` | **273** | **241** | **213** | **235** | 411 | 418 |

In bold, what lies inside the 55G6's 267 km. No blue airfield is within the reach of any A-50, and every 55G6 that held contacts reaches at least two of them.
That is consistent with the ground radars seeing the traffic around the Georgian bases while the A-50s, 290 km and more away, saw nothing — but it is consistent, not proven: the contacts' positions died with the log.

## Outcome

Closed as **not a defect**, on David's decision of 2026-10-05.
An A-50 enrolled by the helper detects by radar and feeds Skynet, measured in game, on a detection path byte-identical to the one that ran on 2026-09-17.
The geometry above accounts for The Reaper's three zeros, without proving it, since the contacts' positions were lost with the log; replaying his mission is the only way to complete the proof, and it was judged not worth it.

The one real behaviour the investigation found — a contact flagged `DLINK` only for minutes, which Skynet's `RADAR` filter drops — is recorded as the DCS trap `awacs-contact-radar-flag-comes-and-goes` in `known-limitations.yaml`.
Skynet is left unchanged: accepting `DLINK` would make an AWACS relay the coalition's whole datalink, a design decision for [VEAF/Skynet-IADS](https://github.com/VEAF/Skynet-IADS), not a fix.

## Definition of done

Either a named cause with the measurement behind it and a fix, or a documented "not a defect" with
the geometry that explains it. Do not close it on a plausible story: hypothesis 2 is the one that
looks most like an excuse and it is also the cheapest to check, so check it first.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**three red A-50s, 286 status cycles each, not one contact**, while the ground radars covering the same sixteen sites held up to 14 aircraft at the same instants. Found while diagnosing the report above, and it makes it worse: a covering EWR keeps a site non-autonomous whether or not it ever feeds it anything, so a blind AWACS holds sixteen batteries under network control and contributes nothing to waking them. Three hypotheses bounded — the once-read range filter, plain orbit geometry, the airborne wrapper — cheapest first
