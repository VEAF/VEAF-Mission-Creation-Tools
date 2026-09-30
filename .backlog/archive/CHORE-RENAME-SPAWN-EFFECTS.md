# CHORE-RENAME-SPAWN-EFFECTS — `veafSpawnEffects` is not about effects

Status: ✅ done — split landed 2026-09-01, both tickets closed · archived 2026-09-28

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
| 01 | [Objects move out, the effects module keeps its name](CHORE-RENAME-SPAWN-EFFECTS.md) | low — a pure move, proven byte-identical outside the comments | ✅ |
| 02 | [A guard for the one line that fails silently](CHORE-RENAME-SPAWN-EFFECTS.md) | low — three tests beside the bundle guard | ✅ |

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

---

## Tickets, in full

## 01 — Objects move out, the effects module keeps its name

Status: ✅ done
Type: chore

### What was wrong

`veafSpawnEffects.lua` (550 lines) held nine functions, five of which create, move or remove
something that stays in the world. The name described the loudest quarter of the file, and the PRD
records what that cost: a wrong sentence in `DROP-MIST` ticket 07 and a question that a correct name
would not have raised.

### What was done

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

### How it was proven to be a pure move

Both new files, concatenated and stripped of blank and comment lines, are **byte-identical** to the
original file given the same treatment: 442 lines each way, `diff` empty. That is the ticket's whole
claim — the Lua suite passing unchanged (45 suites, 0 failures) says the move did not break anything,
the diff says nothing else changed either.

### Definition of done

- [x] `veafSpawnObjects.lua` holds cargo, logistic, static, teleport, destroy
- [x] `veafSpawnEffects.lua` holds bomb, smoke, signal flare, illumination flare — and nothing else
- [x] Proxy `dofile` list and header comment updated, order preserved
- [x] `LUA_BUNDLE_SCRIPTS` updated, `test_lua_bundle_manifest` green
- [x] The Lua suite passes unchanged
- [x] `stylua --check` clean

---

## 02 — A guard for the one line that fails silently

Status: ✅ done
Type: chore

### What was wrong

The PRD's own conclusion: *"the real risk is one line: the `dofile` in the proxy"*. `veafSpawn.lua`
loads its sub-modules for the dynamic (non-bundled) path, and forgetting one there raises nothing at
load time — the functions simply never exist, and the mission finds out when a player types the
command. `LUA_BUNDLE_SCRIPTS` has covered the static build since `veafSpawnParser.lua` was lost that
way; nothing covered the dynamic one.

### What was done

Three tests added to `test/python/veaf_build/test_lua_bundle_manifest.py`, next to the bundle guard
they complete:

| Test | What it refuses |
|---|---|
| `test_every_spawn_submodule_is_loaded_by_the_proxy` | a `veafSpawn*.lua` file on disk that the proxy never `dofile`s |
| `test_proxy_does_not_load_a_file_that_is_gone` | a `dofile` left behind after a file is renamed or removed |
| `test_proxy_order_matches_bundle_order` | the dynamic path registering command handlers in a different order from the bundle (dispatch is first-match-wins) |

The set of sub-modules is **enumerated from disk**, not from a hand-written list, so the guard covers
the next sub-module as well as the six there are today.

### Proof it can fail

Deleting the `dofile(_dir .. "veafSpawnObjects.lua")` line and running the file: **2 failed, 5
passed** — `test_every_spawn_submodule_is_loaded_by_the_proxy` and
`test_proxy_order_matches_bundle_order`. The line restored: 7 passed.

### What the measurement also showed, and the PRD did not

With that line removed, `poetry run test-lua` **fails too** — `test_veafSpawn.lua` asserts on
`veafSpawn.DEFAULT_FLAK_POWER` and on the object-spawning functions, all of which now live in
`veafSpawnObjects.lua`. So the `dofile` for *this* sub-module is no longer unguarded even without
this ticket. What stays unguarded without it is the **next** sub-module: one whose functions no Lua
test happens to touch would be dropped from every dynamic build in silence. The guard names the
invariant instead of relying on a test suite that covers it by accident.

### Definition of done

- [x] A test fails when a sub-module is not loaded by the proxy
- [x] The test was shown red, and green again once restored
- [x] Python quality gate clean (ruff check, ruff format, mypy)

---
