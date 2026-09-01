# CHORE-RENAME-SPAWN-EFFECTS — `veafSpawnEffects` is not about effects

Status: ✅ done — split landed 2026-09-01, both tickets closed

Origin: David, 2026-08-28, reading the `DROP-MIST` ticket 07 enumeration — *"pour veafSpawnEffects, y'a
124 types d'effets (fumée, feu, etc.) ?"*. The answer was no, and the question only arose because the
file's name says something its contents never did.

## Why the name is wrong, established from the history

`veafSpawnEffects.lua` was created on **2026-05-21** by commit `049ac196`, *"feat(lua): split
veafSpawn.lua into 4 sub-modules (LUAR-001)"*. `veafSpawn.lua` had reached 4528 lines and was cut along
three axes — the core, the ground, the aircraft — plus **whatever was left**. The commit message names
the residue itself:

```
- veafSpawnEffects.lua: cargo, bomb, smoke, flares, destroy, teleport (~489 lines)
```

So the module was never *"the effects"*: it is the remainder of a three-way split, named after the
loudest quarter of what it holds. The commit message does not even mention `doSpawnStatic`, which was in
it from the first day.

## What it actually contains today (551 lines)

| Function | Nature |
|---|---|
| `spawnCargo`, `doSpawnCargo` | **creates an object** |
| `spawnLogistic` | **creates an object** |
| `doSpawnStatic` | **creates an object** — the `-spawn static` command, any of 873 catalogue types |
| `teleport` | **moves an object** |
| `destroy`, `destroyObjectWithFlak` | **removes an object** |
| `spawnBomb` | an effect |
| `spawnSmoke` | an effect |
| `spawnSignalFlare` | an effect |
| `spawnIlluminationFlare` | an effect |

**Five of the nine create, move or remove objects. Four are effects.** The four effects go through
`trigger.action.smoke` / `signalFlare` / `illuminationBomb` / `explosion`; the five others go through
`dynAddStatic`, `teleportToPoint` and `Object.destroy`.

## What it costs today

Nothing at runtime. The cost is in reading: it produced a wrong sentence in the `DROP-MIST` ticket 07
enumeration (*"any of the 124 can arrive there"*, corrected to 93 spawnable statics) and a question from
David that a correct name would not have raised. It will do the same to the next reader, and the next
lot to touch spawning is ticket 07 itself.

## The move

Split it in two along the line above:

- **`veafSpawnObjects.lua`** — cargo, logistic, static, teleport, destroy. What creates, moves or
  removes something that stays in the world.
- **`veafSpawnEffects.lua`** — bomb, smoke, signal flare, illumination flare. What flashes and fades.
  The name becomes true instead of being retired.

A plain rename of the whole file would be cheaper but would leave the same problem under a different
word: the file's real defect is that it holds two unrelated things.

## Every place the file is named, checked 2026-08-28

The memory note says adding a Lua module means editing five registries, three of which fail silently.
Measured for this one, it is **less than that** — and knowing which are guarded is the point:

| Where | What | Guarded? |
|---|---|---|
| `veaf_build/worker.py` — `LUA_BUNDLE_SCRIPTS` | the bundle order | ✅ `test/python/veaf_build/test_lua_bundle_manifest.py` fails on a file missing from the list |
| `src/scripts/veaf/veafSpawn.lua` | the proxy's `dofile` **and** its header comment | ❌ silent — a missing `dofile` only shows as a nil function at runtime |
| `doc/TESTING.md` / `.en.md` | only if a test suite is added | ✅ `docs-check` |
| `test/lua/dcs_mocks.lua`, `src/scripts/veaf/veafScheduler.lua`, `test/lua/test_veafScheduler.lua` | comments naming the module | ❌ silent, and harmless |

`.luacheckrc` lists the `veafSpawn` global, not the file, so it needs nothing. `VeafDynamicLoader.lua`
loads the `veafSpawn.lua` proxy only. `build/` and `published/` are artefacts. `CHANGELOG.md` and
`ROADMAP.md` mention it historically and must **not** be rewritten.

**So the real risk is one line: the `dofile` in the proxy.** Everything else either fails a test or is a
comment.

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | [Objects move out, the effects module keeps its name](tickets/01-split-objects-out-of-effects.md) | low — a pure move, proven byte-identical outside the comments | ✅ |
| 02 | [A guard for the one line that fails silently](tickets/02-a-guard-for-the-silent-line.md) | low — three tests beside the bundle guard | ✅ |

## What implementation found that this document did not say

Four things, all measured 2026-09-01 on `origin/develop` at `e20ff90c`:

1. **The load order is load-bearing, and this PRD did not mention it.** `veafSpawn.commandHandlers`
   is an *ordered* list and `executeCommand` dispatches first-match-wins. Splitting the file puts
   eight handlers into two files, so the file order decides the handler order. `veafSpawnObjects.lua`
   therefore comes **before** `veafSpawnEffects.lua` in both the proxy and `LUA_BUNDLE_SCRIPTS`,
   which reproduces the previous order exactly. Reversed, the split would have silently reordered
   `bomb`/`smoke`/`flare`/`signal` ahead of `cargo`/`logistic`/`destroy`/`teleport`.
2. **The `dofile` for this sub-module was already guarded, by accident.** Removing the line makes
   `poetry run test-lua` fail (`test_veafSpawn.lua` asserts on `DEFAULT_FLAK_POWER` and on the object
   spawners, all now in `veafSpawnObjects.lua`). The silent-failure risk is real for the *next*
   sub-module, not for this one — see ticket 02.
3. **The sequencing note is stale on its own premise.** It said this lot must wait because ticket 07
   of `DROP-MIST` migrates "two `dynAddStatic` calls" living in this file. That migration has since
   landed: the file calls `veaf.addStatic` and holds no MiST call at all.
4. **The registry table is accurate but one line under-counts.** `doc/TESTING.md` needed nothing (no
   Lua suite was added) and `.luacheckrc` needed nothing, as stated. The comments row named three
   files; there are **five** — `veafScheduler.lua`, `veafDcsSpawner.lua`, `test/lua/dcs_mocks.lua`,
   `test/lua/test_veafScheduler.lua`, `test/lua/test_veafDcsSpawner.lua`. The `dcs_mocks.lua` mention
   of `veafSpawnEffects.spawnSignalFlare` was left alone: it is still true.

## Sequencing

**After `DROP-MIST` ticket 07.** That ticket migrates 18 `dynAddStatic` calls, two of which live in this
file; moving the functions first would make its diff harder to read for no gain. This is a chore, it can
wait for the campaign to clear.

## Definition of done

- [x] `veafSpawnObjects.lua` holds cargo, logistic, static, teleport, destroy
- [x] `veafSpawnEffects.lua` holds bomb, smoke, signal flare, illumination flare — and nothing else
- [x] `veafSpawn.lua`'s `dofile` list and header comment updated
- [x] `LUA_BUNDLE_SCRIPTS` updated, `test_lua_bundle_manifest` green
- [x] The Lua suite passes unchanged — this moves functions, it does not touch one
- [x] `stylua --check` clean; `luacheck` is not installed on this workstation, the CI Lua gate runs it
