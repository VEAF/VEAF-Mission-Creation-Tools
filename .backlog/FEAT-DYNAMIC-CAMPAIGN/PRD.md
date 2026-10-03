# FEAT-DYNAMIC-CAMPAIGN — a Foothold-like persistent campaign, built on VMCT alone

Status: ⬜ ready

David, 2026-10-02/03: VEAF likes Foothold, but it is hard on our servers' performance, and his
experience points at Moose (many modules, nearly all active all the time, many loops). He wants a
dynamic campaign engine that gives Foothold's **player experience** without Moose, on VMCT only. This
is the `DYNAMIC-CAMPAIGN` row of the roadmap vision, and it carries the campaign half of `PERSISTENCE`.

The Foothold adoption chain (`convert-other --profile foothold`, `doc/mission-maker/FOOTHOLD.md`) stays
as it is: this is a separate product, not a replacement.

## What Foothold is, measured (VEAF-Foothold-Caucasus, Foothold 4.7.0, read 2026-10-02)

| Layer | Size | Role |
|---|---|---|
| `zoneCommander.lua` — the engine, shared by every map | 81 542 lines | `BattleCommander`, `ZoneCommander`, `GroupCommander`, `LogisticCommander`, `Director`, `MissionCommander`, `EventCommander`… |
| `MA_Setup_CA.lua` — the campaign data, **hand-written per map** | 7 386 lines | ~90 zones, 134 `addConnection`, hundreds of `GroupCommander` written one by one, shop, events |
| the `.miz` | 1 185 trigger zones, 927 groups of which **448 late-activated templates**, 362 statics, 34 dynamic slots | what the engine looks up by name |

