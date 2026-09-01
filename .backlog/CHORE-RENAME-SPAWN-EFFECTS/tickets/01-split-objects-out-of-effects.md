# 01 — Objects move out, the effects module keeps its name

Status: ✅ done
Type: chore

## What was wrong

`veafSpawnEffects.lua` (550 lines) held nine functions, five of which create, move or remove
something that stays in the world. The name described the loudest quarter of the file, and the PRD
records what that cost: a wrong sentence in `DROP-MIST` ticket 07 and a question that a correct name
would not have raised.

## What was done

The file was cut along the line the PRD draws, **without touching a single function body**:

| New file | Functions |
|---|---|
| `veafSpawnObjects.lua` (376 lines) | `spawnCargo`, `spawnLogistic`, `doSpawnCargo`, `doSpawnStatic`, the FLAK constants, `destroyObjectWithFlak`, `destroy`, `teleport`, and the `cargo` / `logistic` / `destroy` / `teleport` command handlers |
| `veafSpawnEffects.lua` (188 lines) | `spawnBomb`, `spawnSmoke`, `spawnSignalFlare`, `spawnIlluminationFlare`, and the `bomb` / `smoke` / `flare` / `signal` command handlers |

`destroyObjectWithFlak` goes with the objects even though it fires `trigger.action.explosion`: what
it is for is removing an object, and it is the one that reschedules itself until the object is gone.

**Load order is deliberate.** `veafSpawnObjects.lua` is registered *before* `veafSpawnEffects.lua` in
both the proxy and `LUA_BUNDLE_SCRIPTS`, which reproduces the previous registration order exactly —
`veafSpawn.commandHandlers` is an ordered list and `executeCommand` dispatches first-match-wins, so
reversing the two files would silently reorder eight command handlers.

Registries updated: the `dofile` list and the header comment of the `veafSpawn.lua` proxy,
`LUA_BUNDLE_SCRIPTS` in `veaf_build/worker.py`, and four comments that named the module for code
which now lives in `veafSpawnObjects` (`veafScheduler.lua`, `veafDcsSpawner.lua`,
`test/lua/test_veafScheduler.lua`, `test/lua/test_veafDcsSpawner.lua`, `test/lua/dcs_mocks.lua`).

## How it was proven to be a pure move

Both new files, concatenated and stripped of blank and comment lines, are **byte-identical** to the
original file given the same treatment: 442 lines each way, `diff` empty. That is the ticket's whole
claim — the Lua suite passing unchanged (45 suites, 0 failures) says the move did not break anything,
the diff says nothing else changed either.

## Definition of done

- [x] `veafSpawnObjects.lua` holds cargo, logistic, static, teleport, destroy
- [x] `veafSpawnEffects.lua` holds bomb, smoke, signal flare, illumination flare — and nothing else
- [x] Proxy `dofile` list and header comment updated, order preserved
- [x] `LUA_BUNDLE_SCRIPTS` updated, `test_lua_bundle_manifest` green
- [x] The Lua suite passes unchanged
- [x] `stylua --check` clean
