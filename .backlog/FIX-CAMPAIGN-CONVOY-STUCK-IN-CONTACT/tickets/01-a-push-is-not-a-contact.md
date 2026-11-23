# 01 — A push that moves nothing is not a contact

Status: 🧑 waiting-human
Type: fix

## To do

- First, a failing test (TDD) that reproduces 2026-11-21: a convoy fighting, halted, pushed by `closeIn` and `pressOn` every cycle without moving and without a shot; at its retirement time `convoyMayLeave` says "in contact" for ever.
- Keep apart what the convoy did and what happened to it: a shot fired or received, or an enemy newly seen, is a contact; a push the convoy gives itself (`closeIn`, `pressOn`) is not. Record the pushes in their own field (for instance `lastPush`) so that `closeIn`'s stalemate clock still restarts, and `convoyMayLeave` reads only the real contact.
- A convoy whose pushes do not move it: after N pushes (a setting, with an estimated default written as such) with the distance to its enemy unchanged within a margin, it stops pushing and drives on to its objective, or stands down, as `standDown` does after a fight; log one line saying so ("convoy Mule: 3 pushes moved nothing, driving on").
- Check the "a player near" reason of `convoyMayLeave` on the 2026-11-20 case: a player who orbits a stuck convoy all evening keeps it too; say in the PR whether that is wanted (it is today, FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 07).
- `known-limitations.yaml` if the measurement shows a DCS behaviour (a vehicle given an off-road route onto an enemy 956 m away that does not move), with the date.
- Tests: the stuck convoy is retired at its time once its pushes are not contacts; a convoy that exchanged fire a minute ago stays; the give-up after N pushes that move nothing; a push that moves the convoy keeps pushing.

## Done when

A convoy that stands still and fires nothing is retired at its time, even while it keeps trying to close in; with tests.

## Done

- `veafGroundAI.lua`: a convoy keeps apart what it did and what happened to it. `lastSighting` (an enemy newly seen: not seen within `QUIET_DELAY`) and `lastFireExchanged` (a shot fired or taken, nothing else) are the contact; `lastPush` (the contact's start, `pressOn`, `closeIn`) restarts the watch's quiet and stalemate clocks and is no contact. `pressOn` recalls its out-of-sight enemies without counting them as seen.
- `pushMovesSomething`: before each push, a push that brought the convoy's centre less than `PUSH_PROGRESS_MARGIN` (50 m, estimated) closer to its enemy counts as futile; after `FUTILE_PUSHES` (3, estimated) in a row the convoy logs "convoy Mule: 3 pushes moved nothing, driving on", drives on (`resume`), and the enemies in sight it gave up on no longer start a fight by being seen (a shot from them still does).
- `veafCampaign.convoyMayLeave` reads `lastSighting` and `lastFireExchanged` only.
- "A player near" is kept as it is: a player within `wake_radius` keeps a convoy to retire in play (FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 07, never remove a convoy in front of the players). The 2026-11-20 case near Kilis was kept by a player; with the give-up, a convoy stuck there now drives on after six minutes of futile pushes instead of standing still in front of him, and leaves once he is gone.
- No `known-limitations.yaml` entry: why DCS did not move the vehicles (terrain, path) was not measured.
- Tests: `test_veafGroundAI_convoy.lua` (the 2026-11-21 reproduction, the give-up, a push that moves keeps pushing, a press on is no contact) and `test_veafCampaignPersistent.lua` (a convoy pushing without a shot is retired at its time; a newly seen enemy keeps it).

## In-game check

On the Campagne server, a red convoy halted near a blue zone without a shot: at its retirement time, `dcs.log` shows `assault convoy [...] retired`, not `stays: in contact`.
