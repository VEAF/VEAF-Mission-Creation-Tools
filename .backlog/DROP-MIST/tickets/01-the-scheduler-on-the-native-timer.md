# 01 — The scheduler on the native timer

Status: ✅ done — 2026-08-28
Type: refactor

85 call sites: `mist.scheduleFunction` (67), `mist.removeFunction` (16), `mist.addEventHandler` (1),
`mist.removeEventHandler` (1). Rule 1 — the native call exists — plus a thin rule 2 adapter.

## What exists

DCS provides `timer.scheduleFunction(f, arg, time)` and `timer.removeFunction(id)`. MiST deliberately
does **not** wrap them: [`mist.lua:2091`](../../../src/scripts/community/mist.lua) calls its own
scheduler *"superior to timer.scheduleFunction"*. It maintains a task list, and `mist.main` re-arms
itself **every 0.01 s** so [`doScheduledFunctions`](../../../src/scripts/community/mist.lua) can walk
that list on every pass.

Four things the native call does not give, all four used by our 67 call sites:

| MiST parameter | What it does | Native equivalent |
|---|---|---|
| `rep` | re-run every `rep` seconds | none — the native call re-arms only if the function *returns* the next time |
| `st` | stop re-running at this mission time | none |
| — | a `pcall` so a failing task does not break the chain | none — an error kills the scheduled call |
| `vars` | arguments as a table, unpacked into the call | the native call passes **one** argument |

## What this ticket does

A `veafScheduler.lua` module holding a `timer.scheduleFunction`-backed adapter with MiST's signature,
so the 67 call sites change only their prefix:

```lua
veaf.scheduleFunction(f, vars, t, rep, st)   -- returns an id
veaf.removeFunction(id)
```

One native scheduled call **per task**, re-armed by returning the next time — not one global tick
walking a list. `rep` and `st` are the adapter's own bookkeeping; the `pcall` wraps the call so the
existing tolerance for a failing task is preserved.

The two event-handler calls go to native `world.addEventHandler` / `world.removeEventHandler`. Check
first whether they should instead route through `veafEventHandler`, which is VEAF's own dispatcher and
was just corrected in `FIX-DOUBLE-EVENT-HANDLER` — a second registration path is exactly the defect
that lot fixed, so this must not reintroduce one.

**The 100 Hz tick does not disappear here.** `mist.main` is MiST's own and keeps running while MiST is
injected. It stops at ticket 08. What this ticket removes is our *dependence* on it.

## What the migration actually found

- **Only one of the 67 call sites uses `rep` or `st`.** `veafSkynetIadsMonitor.lua:610` repeats every
  `_interval` seconds with a one-hour stop time; the other 66 are one-shots. The adapter still
  implements both, because that one call is the module's monitoring thread — but the risk this ticket
  was given is not where the count suggested.
- **`{ position, nil, nil, color }` is a real argument list** (`veafSpawnEffects.lua:150`). `#` is
  undefined on a table with holes, so the adapter measures the list with `table.maxn` — Lua 5.1's
  answer to exactly this, with a key-scan fallback for newer interpreters. Covered by a test.
- **A test was asserting the mock, not the code.** `test_veafGroundAI`'s `check()` case asserted that
  no reschedule was left behind, which held only because `mist.scheduleFunction` was a no-op returning
  nil. `GroundUnitHandler:check()` re-arms itself on every pass; the test now says so.
- **The event handler goes to native `world.*`**, following `veafMissileGuardian`. `veafEventHandler`
  registers callbacks and has no way to drop one, and this handler is armed and disarmed as Skynet
  networks come and go. `mist.addEventHandler` took a plain function and answered a numeric id, so the
  call site now builds the one-line `onEvent` table the native API wants, and
  `monitorDynamicSpawnHandlerId` was renamed `monitorDynamicSpawnHandler` — it holds a table now, not
  an id.
- **A module has five registries, not one.** `veaf_build/worker.py`'s `LUA_BUNDLE_SCRIPTS`,
  `VeafDynamicLoader.lua`, `.luacheckrc`'s globals, `test/lua/veaf_loader.lua`'s module order, and
  `doc/TESTING.md` + its English twin for the test suite. Only the first is guarded by a test; the
  suite listing is guarded by `test_docs_check`. The other three fail late or not at all.
- **The scheduler mock now records instead of swallowing.** `timer.scheduleFunction` hands back an id
  and stores the task; `dcs_mocks.runScheduled(t)` runs what is due, re-arming on a numeric return
  like DCS. `setTime` deliberately still runs nothing, so no existing suite changed behaviour.

## Definition of done

- [x] `veafScheduler.lua` exists, with `veaf.scheduleFunction` / `veaf.removeFunction` façades
- [x] All 85 call sites migrated; `grep -E 'mist\.(scheduleFunction|removeFunction|addEventHandler|removeEventHandler)' src/scripts/veaf/` returns nothing
- [x] Lua tests covering: a one-shot task, a repeating task, `st` stopping a repeat, removal before
      first run, removal of an unknown id, and **a task that raises — the chain survives and the error
      is logged** — 19 cases, and the module lands at 94.8 % line coverage
- [x] The event-handler question is settled explicitly: native `world.*`, with the reason recorded in
      the source
- [x] `stylua --check` and `luacheck` clean
