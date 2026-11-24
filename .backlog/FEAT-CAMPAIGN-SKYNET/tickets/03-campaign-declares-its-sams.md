# 03 — The campaign declares its SAM groups to Skynet

Status: ✅ done
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

## Done

- One place: `VeafCampaignZone:spawnGroup`, right after `veaf.addGroup`. Every garrison spawn goes through it — `spawnGarrison`, the wake queue (`continueSpawning`), a shop upgrade (`addUpgrade`), a delivery (`reinforce`), a capture's new garrison — and it is the campaign's only `veaf.addGroup`.
- `VeafCampaignZone:isSamGroup(group)`: never the main group `<zone> garrison`; yes for a name ending in `SAM` (the zone's SAM group, the long- and medium-range batteries, a Tor battery included) or for a group holding a missile launcher (`SAM LL`: the NASAMS, IRIS-T SLM, Patriot, Rapier and Hawk upgrades). Not an Avenger or Gepard upgrade, nor an infantry or armour one; convoys, helicopters and aircraft do not spawn through `spawnGroup`.
- The units a delivery brings back as a group of their own (`<group> +N`) are not declared: an air defence unit brought back respawns its whole group under its name, which is declared; a `+N` group holds only what is not air defence (a battery's lorry).
- `veafCampaign.declareToSkynet(groupName, side)` calls `veafSkynet.integrateMissionSpawn(groupName)` and logs `[CAMPAIGN SKYNET] [Hatay SAM] declared to blue iads` at info level, whatever `dynamic.debug`. Nothing while Skynet is not running (`veafSkynet.initialized` false, or no `veafSkynet`): a debug line only, since a campaign that turns Skynet off would otherwise log every SAM spawn.
- **A group spawned again under its name.** `veafSkynet.addGroupToNetwork` refuses a group whose name the network lists (`sam.dcsName == dcsGroupName`). The sweep (`sweepVanishedSites` → `removeVanishedSites`) drops a site whose DCS object is gone **unless DCS reported one of its units lost**: then it keeps the site as destroyed, Skynet's readout of a kill. A campaign SAM is spawned again under its name when its zone wakes again, and when a delivery brings an air defence unit back — the latter always after a loss. The old site would have held the name for the rest of the mission, and the new group would never have been integrated. So `declareToSkynet` first removes any site of that name from the side's network (`veafSkynet.removeSkynetElement`, then `rebuildRadarCoverage` as the sweep does), and its log line says `its old site replaced`. The cost: that destroyed site's line in Skynet's status readout goes with it.
- **A captured zone.** Its garrison dies to the last unit before the zone turns neutral, so its SAM sites stay in the old owner's network as destroyed, as Skynet means them to. The new owner's garrison is drawn under the same names and declared to **its** network; the removal looks only there, so the old owner's destroyed sites are left alone.
- Timing: Skynet starts `DelayForStartup` (1 s) into the mission; a persistent campaign's zones all start asleep, and the first wake comes at the first beat (`BEAT_SECONDS`, 10 s). So no SAM group spawns before the networks exist, and no garrison is on the map for `loadAllAtInit` to take.
- Tests (`TestVeafCampaignSkynet`, Skynet mocked): every SAM group declared and no other; an old site of the same name replaced and the coverage rebuilt; a zone of the other side declaring to its own network without touching the other; units a delivery brings back beside a group not declared; a lorry brought back beside a battery not declared (checked to fail without the guard); a SAM brought back by a delivery declared again; nothing while Skynet is not running, or absent.
