---
status: accepted
---

# One transport to a running DCS: the VEAF bridge

Lot: [REFACTOR-BRIDGE-ONLY](../../.backlog/REFACTOR-BRIDGE-ONLY/PRD.md).
Decided by David on 2026-10-28.

## Context

Two technologies reached a running DCS from the tools.
The **VEAF bridge** — `dcs-bridge.lua` embedded in the mission, `dcs-serve` on the machine — carried `capture-map`, `clear-ground-sweep`, `terrain-sweep` and the VEAF assertions of `smoke-test`.
The **DCS Fiddle hook** — `dcs-fiddle-server.lua` copied into `Saved Games/DCS/Scripts/Hooks/` — carried `recon-plan`, `recon-shoot`, `mission-check`, the DCS-native checks and the unattended `--full` run of `smoke-test`, and the airfield frequency capture of `veaf-build`.

Two technologies were too hard to explain: a VEAF member could not tell "the bridge" from "the MCP" from Fiddle.
The hook was never in `published.zip` either, so a mission maker had to fetch a file from the repository to run the commands that needed it.

The hook's one advantage was that it answers with no mission loaded.
It mattered only to the unattended `--full` run, which could not load a mission anyway: `net.load_mission` does nothing in single player (measured 2026-08-15), and David launches DCS and loads the mission himself.

## Decision

The bridge is the only way the tools talk to a running DCS, and the hook is removed.

What the hook reached, the bridge reaches from the mission scripting state through `net.dostring_in`: `export`, `gui`, `server` and `config` answered, and `LoSetCameraPosition` sent through `export` moved the F11 camera from 145 to 445 m (measured 2026-10-28 in David's DCS).
So `recon-shoot` moves the camera through `export`, and the airfield frequency capture reads the Mission Editor's terrain data in `gui`; everything else runs in the mission scripting state itself, where both DCS's globals and the VEAF scripts live.

The mission has to carry the bridge: `recon-prepare` and the new `mission-check-prepare` embed it in the copy they write, the airfield capture missions embed it, and `smoke-test` needs a mission built with `dcs_bridge`.
`dcs-serve` is started by the commands when none runs, with a key of their own, on the loopback.

## Consequences

- One `MissionScripting.lua` change (the bridge needs `require("socket")`) and one server to explain, for every command that talks to DCS.
- `smoke-test --full`, `--probe-only` and the hook's per-session token are gone, and with them [ADR 0019](0019-dcs-fiddle-server-stays-unauthenticated-for-now.md), whose subject no longer exists.
- Nothing can be asked of DCS before a mission is running. No command needs it.
- `smoke-test` no longer *skips* when there is nothing to talk to: it waits for the mission's bridge (`--wait`) and fails, naming what it waited for. It is run by hand in front of a DCS, never by CI or a script, so a red run on a machine without DCS asks nothing of anyone.
- The bridge runs on the mission's clock: a paused mission does not answer, and a bridge whose `dcs-serve` started after it can take up to a minute of mission time to reconnect. The commands wait and say so.
