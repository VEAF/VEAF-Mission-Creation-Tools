# 04 — The escort stands beside its own FARP's props

Status: 🔄 in-progress — implemented, to see in game
Type: fix

R19 of 2026-10-03: on open ground the escort still moved, `occupancy probe=false` on its wanted spot.
The FARP's own tents, props and windsock are laid out first on the same bearing. The escort's search
now ignores statics named after its own FARP; the probe names what it found. Details in the
[PRD](../PRD.md).

## To see in game

A `-farp` on open ground: `FARP escort: bearing 0 requested, 0 used at 1x distance`, and — before the
fix is trusted — the debug line `isSpotOccupied: ignoring FARP … unit #N, part of this FARP`, which
confirms what used to block it. A `-farp` in a wood still moves out of the trees.
