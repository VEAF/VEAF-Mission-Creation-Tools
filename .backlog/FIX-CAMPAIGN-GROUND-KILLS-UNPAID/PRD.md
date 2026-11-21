# FIX-CAMPAIGN-GROUND-KILLS-UNPAID — a player's ground kill pays nothing and counts nothing

Status: ⬜ ready

David, 2026-11-21, on the sitac's ranking of "Bouclier de l'Oronte": "le classement de la SITAC a l'air incomplet ; il manque des gens". It showed four pilots: RexAttaque 250, Paluche 90, griffin 0 with 3 deaths, Mitch 0 with 1 death.

## Measured (Campagne server, 2026-11-21, 20:17 to 22:20 UTC)

| Pilot | Kills (`type=kill` events in `dcs.log`) | `CREDITS <pilot>` lines | On the sitac's ranking |
|---|---|---|---|
| griffin (AH-64D) | 31 | none | 0 points, no kill |
| Ninja 1-1 \| Zip (A-10C) | 24 | none | absent |
| Mitch (A-10C) | 13 | none | 0 points |
| Paluche (F-16C) | 10 | none | 90 points (earlier evenings) |
| Angrydad54 (F-16C) | 8 | none | absent |
| RexAttaque (JF-17) | 8: aircraft and helicopters | 8 lines, 175 credits | 250 points |

Every personal credit of the evening came from air kills; the side's credits came from tasks and captures only.

## Cause (read in the code, to prove with a test)

1. `veafEventHandler.transformEvent` hands a kill's target over as `completeUnit(event.target)`: a data table filled from `Unit.getByName(<target name>)`, its coalition defaulting to `coalition.side.NEUTRAL` when the unit is not found (`veafEventHandler.lua`, `completeUnitFromName`, lines 43-128).
2. A ground vehicle destroyed is no longer found by name when `S_EVENT_KILL` reaches the handler; an aircraft shot down still is, while it falls.
3. `veafCampaign.readPlayerKill` (`veafCampaign.lua` around line 4323) returns nil for a neutral target, since 5b239856 (2026-11-15, "read kill events the way veafEventHandler hands them over"): neither `veafCampaignEconomy.count` nor `payKill` runs.

The initiator has the same data table, but `dcsInitiator` keeps the raw DCS object beside it (`veafEventHandler.lua` around line 206, with the measurement that a dead object still answers at the event's moment); the target has no such field.

## Consequences

- The players earn a small part of the credits the economy was designed for, since 2026-11-15.
- The ranking (`sitacStats`, FIX-CAMPAIGN-THIRD-SERVER-FLIGHT ticket 03) knows a pilot only once he has books: a pilot with no paid kill and no death is absent.
- The economy's tuning since 2026-11-16 (FIX-CAMPAIGN-ECONOMY-BALANCE) read gains that were wrong. Retune after two evenings with the fix.
- The kills of the past evenings cannot be paid back: the log does not say which kills the campaign would have counted. The campaign goes on from the next deployment.

## Decided

David, 2026-11-21: tickets 01 and 02; then ticket 03, the evening's summary lost when the last player disconnects, found the same night and added to this lot since it is the same books.

The integration branch is `feature/dynamic-campaign`: one branch and one pull request into it.

| # | Ticket |
|---|---|
| 01 | [A ground kill is read before its target is gone](tickets/01-read-the-target-at-the-kill.md) |
| 02 | [Every pilot who flew is on the ranking](tickets/02-every-pilot-on-the-ranking.md) |
| 03 | [The evening's summary is written when the last player disconnects](tickets/03-summary-when-the-last-player-disconnects.md) |
