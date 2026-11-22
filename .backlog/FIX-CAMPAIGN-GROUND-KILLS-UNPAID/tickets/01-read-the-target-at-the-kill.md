# 01 — A ground kill is read before its target is gone

Status: 🧑 waiting-human
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

## Done (2026-11-22)

- `veafEventHandler.transformEvent` hands the raw target as `dcsTarget`, beside the data table, with the reason in a comment.
- `veafCampaign.readPlayerKill`: when the data table says neutral or has no category, it asks `dcsTarget` (`getCoalition`, `getDesc().category`, each under `pcall`), then `veafCampaign.recordOf(<name>)`: the garrison index (its zone's owner, its recorded type), the assault convoys (by group name) and veafCampaignOps' flights and helicopters. A target neutral for all three stays ignored, as does a blue one.
- Found in review: when a zone's last unit has its death read before its kill, the zone turns neutral and drops its garrison first, so its owner and garrison no longer tell the unit's side or type. The garrison index now keeps both from the spawn (`side`, `type`); test `test_the_last_unit_of_a_zone_is_paid_when_its_death_came_first`, red without the fix.
- The other readers of `event.target`: `killStat` read a SAM or infantry from `Unit.getByName`, so a destroyed SAM was paid `kill_ground`. It now asks the raw object, then the recorded type through `Unit.getDescByName`. The Hunter reads `readPlayerKill` and is fixed with it; the structure count reads only the target's name, which still comes through; the tasks count air kills only; veafCampaignOps' flight log already read `dcsTarget` by name.
- Whether a dead ground unit's raw object still answers `getCoalition` at `S_EVENT_KILL` is not measured (no DCS run in this lot): written "to confirm" in the code and in `known-limitations.yaml` (`kill-target-gone-by-name`, `kind: dcs`); `docs/agents/dcs-runtime-traps.md` regenerated.
- Tests (`TestCampaignGroundKill`): a red vehicle gone by name counted and paid, its held share held, a SAM still a SAM, a garrison unit and a garrison SAM known only to the campaign's index, an assault convoy known only to its record, the Hunter counting it, an air kill still paid, a neutral target ignored, friendly fire ignored; `TestVeafEventHandlerKillTarget`: the raw target comes through.
