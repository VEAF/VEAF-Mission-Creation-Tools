# FEAT-CAMPAIGN-SKYNET — the persistent campaign's SAM sites run under Skynet

Status: ⬜ ready

David, 2026-11-22: "il faudrait activer Skynet sur la mission de campagne". Asked while looking for why Hatay's Hawk does not fire (FIX-CAMPAIGN-FIFTH-SERVER-FLIGHT 02); Skynet is not that cause — it is not running in the campaign —, this lot is a feature of its own.

## Read (2026-11-22)

- The campaign mission's `mission.yaml` has `SKYNET: false` (`D:\dev\_VEAF\tmp\dynamic-syria\missions\mission-01\mission\mission.yaml`, line 284). The Campagne server's log has `VEAF-SKYNET … loaded` and never `initializing`; another VEAF mission on David's DCS logs `initializing Skynet in 1 seconds`.
- Turning it on alone would integrate nothing: `veafSkynet.loadAllAtInit` takes the groups on the map when Skynet starts, and the campaign spawns its garrisons later (each zone wakes in turn, `VeafCampaignZone:spawnGarrison`; deliveries, redraws and shop upgrades spawn more). `dynamic_spawn` is off by default.
- Skynet commands a whole group (`GroupIntegrationModes.Lenient` takes a group even with units it does not know). A blue level-5 garrison is one group of up to 74 units whose Hawk sits with its Gepard, Avenger, Stinger and armour (`veafCampaign.composeGarrison`, `generateAirDefenseGroup`, `veafCampaign.lua` line 797): under Skynet the whole garrison would go dark.
- The red medium- and long-range batteries and the shop upgrades (NASAMS, IRIS-T SLM, Rapier) are groups of their own already (`drawGarrison`, the `batteries` table, line 869).
- `veafSkynet.integrateMissionSpawn(groupName)` (`veafSkynetIadsHelper.lua` line 1241) integrates one spawned group into its coalition's network, deferred, and leaves it to the birth-event handler when the network integrates dynamic spawns; combat zones already call it (`veafCombatZone.lua` line 1945).
- `next_mission.py` already sets campaign modules in `mission.yaml` (`CAMPAIGN` line 267, `SUPPORT` with `enable_support_module` line 275).

## Decided

David, 2026-11-22, the three recommendations:

- **a. Both sides** under Skynet, as in the Open Trainings.
- **b. Each multi-unit SAM in a group of its own, and only those groups under Skynet.** The short-range weapons stay in the garrison's main group, left to DCS's AI. Saves already on the server are split at load, no redraw.
- **c. The campaign declares its SAM groups to Skynet itself**, with `veafSkynet.integrateMissionSpawn`, at every spawn of such a group.
- Out of the lot: no early-warning radar (EWR) added. Without one, a Skynet site keeps its own radar on; the behaviour stays close to today's except against anti-radiation missiles.

One branch and one pull request into `feature/dynamic-campaign`.

| # | Ticket |
|---|---|
| 01 | [Skynet on in the campaign mission](tickets/01-skynet-on-in-the-campaign.md) |
| 02 | [A garrison's SAM in a group of its own](tickets/02-garrison-sam-in-its-own-group.md) |
| 03 | [The campaign declares its SAM groups to Skynet](tickets/03-campaign-declares-its-sams.md) |
