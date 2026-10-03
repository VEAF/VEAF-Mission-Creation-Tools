# 04 — The escort stands beside its own FARP's props

Status: ✅ done — verified in game 2026-10-03
Type: fix

R19 of 2026-10-03: on open ground the escort still moved, `occupancy probe=false` on its wanted spot.
The FARP's own tents, props and windsock are laid out first on the same bearing. The escort's search
now ignores statics named after its own FARP; the probe names what it found. Details in the
[PRD](../PRD.md).

## To see in game

A `-farp` on open ground: `FARP escort: bearing 0 requested, 0 used at 1x distance`, and — before the
fix is trusted — the debug line `isSpotOccupied: ignoring FARP … unit #N, part of this FARP`, which
confirms what used to block it. A `-farp` in a wood still moves out of the trees.

## Seen in game (2026-10-03, second pass)

The probe now names what it found: on all four `-farp` the wanted spot was occupied by `FARP … unit
#10` (or `#9` beside the static FARP) — the FARP's own windsock or generator. With them ignored, open
ground, beside a static FARP and the deep-wood case all logged `FARP escort: bearing 0 requested, 0
used at 1x distance`.

It also showed a second defect, fixed in the same branch: in the wood case the escort **stayed in the
trees**. The cloud was empty (`0 cloud candidate(s)`), so the bearing walk decided, and it only asked
the occupancy probe. This morning's run had moved out of the trees by accident, the windsock blocking
bearing 0. The walk now also asks the small scenery probe. Re-run on the rebuilt mission: no free patch
at any of 24 bearings at 150, 225 or 300 m around that spot (measured), and the `-farp` was **refused**
— `no clear ground for its escort`, the first time the refusal case of FIX-PLACEMENT-IGNORES-SCENERY
ticket 04 has been reached in game.
