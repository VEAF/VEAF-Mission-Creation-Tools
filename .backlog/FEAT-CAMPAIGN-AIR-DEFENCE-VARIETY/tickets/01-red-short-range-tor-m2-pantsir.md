# 01 — Red's short range draws the Tor M2 and the Pantsir

Status: ⬜ ready
Type: feature

## To do

- In the modern era, red's generated air defence of level 4 and 5 (`generateAirDefenseGroup-RED-4`, `-5` in `veaf-units.yaml`, or a `-MODERN-` variant if the other eras must not get them) can draw a `CHAP_TorM2` and a `CHAP_PantsirS1` among its short-range choices, next to the `Tor 9A331`, the Tunguska and the SA-8; the mix stays about as strong (a Pantsir replaces a Tunguska, it does not add one).
- The escorts of `veafCasMission.lua` that draw a Tor or a Tunguska (lines 640-730) draw the Tor M2 and the Pantsir too, in the modern era.
- `veafCasMission.ESCORT_TYPES_REPLACED_BY_ERA`: a cold war or WW2 mission never gets them (the Tor M2 entered service in 2009, the Pantsir S1 in 2012); add the swaps (Tor M2 → `Osa 9A33 ln`, Pantsir → `ZSU-23-4 Shilka`) the way the Tor and the Tunguska are swapped.
- The pilots' names for them: `air_defence_names.py` (`_VEHICLES`: "Tor M2", "Pantsir S1") so the theatre dossier and the briefings name them, and the sitac if it lists types.
- Skynet: check that `skynet-iads-compiled.lua` knows `CHAP_TorM2` and `CHAP_PantsirS1` as point defences (the campaign's IADS treats an unknown type as a plain unit); say what was found in the code comment.
- Measure, as the 2026-10-06 measurement of `models.py` did, 40 draws of a modern airfield zone: how often a Tor M2 or a Pantsir comes out; write it in the comment over the table.
- Tests: the enumerated sweep of the era tables (FIX-PLATOON-UNITS) covers the new types; a cold war draw never gives them.

## Done when

In a modern campaign, a red airfield zone draws a Tor M2 or a Pantsir S1 in a fair share of draws, and a cold war one never does; with tests.

## In-game check

On the Campagne server after a rebuild, the `[CAMPAIGN AIRDEF]` lines show `CHAP_TorM2` or `CHAP_PantsirS1` in at least one red zone that was regenerated (a zone retaken by red, or a new campaign).
