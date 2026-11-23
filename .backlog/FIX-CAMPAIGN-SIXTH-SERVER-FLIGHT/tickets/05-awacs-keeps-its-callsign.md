# 05 — A respawned AWACS keeps its callsign

Status: 🧑 waiting-human — the measure in DCS and the flight check
Type: fix

## Read

On the Campagne server, every radio call to the AWACS fails in DCS's speech: `Error in wMessage::buildSpeech(), event = wMsgLeaderPicture … Callname -1 not found for AWACS Magic-1 !` (also `wMsgLeaderVectorToNearestBandit`, `wMsgAWACSClean`), from 2026-11-21 22:00 UTC and all of 2026-11-22: the AWACS answers nothing. Red strikes shot it down several times (2026-11-22 14:49 and 21:40 UTC), and it was bought back from the shop, which calls `veafAssets.respawn` → `VeafGroupSpawn:new():forGroup(name):withRoute(veaf.getGroupRoute(name)):respawn()` (`veafAssets.lua` line 171, `veafDcsSpawner.lua` line 914). The spawner says it keeps "skill, payload, callsign" (line 625): the callsign reaches DCS wrong.

## To do

- First, reproduce in DCS through the bridge: respawn an AWACS of a Mission Editor group (`AWACS Magic`, task AWACS, callsign Magic) through `veafAssets.respawn`, ask it for a picture, and read the unit's callsign before and after (`unit:getCallsign()`, the group data). Write what the respawned group carries.
- Fix the respawn so an aircraft keeps its Mission Editor callsign (the callsign table of a western aircraft, `{ [1]=name index, [2]=flight, [3]=element, name = "Magic11" }`, and the number of an eastern one), with a failing test first. Check the tankers and every other `veafAssets.respawn` user get the same.
- Add the DCS behaviour to `known-limitations.yaml` if it surprises (a missing callsign raises no error at the spawn, only in the speech), and regenerate `docs/agents/dcs-runtime-traps.md`.
- Docs: CHANGELOG entry.

## Done when

An AWACS or tanker respawned by VEAF answers on the radio with its callsign; with tests and the measure in DCS.

## Flight check

On the Campagne server: buy the AWACS back after a loss, ask it for a picture, it answers "Magic".

## Done (2026-11-23)

**The cause**: `veafMissionDb`'s unit record (`unitRecord`) carried no `callsign`.
`VeafGroupSpawn:respawn()` (and `clone`, and `teleport` through `getCurrentGroupData`) builds its units from that record, so `veafAssets.respawn` submitted the AWACS with no callsign; DCS accepts it, and its speech fails at every call, `Callname -1 not found for AWACS Magic-1`.
The spawner's comment "skill, payload, callsign survives" had been wrong for the callsign since the record replaced MiST's database.

- `unitRecord` keeps `callsign = unitData.callsign` (a table for a western aircraft, a number for an eastern one), so every respawn, clone and teleport of a Mission Editor aircraft carries it: the AWACS and the tankers alike, and every other `veafAssets.respawn` user.
  A clone now carries the template's callsign too (DCS allows two aircraft with the same one); before, it had none.
- Test: `test_a_respawn_keeps_the_editor_callsign` (a western `Magic11` table and an eastern number), red before the fix.
- `known-limitations.yaml`: `aircraft-spawned-without-callsign-is-mute` (kind `dcs`, measured 2026-11-22); `docs/agents/dcs-runtime-traps.md` regenerated.
- **Not done**: the measure in DCS through the bridge. David's DCS was not running on 2026-11-23. To do on a test mission with `AWACS Magic`: `veafAssets.respawn("AWACS Magic")`, read `Group.getByName("AWACS Magic"):getUnit(1):getCallsign()` before and after (expected `Magic11` both times), and ask it for a picture.
