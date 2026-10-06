# FEAT-LIVE-GAME-MASTER — Claude acting in a running mission while the squadron flies

Status: ⬜ ready

David, 2026-10-06, while scoping [`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md): he would like Claude to intervene **live** during a flight, through the bridge — spawn things, destroy others, move convoys, send radio messages to the players — and said it is probably a lot of its own.
This PRD only records the request and what is already known; it is written up properly when the lot is taken.

## What exists

- The DCS bridge: `dcs-serve` and its HTTP API (`POST /api/exec`, Bearer token), already used by the tools to capture a theatre's airbases (`CLI_REFERENCE`, `--serve-url` / `DCS_BRIDGE_API_KEY`).
- The VEAF runtime already does most of the actions through its own commands: `_spawn`, `_destroy`, `veafGroundAI` convoys, `trigger.action.outText*` messages, the radio menus.

## What the lot has to answer

- **The actions**: a small set of MCP actions that call the VEAF runtime through the bridge (spawn, destroy, move a group, message a coalition or a group, read the situation), rather than raw Lua sent from the conversation.
- **The guardrails**: what Claude may do without asking during a session where people are flying (David's rule: an action on his live session is his to launch), which actions need his go, and a log of every action taken, readable by admins in game.
- **The reach**: local server only, or dcs.veaf.org too — the bridge's exposure and its key on a production server are David's call.
- **With a campaign** (`FEAT-MULTI-MISSION-CAMPAIGN`): what Claude does live must reach the state file like anything else that happens in the mission.

## Tickets

Written when the lot is taken.
