# 01 — Count the three mechanisms, from the sources rather than from one mission

Status: ✅ done

Type: chore · Files: `src/python/veaf-tools/veaf_libs/lua_module_scanner.py`

The PRD's first task, and the one it says is not established: **which modules the generator calls, and
in what order**. Its own figures came from one built mission, and the generator emits a call only for a
module the mission enables — so an inventory from a single `.miz` is a sample.

## What was done

`scan_module_initialisation(lua_dir)` reads every `veaf*.lua` carrying a `<table>.Id = "…"` line and
reports, per module: whether it calls `veaf.registerModule`, at which declared order, whether the
initFn is an inline closure, whether the file defines an `initialize()` and with what parameters, and
whether it calls that `initialize()` itself at load time.

Two parsing traps were paid for on the way, and both are pinned by tests:

- **Closures.** Four registrations pass `function() … end` instead of a function reference. A regular
  expression tight enough to skip a closure body drops them silently — which is how a first count
  reported 23 registered modules where there are 31.
- **Comment blocks.** `veafAirbases.lua` and `veafWeather.lua` each keep a `--[[ … ]]` scratch block
  holding a top-level `veafAirbases.initialize()`. Scanning raw text reports two self-initialising
  modules that do no such thing.

## Definition of done

- [x] The census is derived from the sources, not from a built mission
- [x] Closure registrations are counted
- [x] Commented-out calls are not counted
- [x] The parser's own count is checked against a raw text search of the tree
