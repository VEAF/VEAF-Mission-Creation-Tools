# 08 — The garrison of a helicopter capture is not a token one

Status: ✅ done
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

## Done

- A capture by landed helicopters alone draws `veafCampaign.composeHelicopterGarrison`: `dynamic.helicopter_garrison` soldiers (default 6, a Mi-8's or UH-1's worth), of the side's and era's infantry types, no vehicle, no long-range battery, whatever the zone's size class.
- The token garrison of a side that cannot pay a ground capture is unchanged (the smallest size class).
- Test: an outpost and an airfield, both declared with a heavy size class, get at most 6 soldiers and no vehicle.
- `PERSISTENT_CAMPAIGN.md` / `.en.md`: the setting and what a helicopter capture leaves.

## In-game check

The next zone taken by a helicopter (`zone [X]: garrison drawn, N unit(s)` in `dcs.log` right after `captured by`): N ≤ 6, all infantry.