The loop: zones form a graph, each has a side (0/1/2), a size and a garrison list per side. An owned
zone is reinforced over time; when its whole garrison is destroyed it turns **neutral**; it is captured by
a delivery landed in it (AI helicopter or convoy, or players' troops and crates), and the new side's
garrison appears. AI sorties run between connected zones (supply, CAP, CAS, SEAD, convoys, artillery).
State is saved every 60 s under `Saved Games\Missions\Saves`.

**Moose:** 1 664 lines of the engine touch it (2 %), 226 distinct methods — mostly utilities, plus the
OPS layer (`AUFTRAG`/`FLIGHTGROUP`, one state machine per AI flight), `MANTIS` over the whole red air
defence, eight `SET_*:FilterStart()`, and Foothold's CTLD, which **is** Moose's CTLD. Whether Moose is
what costs the frames was **not measured** (David, 2026-10-03: a profiling evening is not for now); the
engine below is designed against every candidate cause anyway, and ticket 07 measures the result.

**Why not a Foothold fork without Moose:** upstream has no licence (`license: null`), and every weekly
release rewrites thousands of engine lines (+6 162/−2 311 on 2026-09-04, +4 433/−624 on 2026-09-19;
the whole file was deleted and re-added in August). A fork would freeze on one version within weeks.

## What VMCT changes about it

Foothold's cost to the author is the data: 7 400 lines and ~1 200 hand-placed zones per map. Here:

- the campaign is **declared** in a `campaign.yaml` sidecar (ADR 0016's model): zones by airfield name,
  named point or coordinates, a size class, a starting side, the connections;
- the **build** generates the trigger zones, the dynamic slots and a Lua data table — nothing placed by
  hand in the editor;
- garrisons come from the VEAF group database, **drawn at random per size class** (so many SAM / SHORAD /
  AAA / armour / infantry, Foothold's `RandomUpgradeTemplates` idea), filtered by `mission.era`, with an
  optional explicit list per zone — no template groups in the `.miz`;
- AI sorties are **derived from the graph**, not declared one by one.

## Player experience the lot must deliver (the "viable campaign")

1. The F10 map shows every zone coloured by owner, and the connections between them.
2. A radio menu lists the zones with their state (owner, garrison strength, under capture).
3. Destroying a zone's whole garrison turns it neutral.
4. A neutral zone is captured by **any ground presence of one side** held there for a while, as in
   Foothold: an AI convoy, troops or vehicles unloaded with CTLD 2, a CTLD 2 crate, a landed AI supply
   helicopter, a player's ground vehicle; the new owner's garrison then appears.
5. Player slots exist only at airfields/FARPs their side owns.
6. The enemy counter-attacks and resupplies along the connections, both sides.
7. The campaign survives a server restart.
8. It ends: one side holds every zone (or every zone flagged `key`), it is announced, and the state can be
   reset.

## Performance is a requirement, not a tuning pass

Designed against every candidate cause named above, whatever ticket 07 finds:

- **Dormant zones**: away from players a zone is a row in a table (composition, losses); its units are
  spawned when a player approaches and removed when none is left near, losses kept.
- **One loop**, processing a few zones per pass, instead of one timer per object.
- **DCS events** (dead, hit, land) instead of periodic scans of all units.
- **A cap** on materialized groups, on simultaneous AI sorties, and on ground convoys in particular.
- **Work counters** (zones processed, groups materialized, spawns, events) readable by admins.

The caps are **settings with conservative defaults**. They are not measured up front (David, 2026-10-03):
a workstation says nothing about what our servers hold, so the work is done first and the limits are tuned
after it has run on a server (ticket 07).

## Facts established for the design (measured 2026-10-03 on dcs.veaf.org)

- `MissionScripting.lua` of the production install sanitizes `os` and `loadlib` only: **`io`, `lfs`,
  `require` and `package` are available to missions**. Persistence needs no server change. Without `os`
  the mission side has **no wall clock** (`timer.getTime` is simulation time, frozen while Lua runs): the
  module can count its work, not time it.
- Foothold already persists there: `FootHold_CA_v0.3.lua` (170 kB) on foothold1, saved 2026-09-29.
- DCSServerBot keeps a per-minute FPS series per server in its database (`perfmon`, plugin
  `serverstats` / service `monitoring`); its own log only shows two hours of it. Not read: it needs the
  database password. DCSServerBot also ships a `profiler` plugin (sample / chrome / callgrind) driven by
  `/profiler start|stop` — apparently not in `opt_plugins` (to confirm). Both serve ticket 07.
- CTLD 2 publishes `OnTroopsDeployed`, `OnCrateUnpacked`, `OnFOBDeployed`, `OnLogisticZoneUpdated`
  through its `EventDispatcher` (`src/scripts/community/CTLD.lua`): capture subscribes, CTLD is untouched.

## Out of scope

Shop, economy and budget, ranks, Foothold's events and director, the player task board, JTAC, on-demand
tankers. **MCP actions and the prompt** (`create_campaign`, `add_campaign_zone`, `connect_zones`, a
composite from a theatre description, the authoring skill) are the **next lot**, opened once the
`campaign.yaml` format has survived this one.

## Related

- `FEAT-CTLD-AIRBASE-LOGISTICS` — airfield logistic zones that follow the owner: a capture must flip them.
- `FEAT-SCENERY-AWARE-SPAWN` (archived) — `veaf.findSpawnPoint`, the placement this lot reuses.
- Roadmap §4 `PERSISTENCE` — only the campaign's own state is persisted here, not every VEAF module.

## Tickets

| # | ticket | status |
|---|---|---|
| 01 | [`campaign.yaml`, validation and build generation](tickets/01-campaign-yaml-and-build.md) | ⬜ |
| 02 | [Runtime: zones, garrisons, dormancy, F10, radio](tickets/02-runtime-zones.md) | ⬜ |
| 03 | [Capture: neutral zones, any ground presence, airbase ownership and slots](tickets/03-capture.md) | ⬜ |
| 04 | [AI sorties derived from the graph](tickets/04-ai-sorties.md) | ⬜ |
| 05 | [Persistence, victory and reset](tickets/05-persistence-victory-reset.md) | ⬜ |
| 06 | [Documentation and an example campaign](tickets/06-doc-and-example.md) | ⬜ |
| 07 | [Measure it against Foothold, then tune the caps](tickets/07-measure-against-foothold.md) | ⬜ |
