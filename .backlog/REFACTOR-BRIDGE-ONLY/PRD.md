# REFACTOR-BRIDGE-ONLY — one way to talk to a running DCS: the VEAF bridge

Status: ✅ done

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
