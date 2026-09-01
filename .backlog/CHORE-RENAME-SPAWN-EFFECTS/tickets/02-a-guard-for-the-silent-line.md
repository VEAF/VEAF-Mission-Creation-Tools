# 02 — A guard for the one line that fails silently

Status: ✅ done
Type: chore

## What was wrong

The PRD's own conclusion: *"the real risk is one line: the `dofile` in the proxy"*. `veafSpawn.lua`
loads its sub-modules for the dynamic (non-bundled) path, and forgetting one there raises nothing at
load time — the functions simply never exist, and the mission finds out when a player types the
command. `LUA_BUNDLE_SCRIPTS` has covered the static build since `veafSpawnParser.lua` was lost that
way; nothing covered the dynamic one.

## What was done

Three tests added to `test/python/veaf_build/test_lua_bundle_manifest.py`, next to the bundle guard
they complete:

| Test | What it refuses |
|---|---|
| `test_every_spawn_submodule_is_loaded_by_the_proxy` | a `veafSpawn*.lua` file on disk that the proxy never `dofile`s |
| `test_proxy_does_not_load_a_file_that_is_gone` | a `dofile` left behind after a file is renamed or removed |
| `test_proxy_order_matches_bundle_order` | the dynamic path registering command handlers in a different order from the bundle (dispatch is first-match-wins) |

The set of sub-modules is **enumerated from disk**, not from a hand-written list, so the guard covers
the next sub-module as well as the six there are today.

## Proof it can fail

Deleting the `dofile(_dir .. "veafSpawnObjects.lua")` line and running the file: **2 failed, 5
passed** — `test_every_spawn_submodule_is_loaded_by_the_proxy` and
`test_proxy_order_matches_bundle_order`. The line restored: 7 passed.

## What the measurement also showed, and the PRD did not

With that line removed, `poetry run test-lua` **fails too** — `test_veafSpawn.lua` asserts on
`veafSpawn.DEFAULT_FLAK_POWER` and on the object-spawning functions, all of which now live in
`veafSpawnObjects.lua`. So the `dofile` for *this* sub-module is no longer unguarded even without
this ticket. What stays unguarded without it is the **next** sub-module: one whose functions no Lua
test happens to touch would be dropped from every dynamic build in silence. The guard names the
invariant instead of relying on a test suite that covers it by accident.

## Definition of done

- [x] A test fails when a sub-module is not loaded by the proxy
- [x] The test was shown red, and green again once restored
- [x] Python quality gate clean (ruff check, ruff format, mypy)
