# 04 — AI helicopters never reach Afrin, and red repeats what fails

Status: ⬜ ready
Type: fix

## Found

Four red supply helicopters sent from Aleppo to capture Afrin (20:17, 20:27, 20:47, 20:57): each made `ai abort mission` **16 s after its engine startup**; the first crashed on the ground without taking off (`crash` and `pilot dead`, no `hit`, CSAR "Pilot hasn't taken off"), the three others took off and landed back 2 km from Aleppo 3 minutes later ("landed 47 km from it, 2 km from [Aleppo]").
The helicopters sent from the same field to Menagh did not abort at the start; one landed in Menagh after 18 minutes.
On 2026-11-16 already two Mi-8 for Afrin landed back at Aleppo; the `REACTION_ON_THREAT = EVADE_FIRE` set by #1293 did not change it.
Red sent one every 10 minutes regardless: 60 points for nothing.

## Probable cause (to measure)

The destination, not the spawn point: the AI judges the `Land` task towards Afrin impossible, or sees a known threat on the route from the start (a blue air defence near Afrin or on the way), which `EVADE_FIRE` does not cover.
The abort of the Menagh helicopter at 20:30:43 came 7 s before an Apache killed it: `ai abort mission` also means "under threat", so the Afrin aborts must be read with the blue units then near the route (Tacview, Aleppo → Afrin, 20:17–21:01 UTC).

## To do

- Find the cause in game or in Tacview, then fix it (route, landing point, threat reaction option such as `NO_REACTION`), with the measurement in `known-limitations.yaml` if it is a DCS behaviour.
- **Red remembers what fails**: after N failures on the same route (helicopter or assault convoy, see ticket 05), it does not send that order again for a while, or tries another source or target. Reco: 2 failures, then 1 hour.

## Done when

A helicopter sent to Afrin from Aleppo reaches it in the next evening's check, or red stops sending it after the second failure; a test covers the memory of failures.
