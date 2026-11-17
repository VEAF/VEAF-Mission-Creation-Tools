# 08 — The garrison of a helicopter capture is not a token one

Status: ⬜ ready
Type: fix

## Found

Menagh taken by an Apache got **14 units**, Afrin taken by a Kiowa **24**.
A capture by landed helicopters alone is meant to leave a token garrison (`capturedBy(side, "helicopter")` → `drawGarrison({})`), but `sizeForDraw` only lowers the size class to `size 1, defense ≤ 1, armor ≤ 1` — which is already what an `outpost` is. On a small zone the "token" garrison is a full one; `composeGarrison` then draws 14 to 24 units at random.
Red's two helicopter captures of 2026-11-16 were in the same case.

## To do

- A real cap for a helicopter capture: a number of units or a value in points (reco: what one Mi-8 or UH-1 could carry — 4 to 6 infantry and no vehicle, a setting), whatever the zone's size class.
- The doc (`CAMPAIGN.md`, the player document) says what a helicopter capture leaves.

## Done when

A test shows an outpost and an airfield taken by helicopter both get the capped garrison.
