# 01 — The bridge's VEAF call matches `veafCommands.execute`

Status: ⬜ ready

Repository: `VEAF/VEAF-dcs-bridge` (`src/dcs_bridge/serve/actions.py`, `_veaf_execute_lua`), one PR there.

The bridge builds `veafCommands.execute(__pos, text, coalition, nil, level)` and documents the fourth argument as `bypassSecurity` and the fifth as the caller's level.
VMCT's signature, since Lot 14 (`6b5731ab`, 2026-05-21), is `veafCommands.execute(pos, text, coalition, spawnedGroups, route)`, and it bypasses security on that path by design (`veafCommands.lua`, the comment above `isAllowed`).
The level therefore reaches `route`.

## Done when

- The snippet passes nothing in the fourth and fifth positions, or a real `spawnedGroups` table it reads back to return the names of the groups it spawned (useful to ticket 02 and the journal).
- The docstring no longer claims "no security bypass": the bridge's role check is the gate, and it says so.
- A bridge test asserts the exact Lua emitted; a VMCT Lua test runs that exact snippet against the mocks and checks a ground spawn gets no route.
- Before the fix, measured on the mocks: what a number in `route` does to a `_spawn convoy` and to a `_move group` (the finding goes into the PR, and into `known-limitations.yaml` if a shipped version is affected).
