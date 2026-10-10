# FEAT-LIVE-GAME-MASTER — Claude acting in a running mission while the squadron flies

Status: ⬜ ready

David, 2026-10-06, while scoping [`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md): he would like Claude to intervene **live** during a flight, through the bridge — spawn things, destroy others, move convoys, send radio messages to the players — and said it is probably a lot of its own.
Written up 2026-10-08.

## The need

During a flight, the game master is today a human in the game master slot, typing marker commands on the F10 map.
The lot lets Claude be that game master from the conversation: David (or whoever runs the session) says "envoie un convoi de ravitaillement vers Senaki" or "les bleus traînent, ajoute une patrouille de MiG-29 au nord de la zone", Claude reads the situation, does it, and the players see the result as if a human game master had done it.

What it is not: an autonomous director that runs the mission on its own between two messages.
Claude acts when asked, in the conversation; a loop that watches the mission and decides alone is out of this lot.

## What exists — measured 2026-10-08

**The bridge already does most of the transport, and more than this PRD's stub assumed.**

- `dcs-serve` (repository `VEAF/VEAF-dcs-bridge`, last commit 2026-07-28) carries **role-bearing tokens** (ADR-0005 there): `observer` < `pilot` < `operator` < `superuser`.
  `/api/exec` (raw Lua) needs `superuser`; `/api/units` and `/api/mission` need `observer`; `/api/action` runs a registered action after checking its own minimum role.
- Its action registry already has `spawn`, `smoke`, `remove` and **`run_keyphrase`** (`operator`), which runs a VEAF marker command at a position through `veafCommands.execute`, no map marker needed.
- The VEAF marker language already covers the verbs David named: `_spawn` (units, groups, convoys), `_destroy`, `_move group` (`SENIOR_PILOT`), plus everything else a game master types on the map.
- The VEAF campaign module records a loss when a garrison unit dies (`veafCampaign.onUnitDead`, on the death events).

**A defect found while reading, which ticket 01 fixes.**
The bridge calls `veafCommands.execute(pos, text, coalition, nil, level)`, believing the fourth argument is `bypassSecurity` and the fifth the caller's level.
Since VMCT's Lot 14 (2026-05-21) the signature is `execute(pos, text, coalition, spawnedGroups, route)`, and the function **always bypasses security** by design.
So the level the bridge sends lands in `route`, and its docstring's "no security bypass" is false: the only gate is the bridge's own role check.
Not yet measured in game what a number in `route` does to a ground spawn; the reading of the code says a convoy or a `_move` could take it as a route.

## What the lot delivers

1. **The bridge's VEAF path made true** (ticket 01): the call matches the signature, and the level is either carried for real or dropped from the claim.
2. **Live actions in the VMCT MCP server** (ticket 02), the same server Claude already uses to author the mission, so the vocabulary is the same at both ends:
   - `live_situation` — read: players and their slots, groups by coalition near a point or a zone, the combat zones and their state, the campaign zones and their owner when the mission is part of a campaign;
   - `live_command` — run one VEAF marker command at a position (`_spawn`, `_destroy`, `_move`, `-sa6`, every alias), through the bridge's `run_keyphrase`;
   - `live_message` — a text message to everyone, one coalition, or one group, for a duration.
   They hold an **`operator` token, never a `superuser` one**: Claude cannot send raw Lua to a running mission through these actions, by construction rather than by promise.
3. **A journal of what the game master did** (ticket 03): every live action written to `dcs.log` with one prefix, and readable in game by admins from a radio menu.
4. **The campaign counts it** (ticket 04): a garrison unit Claude destroys is a loss in the state file, like one the players kill.
5. **A voice** (ticket 07): a warning to blue players spoken on their SRS frequency, alongside the text.
6. **Documentation** (ticket 05): a FR/EN page for the person who runs a session — start the bridge, give Claude the key, what it can and cannot do — plus the authoring skill and the known limitations.
7. **The in-game check** (ticket 06): a new entry in `DCS-SESSION-TODO.md`.

## Decisions — David, 2026-10-08

| # | Question | Decision |
|---|---|---|
| D1 | Where the live actions live | in the VMCT MCP server, calling the bridge with an `operator` token; the bridge stays the transport |
| D2 | What Claude does without asking during a flight | **free by default**: the person running the session allows the live actions in Claude Code's permissions, and Claude acts on a request without a further go. A budget only makes sense in a campaign, and there it is the campaign that bounds what can be spawned, for everyone — moved to `FEAT-DYNAMIC-CAMPAIGN` (its item 9) |
| D3 | What the players see of it | **it depends on the side Claude plays.** Playing red, nothing is shown: the players meet the enemy, not its game master. Playing blue, Claude decides from the situation whether the players concerned need warning — a tasking, a threat popping up near them — and warns them by text and, when SRS is there, by voice (ticket 07). The journal (ticket 03) is for admins in every case |
| D4 | The reach | v1 local: a mission David hosts or flies himself; dcs.veaf.org later, through an SSH tunnel to a bridge bound to loopback, so no new port opens on the server |
| D5 | What Claude spawns, in a campaign | out of this lot: what may be spawned in a campaign is the campaign's question, for players and Claude alike (`FEAT-DYNAMIC-CAMPAIGN`, item 9). Here, what Claude spawns is not added to a garrison, and what Claude destroys from one is a loss (ticket 04) |

D4 in practice: the MCP stays on David's PC while the squadron's DCS and SRS servers run on dcs.veaf.org (David, 2026-10-08).
So the voice of ticket 07 reaches the server through SSH from the start, and the bridge's own reach to a production instance is the next step after v1, not a remote one.

## Voice through SRS — possible, measured 2026-10-08

VMCT already has the code: `veafRadio._transmitViaSRS` builds the `DCS-SR-ExternalAudio.exe` command line (`-t` text, `-f`, `-m`, `-c`, `-p`, `-n`, shell-safe) and runs it with `os.execute` from inside the mission, reaching `os` directly or through `SERVER_CONFIG.getModule("os")`; `veaf.lua` fills `STTS.DIRECTORY`, `SRS_PORT` and `EXECUTABLE` from `SERVER_CONFIG`.
Whether that path speaks today, measured on both machines:

| | `os` in the mission | `SERVER_CONFIG.SRS_*` | In-mission voice |
|---|---|---|---|
| DAVID-BUREAU | reachable: the customised `MissionScripting.lua` defines `SERVER_CONFIG.getModule`, which returns the saved `os` | not set | mute — `STTS.DIRECTORY` ends up nil |
| dcs.veaf.org (`C:\DCS World OpenBeta Server`, 22 lines) | sanitised, and no `SERVER_CONFIG` anywhere in the install or `private1_server\Scripts` | not set | mute |

`DCS-SR-ExternalAudio.exe` is installed on DAVID-BUREAU (`C:\Program Files\DCS-SimpleRadio-Standalone\ExternalAudio\`).
So the voice Claude sends goes **from the tools' side** (ticket 07): the MCP action runs the same executable with the same arguments as `veafRadio`, on the machine that hosts the SRS server, and nothing in DCS changes.
A voice the mission must produce **alone** — a unit calling for help with nobody in the conversation — needs the in-mission path, hence `SERVER_CONFIG` set on each machine; that is not this lot's need.

## Out of scope

- An autonomous director that acts between two messages without being asked.
- Raw Lua from the conversation into a running mission (`/api/exec`); it stays a `superuser` tool for development, outside this lot's actions.
- A spawn budget, and what may be spawned in a campaign (D2, D5): `FEAT-DYNAMIC-CAMPAIGN`.
- The production reach itself (D4), until David decides it: the bridge's key and exposure on a server the squadron flies on are his call.

## Tickets

- [01 — the bridge's VEAF call matches `veafCommands.execute`](tickets/01-bridge-veaf-call-signature.md)
- [02 — live actions in the MCP server](tickets/02-mcp-live-actions.md)
- [03 — the game master's journal](tickets/03-game-master-journal.md)
- [04 — the campaign counts what Claude destroys](tickets/04-campaign-counts-live-destroys.md)
- [05 — documentation, skill, known limitations](tickets/05-docs-skill-limitations.md)
- [06 — the in-game check](tickets/06-in-game-check.md)
- [07 — a voice on SRS](tickets/07-srs-voice.md)
