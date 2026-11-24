# 03 — The evening's summary is written when the last player disconnects

Status: ✅ done
Type: fix

## Found (Campagne server, 2026-11-21)

- The last player disconnected at 22:31:46 UTC from his slot; DCS paused the simulation in the same second (`ASYNCNET: simulation paused`, `onSimulationPause`).
- `veafCampaignEconomy.beat` writes the `ECONOMY SUMMARY` and `CREDITS SUMMARY` blocks at the first beat where nobody is in a slot (`veafCampaignEconomy.lua` around line 1590). A paused mission runs no beat: the evening's blocks were never written.
- The ledger and the session's gains stay open: the next evening's summary will cover both evenings.
- On 2026-11-21 at 16:49 the summary was written because the last player left his slot and stayed connected a minute, which is not the usual way to end an evening.

## To do

- Write the summary when the last player of the players' side leaves his unit or disconnects, from the event itself (`S_EVENT_PLAYER_LEAVE_UNIT`, a unit's pilot dead or ejected with nobody else in a slot, or the server's disconnect hook if the mission sees it), not at the next beat; keep the beat as the fallback.
- Once only: a summary said at the event is not said again at the next beat.
- Test: the last player leaves his unit and no beat follows: the blocks are written; a player still in a slot: nothing is written.

## Done when

After an evening that ends with the last player disconnecting from his slot, `dcs.log` holds the evening's `ECONOMY SUMMARY` and `CREDITS SUMMARY`; with tests.

## In-game check

At the end of the next evening, the last player quits the server straight from his cockpit: `grep "SUMMARY" dcs.log` shows the two blocks, timed at his departure.

## Done (2026-11-22)

- `veafCampaignEconomy.onPlayerLeave`, on `S_EVENT_PLAYER_LEAVE_UNIT`, `S_EVENT_PILOT_DEAD`, `S_EVENT_EJECTION` and `S_EVENT_CRASH` (none of them a delayed callback in veafEventHandler, so it runs in the event's frame): when a session is open and no player is left in a slot of either side, the leaving unit aside, it writes `summarizeSession("the last player left his slot")`. A death, an ejection or a crash counts only when the unit says it carries a player.
- Once only: `summarizeSession` closes the gains and the ledger, so the next beat has nothing to say. The beat stays the fallback.
- Whether DCS delivers `S_EVENT_PLAYER_LEAVE_UNIT` before it pauses the mission when the last player quits the server is to confirm in game (ticket's in-game check).
- Tests (`TestCampaignEvening`): the last player leaving writes both blocks with no beat after, and the next beat says nothing; a player still in a slot keeps the session open; the last pilot dead writes the summary too.
