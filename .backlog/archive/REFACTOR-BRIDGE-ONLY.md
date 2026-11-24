# REFACTOR-BRIDGE-ONLY — one way to talk to a running DCS: the VEAF bridge

Status: ✅ done · archived 2026-11-24

David decided on 2026-10-28 that VMCT reaches a running DCS through **one** technology, the VEAF bridge (`dcs-bridge.lua` in the mission, `dcs-serve` on this machine), and no longer through the DCS Fiddle hook (`src/scripts/other/dcs-fiddle-server.lua`).
Two technologies were too hard to explain: a VEAF member could not tell "the bridge" from "the MCP" from Fiddle.
The hook was never shipped in `published.zip` either, so a mission maker could not run the commands that needed it without fetching a file from the repository.

Measured on 2026-10-28 in David's DCS, from the mission scripting environment where the bridge runs: `net.dostring_in` reaches `export`, `gui`, `server` and `config`, and `LoSetCameraPosition` sent through `export` moves the F11 camera (145 → 445 m).
So everything the hook was used for can be sent from the bridge.

| # | What | Ticket |
|---|---|---|
| 01 | A bridge session shared by the commands: start `dcs-serve` with a key of its own, wait for the mission to connect, raise a Lua error instead of returning an empty string, run a chunk in another Lua state | 01 |
| 02 | `recon-prepare` injects the bridge into the shooting copy; `recon-plan` and `recon-shoot` go through it | 02 |
| 03 | `mission-check-prepare` writes a test copy carrying the bridge; `mission-check` goes through it | 03 |
| 04 | `smoke-test` runs every check over the bridge; `--full`, `--probe-only` and the unattended lifecycle go | 04 |
| 05 | `veaf-build update-dcs-data --airfield-freqs --capture` reads the GUI state through the bridge | 05 |
| 06 | The hook goes: `dcs_fiddle_client`, `dcs-fiddle-server.lua`, its token, its messages; ADR 0019 superseded | 06 |
| 07 | Documentation FR + EN, CHANGELOG | 07 |
| 08 | In-game check of every moved command | 08 |

Decided (2026-10-28 / 2026-10-29):

- David launches DCS and loads the mission himself, and `net.load_mission` does nothing in single player: "it works with no mission loaded" is not a reason to keep the hook, so the unattended `smoke-test --full` lifecycle goes with it;
- the bridge needs `require("socket")`, i.e. the `MissionScripting.lua` change already documented for `terrain` / `clear-ground`: reused, not written a second time;
- the window capture of `recon-shoot` stays local Python;
- `clear-ground-sweep` keeps its own `dcs-serve` start-up, which already works: this lot does not touch it.

One branch, one PR.

## Tickets, in full

## 01 — A bridge session shared by the commands

Status: ✅ done

One helper the commands call instead of each opening the hook: start `dcs-serve` (loopback, a key of its own, in the folder `clear-ground-sweep` already uses) unless one answers, wait until the mission's bridge connects (it reconnects with a back-off of up to 60 s of mission time), and stop the server it started at the end.

- a Lua error comes back from `dcs-serve` as `{"error": …}` with HTTP 200; `exec_over_bridge` returned an empty string for it. It now raises;
- `in_state_lua(state, code)`: the chunk that runs *code* in another Lua state through `net.dostring_in`, which hands a Lua error back as its string result — told apart by its shape, as the hook client did.

Done when: the helper and both behaviours are unit-tested.

## 02 — Recon over the bridge

Status: ✅ done

- `recon-prepare` injects `dcs-bridge.lua` into the shooting copy (`--bridge-lua` for a local file, downloaded otherwise);
- `recon-plan` and `recon-shoot` read the units in the mission scripting state and move the camera through `net.dostring_in("export", …)`;
- `--url` / `--fiddle-token` give way to `--serve-url`, `--dcs-serve`, `--api-key`, `--config`.

Done when: the commands are unit-tested against a fake bridge.

## 03 — mission-check over the bridge

Status: ✅ done

- `mission-check-prepare MISSION` writes `<stem>_CHECK.miz` beside it: the mission, the bridge injected, nothing else changed;
- `mission-check` sends its chunks to the bridge, which runs where the `veaf*` modules live (the fiddle server on 12080 did the same).

Done when: both are unit-tested.

## 04 — smoke-test over the bridge only

Status: ✅ done

Every check rides the bridge: it runs in the mission scripting state, which has DCS's own globals (`Disposition`, `missionCommands`, `coalition`) as well as `veaf`.
The hook probe, `--probe-only`, and the unattended `--full` lifecycle (`dcs_lifecycle.py`: launch DCS, `net.load_mission`, `exitProcess`) go: David launches DCS and loads the mission himself, and `net.load_mission` does nothing in single player.

Done when: `dcs_smoke` has no hook path left and its tests pass.

## 05 — Airfield frequency capture over the bridge

Status: ✅ done

`veaf-build update-dcs-data --airfield-freqs --capture` read `Terrain.GetTerrainConfig` and `DCS.getATCradiosData` in the hook's GUI environment.
The blank capture missions now carry the bridge, and the capture chunk is sent to the `gui` state through `net.dostring_in`, JSON-encoded there with `net.lua2json` since only a string crosses.

Done when: the session is unit-tested against a fake bridge, and one theatre is captured in game.

## 06 — Remove the hook

Status: ✅ done

`veaf_libs/dcs_fiddle_client.py`, `src/scripts/other/dcs-fiddle-server.lua`, its per-session token, its messages and tests go.
ADR 0019 (the hook stays unauthenticated) is superseded by a new ADR recording the decision of this lot.

Done when: nothing in the shipped code or the documentation still sends anyone to the hook.

## 07 — Documentation and CHANGELOG

Status: ✅ done

`doc/CLI_REFERENCE*.md`, `doc/mission-maker/GUIDE*.md`, `doc/developer/smoke-harness*.md`, `doc/developer/dcs-data*.md`: the bridge, the `MissionScripting.lua` change already written for `terrain` linked rather than repeated. One CHANGELOG entry.

## 08 — In-game check

Status: ✅ done

In David's DCS (`C:\jeux\DCS World`): `recon-plan` and `recon-shoot` on a shooting copy, `mission-check` on a test copy, `smoke-test`, one theatre of the airfield frequency capture.

### Result

2026-10-29, 12:01–12:10 (Paris), David's DCS, `VEAF_Syria_MarteauDuGolan_RECON_BRIDGE.miz` (the shooting copy written by `recon-prepare`), through a `dcs-serve` another session had started (`--config`):

- `recon-plan`: 8 shots written from the live units;
- `mission-check`: PASS, 16 checks (147 menu entries, 10 zones, 2 routed columns moving, 4 CAP variants);
- `smoke-test`: 9/9, the four `Disposition` checks and the coalition submenu — formerly hook checks — included;
- the airfield capture chunk sent to the `gui` state: Syria, 224 airdromes, 81 from radio and 143 without — identical to the committed `Syria.json`;
- `recon-shoot --only 02-contreattaque`: the F11 camera moved through `export`, the window grabbed, `recon-render` made the photo.

Not exercised in game: `dcs-serve` started by the command itself (one was already running), `mission-check-prepare`'s copy (the shooting copy carried the bridge already), and the capture command's own loop (`THEATRE_LUA`, one mission per theatre) — only its `gui` chunk was. Each is covered by unit tests.

The first attempt to load the copy failed on two La-7 templates whose frequencies (118.6 / 121.5 MHz) are outside the La-7's 3.7–6.06 MHz radio — a defect of the shipped templates, not of this lot, handled in its own session.
