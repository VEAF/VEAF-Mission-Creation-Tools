# 03 — The campaign declares its SAM groups to Skynet

Status: ⬜ ready
Type: feature

## To do

- First, failing tests (Lua, with the Skynet helper mocked): every time the campaign spawns a SAM group — a zone's SAM group of ticket 02, a medium- or long-range battery, a shop upgrade (NASAMS, IRIS-T SLM, Rapier…), the units a delivery brings back to such a group — it calls `veafSkynet.integrateMissionSpawn(groupName)`; never for a garrison's main group, a convoy, a helicopter or an aircraft.
- One place does it, after the group exists (`veaf.addGroup` returned), so every spawn path goes through it; nothing when `veafSkynet` is absent or not initialized (`integrateMissionSpawn` already returns then).
- A group spawned again under its name (a redraw, a respawn after a delivery) is integrated again: check what Skynet does with the old element (`veafSkynet.removeVanishedSites`, `sweepVanishedSites`) and say it in the ticket.
- A zone captured by the other side: its SAM groups are destroyed with its garrison today; check Skynet drops them (vanished sites sweep) and the new owner's are integrated into its own network.
- Log one line per integration, so the in-game check can count them: `[CAMPAIGN SKYNET] [Hatay SAM] declared to blue iads`.
- Docs: CHANGELOG entry.

## Done when

Every campaign SAM group is in its side's Skynet network from its spawn to its death, and no other campaign group is; with tests.

## In-game check

On the Campagne server: a `[CAMPAIGN SKYNET]` line for each SAM group as its zone wakes; a red site going dark when a player fires an anti-radiation missile at it, and lighting up again.
