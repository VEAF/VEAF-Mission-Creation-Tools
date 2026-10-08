# 02 — Live actions in the MCP server

Status: ⬜ ready

In `veaf_mission_mcp` (D1), three actions that talk to a running mission through `dcs-serve`, with an **`operator`** token — never `superuser`, so none of them can reach `/api/exec`.

| Action | Route on the bridge | What it returns |
|---|---|---|
| `live_situation` | `/api/units`, `/api/mission`, and a new bridge action `veaf_state` (`observer`, `veaf` backend) for what only the VEAF scripts know | players and their slots; groups by coalition, filtered by a point and a radius or a zone name; the combat zones and whether they are active; the campaign zones and their owner when `veafCampaign.data` is set |
| `live_command` | `/api/action` `run_keyphrase` | the command run, its position, the groups it spawned (from ticket 01's `spawnedGroups`), or the reason it was refused |
| `live_message` | a new bridge action, `message` (`operator`), with a `dcs` backend: `trigger.action.outText`, `outTextForCoalition`, `outTextForGroup` | to whom it went |

## Rules

- **The position** is given as lat/lon, MGRS, a named point, a combat zone or a unit's name, and resolved by the tools; the action states the position it used, in lat/lon and MGRS, so Claude can say where it put things.
- **The coalition** of a `live_command` is explicit: the marker default (the opposite of the player's) has no meaning without a player.
- **No mission, no action**: `capabilities` answering `{"connected": false}` gives "no mission running", not a bridge error.
- The key and the URL come from the same place as `capture-map` (`--serve-url`, `DCS_BRIDGE_API_KEY`, `dcs-serve.yaml` / `dcs-client.yaml`), with a second variable for the operator token if the bridge's legacy key is a superuser one.
- The MCP action catalogue page is updated in the same PR (lockstep).

## Done when

Each action has its tests against a fake bridge (HTTP stubbed, not mocked at the function), including: the refused command, the disconnected mission, the 403 on a role too low, and the absence of any `/api/exec` call from the three actions.
`live_situation` is checked against a real `dcs-serve` on a running mission before the PR leaves (David's machine, by me — he only loads the mission).
