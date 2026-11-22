# 02 — An order is checked 30 s later

Status: ⬜ ready
Type: fix

## To do

- After `closeIn` (and every other `veaf.goRoute` the convoy handler gives in a fight or a retreat), check 20 to 30 s later that the convoy moved (a group starts 2 to 4 s after its order, measured by dcs-cartographie, 2026-11): its average position moved more than a margin, or one vehicle is above `HALTED_SPEED`.
- Not moved: the order is counted as failed at once (FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT counts the pushes that move nothing; this check feeds the same count instead of waiting for the next push two minutes later), and the next attempt takes another aim (ticket 01) rather than the same one.
- A check never re-sends an order faster than every few seconds (orders every 2 s or less freeze a group).
- An order given in the frame a group is created is lost (measured 3 out of 3): find whether `veafGroundAI` or the campaign gives a `goRoute` right after an `addGroup` (`mergeIfClose`, a respawn, a convoy's spawn); if so, delay it 5 s. Routes inside the `addGroup` definition were not measured: leave them and say so.
- Tests: a convoy that moved is not counted; one that did not is counted after the check's delay and tries another aim; no `goRoute` within 5 s of its group's creation.

## Done when

A failed order is known within 30 s and the next attempt takes another way; with tests.

## In-game check

`dcs.log` on the Campagne server: a "closing in" line followed, 30 s later, either by the convoy moving or by a line saying the order moved nothing and another aim is taken.
