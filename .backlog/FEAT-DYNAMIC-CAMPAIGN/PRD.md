# FEAT-DYNAMIC-CAMPAIGN — a Foothold-like persistent campaign, built on VMCT alone

Status: 🧑 waiting-human — V1 merged into the integration branch `feature/dynamic-campaign` (#1276, 2026-11-15); waits for David's in-game check of the test mission, then ticket 10 on a server (David: the lot is not merged into `develop` piece by piece)

> **Paused 2026-10-06, resumed 2026-11-15** for the V1 of the table below.
> Paused 2026-10-06: David wants a multi-mission campaign first ([`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md)), then this persistent mission built on the bricks it leaves: the `campaign.yaml` format, garrisons drawn once and recorded, live capture, the F10 map and menu, the runtime state writer, stocks, scenery.
> When this lot is resumed, its tickets 01, 02 and 05 shrink to what those bricks do not cover (dormancy, caps, the periodic save's cadence), and ticket 03 is already done there.
> One premise below did not hold: the VEAF group database has no era, role or side to draw garrisons from; that lot draws them with `veafCasMission`'s generators instead.

## Decision of 2026-11-15: VMCT-native code, two modes, an MCP side

After the analysis of Foothold 6.5.3 ([`foothold-analysis.md`](foothold-analysis.md)), David ruled out removing Moose from Foothold (section 11 of the analysis: some 4 000 call sites, the whole logistics to rewrite on CTLD 2, a fork that diverges at every weekly release, for a gain never measured).
What is kept is the plan of this PRD, sharpened:

- **Foothold's features are taken over in VMCT's own code**, one or several modules, without Moose and without forking Foothold.
- **The dynamic mission runs in two modes**: standalone and persistent on a server, like Foothold; or as one mission inside a VMCT multi-mission campaign ([`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md)).
- **An MCP side** generates these missions, standalone or within a campaign.
- **The selection aims at a system that is interesting and fun to play, without Foothold's complexity**: which Foothold features to take is studied next, from the catalogue of the analysis (section 6).

### Feature selection (David, 2026-11-15)

Section numbers point to the detailed notes under [`foothold-analysis/`](foothold-analysis/).

| Version | What | Notes |
|---|---|---|
| V1 | The core: zones that change hands through a neutral state and a timed capture by ground presence; the F10 map with zones, connections and garrison state; a front that moves on its own (enemy counter-attacks, a zone reinforced by each supply delivery); slots that follow the bases; win, defeat, reset and a periodic save in standalone mode; dormancy of zones far from players | 01 §1–§13, §18; 02 |
| V1 | Enemy air: CAP over the front and CAS/SEAD strikes on blue zones, sorties derived from the graph with a simple target rule, scaled by the number of players (`veafOpposition`), built on the QRA and air-wave bricks; no Director | 03 §2–§5; 04 §2, §4 |
| V1 | Logistics: capture by CTLD 2 troops, and supply crates that reinforce or repair a friendly zone | 07 §7–§8 |
| V1 | **AI helicopters capture and resupply zones**, as in Foothold, rather than convoys only (David: convoys would be too slow); the DCS traps on scripted helicopter landings are known — try it, and find another way if it does not work | 03 §9; `docs/agents/dcs-runtime-traps.md` |
| V1 | Economy: coalition credits earned by kills, captures and deliveries, a small shop of 6 to 8 items whose effects VEAF already has (JTAC, illumination or smoke, tanker, friendly CAP, intel, capture) | 05 §1–§2, §5 |
| V1 | A task board of 3 or 4 tasks drawn from the situation, with a map mark and a credit reward; a briefing explains the particular points if needed | 05 §11 |
| V1 | Intelligence: an enemy garrison's composition stays hidden until reconnoitred (overflight, JTAC, purchased intel) | 06 §5 |
| V1.5 | Weapon stocks per warehouse, moved by players | 07 §9, §17 |
| V1.5 | Territory cells (Voronoi) tinted by owner on the F10 map | 01 §14 |
| V2 | Foothold's Director (packages, feints, learning) | 04 |
| V2 | Foothold's full player economy: personal credits banked on landing, ranks, career | 05 §3, §7–§10 |
| V1 | Hunter: two enemy fighters scrambled against a player on a kill streak | 03 §8 |
| V1 | Spy team: a CTLD troop that walks into an enemy zone and reveals it for an hour (feeds the intelligence line above) | 07 §10 |
| V1.5 | Strategic bombers: an escorted red raid to intercept; a blue raid bought in the shop | 03 §12 |
| V1.5 | **Zone kinds** (David, 2026-11-16): factories, air bases, naval bases… each played its own way. A factory is a set of statics (its buildings): it makes sense to demolish it, and destroying it costs the enemy something. An air base makes no sense to demolish: it is captured, after its defences are destroyed. Today every zone is the same — an airfield or a point, a garrison of vehicles, taken by ground presence — and `kind: logistics` is the only kind | 01 §1, §5; 07 §27–§29 |
| V1.5 | Demolition team: CTLD sappers who blow up a zone's structures — needs the zone kinds above: only a kind made of statics, such as a factory, has anything to blow up | 07 §10 |
| CTLD | C-130J air-dropped crates that build themselves: a feature of our CTLD 2, not of this lot | 07 §13 |
| left out | Trains (Normandy only) | 07 §30 |
| left out | PvP, splash damage, EWRS, ten languages | — |

The MCP side generates the dynamic mission in both modes from the same format; its actions come once the format has settled.

**The two modes in V1 (David, 2026-11-15).** The V1 delivers the persistent mode only.
Its live play (dormancy, sorties, credits, tasks, intelligence) is settings of `veafCampaign`, started only when `mode: persistent`.
Running it inside a multi-mission campaign — carrying credits and intelligence from one mission to the next through `campaign apply`, deciding what tasks and counter-attacks become between missions — and the MCP actions are a later lot, opened once the V1 has proved itself in game.

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
9. What can be spawned during a flight is bounded by the campaign, for everyone: a player's or a human game master's `_spawn` and Claude's live actions ([`FEAT-LIVE-GAME-MASTER`](../FEAT-LIVE-GAME-MASTER/PRD.md)) alike.
   Measured 2026-10-08: the multi-mission campaign has a ground reserve per side and category (`veafCampaign.reserveOf`), drawn on when a garrison is composed, but nothing checks a `_spawn` against it during the flight.
   David, 2026-10-08: "en campagne, tu ne peux pas spawner n'importe quoi. Mais c'est aussi valable pour nous".

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

Superseded on 2026-11-15 by the feature selection above: the shop, the coalition credits, the task board, the JTAC and the tanker are V1 now.
Still out of V1: ranks, personal credits, Foothold's director and events (V2), and the rows marked V1.5, V2 or left out.
Restoring aircraft and convoys in flight after a restart is not in V1 either: they are lost, the zones and garrisons are not.
**MCP actions and the prompt** (`create_campaign`, `add_campaign_zone`, `connect_zones`, a
composite from a theatre description, the authoring skill) are the **next lot**, opened once the
`campaign.yaml` format has survived this one.

## Related

- `FEAT-CTLD-AIRBASE-LOGISTICS` — airfield logistic zones that follow the owner: a capture must flip them.
- `FEAT-SCENERY-AWARE-SPAWN` (archived) — `veaf.findSpawnPoint`, the placement this lot reuses.
- Roadmap §4 `PERSISTENCE` — only the campaign's own state is persisted here, not every VEAF module.
- [`foothold-analysis.md`](foothold-analysis.md) — the functional and technical inventory of Foothold 6.5.3 (2026-11-15, in French): every feature, how it works, what VEAF already has, and five statements of this PRD that no longer hold on that version (a licence exists, Moose is a toolbox, dormancy and staggering are already there).

## Tickets

Realigned on the V1 on 2026-11-15: the seven tickets of 2026-10-03 predated both the multi-mission campaign, which built the format, the capture, the map and the state writer, and the feature selection.
Their content is either done there, or carried into the tickets below.

| # | ticket | status |
|---|---|---|
| 01 | [Persistent mode: save, reload, win, defeat, reset](tickets/01-persistent-mode.md) | 🧑 |
| 02 | [Dormant zones, caps and work counters](tickets/02-dormancy.md) | 🧑 |
| 03 | [A front that moves on its own: counter-attacks, supply, CTLD 2](tickets/03-live-front.md) | 🧑 |
| 04 | [AI helicopters capture and resupply zones](tickets/04-ai-supply-helicopters.md) | 🧑 |
| 05 | [Enemy air: CAP, CAS and SEAD strikes, Hunter](tickets/05-enemy-air.md) | 🧑 |
| 06 | [Coalition credits and a small shop](tickets/06-economy-shop.md) | 🧑 |
| 07 | [A task board drawn from the situation](tickets/07-task-board.md) | 🧑 |
| 08 | [Intelligence: hidden garrisons, reconnaissance, spy team](tickets/08-intelligence.md) | 🧑 |
| 09 | [Documentation, example campaign, test mission, in-game check](tickets/09-doc-example-test-mission.md) | 🧑 |
| 10 | [Measure it against Foothold, then tune the caps](tickets/10-measure-against-foothold.md) | ⬜ |

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a Foothold-like persistent campaign, built on VMCT alone.** David, 2026-10-03: Foothold is hard on our servers and he suspects Moose; he wants its player experience without it. Read on Foothold 4.7.0: an 81 542-line engine fed per map by 7 386 hand-written lines and ~1 200 hand-placed zones, Moose on 2 % of the engine's lines; a fork is ruled out (no upstream licence, thousands of engine lines rewritten every weekly release). Here the campaign is declared in a `campaign.yaml` sidecar, the build generates zones, slots and data, garrisons are drawn per size class from the VEAF database, sorties are derived from the graph, a neutral zone is captured by any ground presence of one side (convoy, CTLD 2 troops or crate, landed supply helicopter — Foothold's rule, one detection instead of one per channel), and performance is designed in (dormant zones, one loop, events, caps). Production allows `io`/`lfs` to missions (measured), so persistence needs no server change. Seven tickets; no up-front measurement (a workstation says nothing of the servers): the caps are settings, tuned after a server evening, which also compares with Foothold. MCP actions and the prompt are the next lot
