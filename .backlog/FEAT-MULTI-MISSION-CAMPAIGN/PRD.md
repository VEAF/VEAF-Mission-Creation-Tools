# FEAT-MULTI-MISSION-CAMPAIGN — a campaign flown mission after mission, each one built from what the last one left

Status: 🔄 in-progress

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
| 01 | [Campaign folder: `campaign.yaml`, campaign state, validation](tickets/01-campaign-folder.md) | ✅ |
| 02 | [Garrisons: drawn once, recorded, spawned from the state](tickets/02-garrisons.md) | ✅ |
| 03 | [Runtime: F10 map and situation menu](tickets/03-map-and-menu.md) | ✅ |
| 04 | [Live capture by ground presence](tickets/04-live-capture.md) | 🧑 |
| 05 | [The state file written by the mission](tickets/05-state-file.md) | 🧑 |
| 06 | [Stocks: warehouses, ground reserve, SAM missiles](tickets/06-stocks.md) | 🧑 |
| 07 | [Destroyed scenery replayed at start](tickets/07-scenery.md) | 🧑 |
| 08 | [Between missions: merge the state file, the enemy's turn, victory](tickets/08-between-missions.md) | ✅ |
| 09 | [Build the next mission from the state, with its strategic briefing](tickets/09-build-next-mission.md) | ✅ |
| 10 | [Documentation and an example campaign](tickets/10-doc-and-example.md) | 🧑 |
| 11 | [Two missions flown end to end](tickets/11-two-missions-flown.md) | 🧑 |

Tickets 04 to 07 and 11 wait for the game (item **R44** of [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md)); ticket 10 waits for the demo mission step.

## Progress, 2026-10-06 — everything that can be done without DCS

David could not start DCS, so the lot was built up to the in-game checks (David, 2026-10-06: "pars sur des trucs que tu peux faire").

### Decisions taken while building

1. **The state file is a Lua literal, the campaign state YAML, with one structure.**
   The mission writes `return { … }` with its own serializer, and `luadata` reads it back; a Python test runs the real serializer under the DCS mocks and reads its output, so the contract is checked across the two languages.
2. **The first mission's briefing speaks in intelligence terms** (ticket 02's open question).
   Drawing in Python would have meant a second copy of ~370 lines of `veafCasMission` tables plus `_addDefenseForGroups` and the era swaps, kept in step by hand — the opposite of #296.
   Mission 1 draws in game; its state file brings the real figures.
3. **`os` is sanitized on the VEAF servers** (measured 2026-10-03, `dcs-veaf-org-ssh-access`): the planned temporary-then-rename write would have left the state in the temporary for ever.
   Without `os` the mission writes the complete temporary, then the file itself; `campaign apply` falls back on the temporary when the file is cut short.
4. **A garrison is one DCS group per zone**, plus its long-range battery as a group of its own, drawn by `veafCasMission.generateCasGroup` unchanged — whose placement (`findPointInZone` + `settleGroup`) is reused rather than `veaf.findSpawnPoint`. `veafCasMission` was not touched, so CAS missions get exactly what they got.
5. **A garrison drawn after the start is paid from the reserve, unit by unit**; an empty reserve gives the smallest draw (size 1, no long-range battery). Mission 1's starting garrisons cost nothing.
   The reserve is therefore the mission's on the way back: the merge takes it from the state file.
6. **Repairs are counted in units, not groups** (`rules.repairs_per_mission`, 4 per side), each taken from the reserve category of its type; a repaired SAM comes back fully loaded.
7. **A capture still in progress at mission end is dropped**: the next mission starts with the zone as it was left.
8. **A CTLD 2 crate counts through `CTLDCrateManager`'s registry**, not its events: a static found in the zone counts when CTLD lists it as a crate. No state to keep in step with events.
9. **"Campaign units that took part are consumed" does not apply here**: an episodic campaign moves no unit of its own between zones. It comes back with the convoys of `FEAT-DYNAMIC-CAMPAIGN`.
10. **`at: { point: … }` is not supported**: a VEAF named point is a mission's, not a campaign's. A zone is on an airfield or at coordinates; the runtime resolves both (`Airbase:getPoint`, `coord.LLtoLO`), so the tools need no projection.
11. **`campaign next` copies a `template/` mission folder** rather than scaffolding one (which downloads from GitHub), and only refreshes a folder that exists: what Claude designed in it survives a second run.
12. **The strategic briefing is two text files** (`strategic-situation.fr.txt`, `.en.txt`) that Claude puts into the briefing it writes, rather than a variable substituted at build: the narrative half is Claude's anyway.

### Left for the game (R44)

- `Airbase.setCoalition` / `autoCapture(false)`: both exist in the scripting API schema and are called guarded; their effect on dynamic slots and warehouses is unmeasured.
- Warehouses: read in flight into the state file; writing them back at build waits for the reading to be measured.
- SAM missiles: recorded per unit (`missiles`); rendering at next start waits for the measurement.
- Scenery: recorded (through `veafMissionDb.destroyedScenery`); the replay method waits for the measurement.
- Recorded in `known-limitations.yaml` as `campaign-records-more-than-it-replays`.

### Left outside this repository

- The demo mission step (`VEAF/VEAF-Demo-Mission-v6`, CLAUDE.md §9 item 9): a campaign is a folder of missions, not a step of one mission; to decide with David whether the demo shows one campaign mission or a link to the example campaign.
- The Python coverage gate: measured locally at 83.8 % without PySide6, which the CI installs; raised once the CI has measured it.
