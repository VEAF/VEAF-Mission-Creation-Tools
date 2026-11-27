# 02 — An order is checked 30 s later

Status: ✅ done
Type: fix

## To do

- After `closeIn` (and every other `veaf.goRoute` the convoy handler gives in a fight or a retreat), check 20 to 30 s later that the convoy moved (a group starts 2 to 4 s after its order, measured by dcs-cartographie, 2026-11): its average position moved more than a margin, or one vehicle is above `HALTED_SPEED`.
- Not moved: the order is counted as failed at once (FIX-CAMPAIGN-CONVOY-STUCK-IN-CONTACT counts the pushes that move nothing; this check feeds the same count instead of waiting for the next push two minutes later), and the next attempt takes another aim (ticket 01) rather than the same one.
- A check never re-sends an order faster than every few seconds (orders every 2 s or less freeze a group).
- An order given in the frame a group is created is lost (measured 3 out of 3): find whether `veafGroundAI` or the campaign gives a `goRoute` right after an `addGroup` (`mergeIfClose`, a respawn, a convoy's spawn); if so, delay it 5 s. Routes inside the `addGroup` definition were not measured: leave them and say so.
- Tests: a convoy that moved is not counted; one that did not is counted after the check's delay and tries another aim; no `goRoute` within 5 s of its group's creation.

## Done when

A failed order is known within 30 s and the next attempt takes another way; with tests.

## Done

- `ConvoyUnitHandler:order` gives every route of the convoy handler (close in, press on, fight, fall back, drive on, retreat, resume, merge) and schedules `checkOrder` `ORDER_CHECK_DELAY` (25 s) later: the group moved when its centre moved more than `ORDER_MOVED_MARGIN` (20 m, estimated) or one vehicle is above `HALTED_SPEED`. Not moved: one log line ("the order given to … 25 s ago moved nothing"). A check that belongs to an older order of the group, or to a convoy holding, says nothing.
- A push (`closeIn`, `pressOn`) that moved nothing (`pushMovedNothing`): its aim goes to `failedAims`, which the next close in avoids by `FAILED_AIM_RADIUS` (100 m), and the push clock is wound back, so the next push comes at the next beat (3 s later, never faster) instead of two minutes later. That push counts in `pushMovesSomething`'s futile count as before (the convoy did not get closer): a convoy that cannot close in drives on after about a minute and a half instead of six. Nothing happens when a shot was fired or taken since the push, or another push came. `failedAims` is emptied by a new contact, a push that got closer, and the give-up.
- Orders right after a group's creation: `veafSpawn.spawnConvoy` gave its route in the frame it created the convoy (the campaign's assault convoys). It now gives it `CONVOY_FIRST_ORDER_DELAY_SECONDS` (5 s) later, unless the convoy was stopped meanwhile (in contact at once). The convoy handler notes the birth of the groups it creates (the split's unarmed group, the merge) and of a spawned convoy (`veafGroundAI.noteBirth`); `order` holds an order to such a group until `SPAWN_ORDER_DELAY` (5 s) has passed, the last order given winning. The routes passed inside the `addGroup` definition (the split, the merge) are left as they are: that case was not measured.
- Not done: `veafSpawnCore` (`_spawn group` with a destination) also gives a route in the frame of the spawn; it is outside the convoy handler and the campaign, left for a later lot.
- Tests: `test_veafGroundAI_convoy.lua` (an order that moves nothing said once, a driving convoy not said stuck, no route within 5 s of a group's creation, the split's and the merge's births noted, a push that moves nothing known at the check and retried toward another aim, the give-up in under two minutes, a push that moves the convoy not counted) and `test_veafSpawn.lua` (a spawned convoy's first route 5 s after its creation, none when it was stopped meanwhile).

## In-game check

`dcs.log` on the Campagne server: a "closing in" line followed, 30 s later, either by the convoy moving or by a line saying the order moved nothing and another aim is taken.
