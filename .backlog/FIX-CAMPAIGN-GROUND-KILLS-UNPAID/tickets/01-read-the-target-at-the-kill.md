# 01 — A ground kill is read before its target is gone

Status: ⬜ ready
Type: fix

## To do

- First, a failing test (TDD) that reproduces the evening: a player kills a red ground unit that `Unit.getByName` no longer finds; today the kill is neither counted nor paid.
- `veafEventHandler.transformEvent`: keep the raw DCS target beside the data table, as `dcsInitiator` is kept (`dcsTarget = event.target`), with a comment saying why.
- `veafCampaign.readPlayerKill`: when the data table's coalition is neutral or its category nil, ask the raw object (`getCoalition`, `getDesc().category`, each under `pcall`); if it no longer answers either, find the side from the campaign's own records (`veafCampaign.unitIndex[<name>]` gives the garrison's zone, so its owner; a campaign convoy or flight by its group). A target that is truly neutral (a neutral country's unit) stays ignored.
- Check every other reader of `event.target` in the campaign modules (`git grep -n "event.target" src/scripts/veaf/veafCampaign*.lua`): the same default may hide the same failure (the Hunter, the tasks' kill counts, the structure count); fix what reads a coalition or a category the same way.
- Measure in game if possible, else write "to confirm" in the comment: whether a dead ground unit's raw object still answers `getCoalition` at `S_EVENT_KILL`, as a dead scenery object answers `getPosition` (measured 2026-08-28).
- `known-limitations.yaml` (`kind: dcs`, with the date): a ground unit destroyed is no longer found by `Unit.getByName` when its `S_EVENT_KILL` arrives; regenerate `docs/agents/dcs-runtime-traps.md`.
- Tests: a ground kill counted (`Ground Units`, `Infantry`, `SAM`…) and paid with its held share; the same when only the campaign's index knows the side; an air kill still paid; a neutral target ignored; a blue target (friendly fire) ignored.

## Done when

A player's kill of a red ground unit is counted and paid, whether or not the unit can still be found by name; with tests.

## In-game check

On the Campagne server after a redeploy, a player destroys a red vehicle: `dcs.log` shows `CREDITS <pilot> +<amount> (kill_held)`, and after landing the held part; the sitac's ranking shows the kill under its category.
