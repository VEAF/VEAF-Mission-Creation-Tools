# FEAT-MULTI-MISSION-CAMPAIGN — a campaign flown mission after mission, each one built from what the last one left

Status: ⬜ ready

David, 2026-10-06: he wants a campaign for his VEAF friends that evolves as they fly it.
A starting situation with strategic objectives reachable in a few missions (configurable, 10 by default); Claude builds the first mission from it, complete, with the campaign's strategic situation added to the usual briefing; the squadron flies it; the result of the flight is read back and updates the strategic situation; the next mission starts from it — a bridge destroyed starts destroyed, a base freed or captured is ours — and the loop goes on.

This is an **episodic** campaign, in the spirit of DCS Liberation: each mission is a bounded flying session, and the campaign moves between missions.
It is not the persistent server mission of [`FEAT-DYNAMIC-CAMPAIGN`](../FEAT-DYNAMIC-CAMPAIGN/PRD.md), which is paused until this lot is done and will then be built on its bricks (David, 2026-10-06: "faire ça en premier, puis la campagne dynamique en utilisant les briques qu'on a construites").

## The loop

| step | who | how |
|---|---|---|
| starting situation, objectives, mission count | Claude with David | a campaign folder: `campaign.yaml` (zones, graph, sides, objectives) and the campaign state that evolves |
| build mission N | the tools, then Claude | the tools apply the state to the `.miz` (owner of every base, garrisons with their losses, destroyed scenery, stocks); Claude designs the mission on top — objectives, packages, briefing — through the MCP |
| fly | the squadron | the mission writes its **state file** during the flight (every N seconds) and at mission end |
| state file → campaign state N+1 | the tools | a deterministic command merges the state file into the campaign state |
| the enemy's turn | the tools, then Claude | fixed rules keep the books (repairs, reinforcements, logistics output); Claude decides where the enemy puts its effort and what the next mission asks, and writes it into the briefing |

## Decisions (David, 2026-10-06)

1. **The flight's result comes from a file the mission writes itself** (`io`/`lfs`, measured available on the production install 2026-10-03), during the flight and at its end — not from the `.trk` (a replay of inputs, unreadable without DCS) nor from Tacview (which does not know our zones and garrisons; usable later as a cross-check).
   A server that crashes mid-mission loses at most one write interval.
   On dcs.veaf.org Claude fetches the file over SSH.
2. **Stocks are kept**, so that the strategic side is real: munitions, aircraft and ground units.
   Destroying an enemy logistics node means fewer tanks facing us later; making a SAM network fire 90 % of its missiles makes it less aggressive afterwards.
   Stocks are written into the state file during the flight like the rest, not only read at the end.
3. **The enemy's turn is shared**: fixed rules for the bookkeeping, Claude for the intent and the story.
   Claude acting **live** during a flight (spawning, destroying, moving convoys, radio messages through the bridge) is a lot of its own: [`FEAT-LIVE-GAME-MASTER`](../FEAT-LIVE-GAME-MASTER/PRD.md).
4. **Capture happens live**, with the ground-presence rule designed for `FEAT-DYNAMIC-CAMPAIGN` (its former ticket 03 moves here): a base freed during the flight is recorded as captured in the state file.

## Bricks shared with FEAT-DYNAMIC-CAMPAIGN

Built here, reused there; each ticket below says which it is.

| brick | here | in FEAT-DYNAMIC-CAMPAIGN |
|---|---|---|
| `campaign.yaml` format (zones, graph, sides, size classes) | ✔ | reused as is |
| garrisons drawn once with `veafCasMission`'s generators, the drawn composition recorded in the state, spawned at run time from it with its losses | ✔ | reused, dormancy added on top |
| live capture by ground presence | ✔ | reused |
| F10 drawing (zones by owner, connections) and the situation radio menu | ✔ | reused |
| the runtime state writer (`io`/`lfs`) | state file of one flight | periodic save of the persistent mission |
| stocks (warehouses, ground reserve, SAM missiles) | ✔ | reusable |
| destroyed scenery replayed at start | ✔ | reusable |
| between-mission rules, strategic briefing, MCP actions | ✔ | not applicable |

## A premise of the first design that did not hold (measured 2026-10-06)

`FEAT-DYNAMIC-CAMPAIGN` planned to draw garrisons "from the VEAF group database filtered by era", by category (SAM / SHORAD / AAA / armour / infantry).
The 115 groups of `veaf-units.yaml` carry **no era, no role and no side**: they are aliases to place, not a catalogue to sort.
What does draw by **side × era × level 0–5** is `veafCasMission.lua`, whose tables are hand-written on purpose (FIX-PLATOON-UNITS, #296): `generateAirDefenseGroup`, `generateLongRangeAirDefenseGroup`, `generateArmorPlatoon`, `generateInfantryGroup`, `generateTransportCompany`.
So a size class is a set of parameters of those generators (`size`, `defense`, `armor`, an optional long-range SAM), and an explicit `garrison` list of aliases stays possible per zone.

## Out of scope

- Claude acting live during a flight — `FEAT-LIVE-GAME-MASTER`.
- The persistent server mission, AI sorties derived from the graph, dormant zones and their caps — `FEAT-DYNAMIC-CAMPAIGN`.
- Pilots (lives, ranks), an economy with a budget and purchases, a shop.

## Related

- `FEAT-CTLD-AIRBASE-LOGISTICS` (done) follows `Airbase:getCoalition()`: an airfield whose owner changes gets or loses its CTLD logistics without coordination, after its own two minutes of presence (class B).
- `FEAT-OBJECTIVE-MISSION-PROMPT` (done): how Claude already builds a complete mission; the campaign's missions are built the same way, from the state.
- `warehouses_injector`, `FIX-WAREHOUSES-INCREMENTAL`, `FIX-WAREHOUSES-LIST-FORM` (done): the build side of the warehouses that ticket 06 fills from the state.
- `scenery-death-events-in-dcs` (measured): a scenery object's death event has `event.pos` nil and `getName()` returning its numeric id.

## Tickets

| # | ticket | status |
|---|---|---|
| 01 | [Campaign folder: `campaign.yaml`, campaign state, validation](tickets/01-campaign-folder.md) | ⬜ |
| 02 | [Garrisons: drawn once, recorded, spawned from the state](tickets/02-garrisons.md) | ⬜ |
| 03 | [Runtime: F10 map and situation menu](tickets/03-map-and-menu.md) | ⬜ |
| 04 | [Live capture by ground presence](tickets/04-live-capture.md) | ⬜ |
| 05 | [The state file written by the mission](tickets/05-state-file.md) | ⬜ |
| 06 | [Stocks: warehouses, ground reserve, SAM missiles](tickets/06-stocks.md) | ⬜ |
| 07 | [Destroyed scenery replayed at start](tickets/07-scenery.md) | ⬜ |
| 08 | [Between missions: merge the state file, the enemy's turn, victory](tickets/08-between-missions.md) | ⬜ |
| 09 | [Build the next mission from the state, with its strategic briefing](tickets/09-build-next-mission.md) | ⬜ |
| 10 | [Documentation and an example campaign](tickets/10-doc-and-example.md) | ⬜ |
| 11 | [Two missions flown end to end](tickets/11-two-missions-flown.md) | ⬜ |
