# CHORE-INIT-REGISTRY-TELLS-THE-TRUTH — make the module registry describe what actually happens

Status: ✅ done · archived 2026-09-28

David's call, 2026-09-01, on route (a) of
[`FIX-PER-MODULE-LOGLEVEL-INERT`](../FIX-PER-MODULE-LOGLEVEL-INERT/PRD.md), split in two so the risky
half is taken with the facts in hand.

**This lot changes no behaviour.** It makes the registry an accurate description of today's
initialisation, and locks that with a test. The switch — having the generated config call
`veaf.initialize()` — is the second lot, and it becomes a decision rather than a bet.

## Why it is needed before the switch

There are **three** mechanisms, not two:

1. `veaf.registerModule(id, initFn, defaults, order)` — a registry nothing reads, because
   `veaf.initialize()` is never called.
2. The generated `veaf-config.lua`, which calls modules one by one, in its own order, sometimes with
   arguments, and **only for the modules the mission enables**.
3. Self-initialisation at load time. `veafMissionDb` does it deliberately and says why:
   *"Built at load time, not on the module init pass: other modules read the snapshot from their own
   `initialize`, and several read it from the top level of their file."*

Switching to (1) without knowing which modules rely on (2) or (3) would reorder initialisation for
most of the tree, and the failures would show up in game rather than in a test.

## What is established, and what is not

*Written before the census. The three corrections below were made when it ran — see
`docs/agents/module-initialisation.md` for the measured figures.*

Established:

- ~~**29 `veaf.registerModule` call sites**~~ → **27**, across the tree. The 29 counted the
  declaration itself, a mention inside a doc comment, and the CTLD registration (a community script,
  not a module). Of the 27, **26** were real module registrations before this lot; the census then
  found five modules the generator starts on every mission that had never registered at all, taking
  the registry to **31**.
- Declared orders run from **5** (`veafMissionDb`) to **230** (`veafRemote`), and they are
  ~~coherent~~ → coherent **among themselves**, and in wide disagreement with the order the generator
  actually uses. That disagreement is the real finding, and the second lot's input.
- Some registrations wrap their init in a closure that reads config first
  (`veafWeather`, `veafSkynet`) → **four** do: `NAMEDPOINTS`, `RADIO`, `SKYNET`, `WEATHER`. So "call
  `initFn`" is not uniformly "call `<module>.initialize()`".
- `veafMissionDb` self-initialises at load time, on purpose — so does `veafEventHandler`, and only
  those two.

**Not established, and the first thing to do**: which modules the generator calls, and in what order.
My own count came from **one built mission**, and the generator only emits a call for a module the
mission enables — so a module absent from that config may be perfectly well handled for a mission
that enables it. Any inventory built from a single `.miz` is a sample, not the answer. Read
`lua_config_generator.py`.

*Answered by ticket 01, from the sources: the generator calls every scanned module the mission
enables — those with a place in `_MODULE_INIT_ORDER` at that position, the rest from an unordered
bucket just before `INTERPRETER`.*

## Scope

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | [Count the three mechanisms, from the sources rather than from one mission](CHORE-INIT-REGISTRY-TELLS-THE-TRUTH.md) | none — read-only census | ✅ |
| 02 | [Register the five modules the generator already starts](CHORE-INIT-REGISTRY-TELLS-THE-TRUTH.md) | low — writes to an inert registry, proven by identical Lua and generator output | ✅ |
| 03 | [A test that fails when the two lists drift apart again](CHORE-INIT-REGISTRY-TELLS-THE-TRUTH.md) | none — new test | ✅ |
| 04 | [The table, and every divergence explained](CHORE-INIT-REGISTRY-TELLS-THE-TRUTH.md) | none — doc and comments | ✅ |

## Definition of done

- [x] A single table, in the repository, listing every VEAF module and, for each: does it register,
      does the generator call it, does it self-initialise, and in what order each of those happens
      — `docs/agents/module-initialisation.md`, 37 rows, read back by the test
- [x] Every divergence explained — deliberate ones written down where the code is (as `veafMissionDb`
      already does), accidental ones fixed by making the registry match reality. Two accidental ones
      are recorded rather than fixed, because fixing them changes generated output: `COMMANDS` /
      `MISSIONDB` holding no place in `_MODULE_INIT_ORDER`, and `veafI18n.initialize()` being emitted
      for a function that does not exist. Both are pinned so the fix cannot land silently.
- [x] **A test that fails when the two lists drift apart again.** It is the deliverable that outlives
      this lot: without it the table is accurate for a week —
      `test/python/veaf_libs/test_module_init_registry.py`, proven to fail in both directions
- [x] `enable` defaults and declared order reflect what happens **today** — this lot does not change
      when anything initialises. Read as a constraint on the five registrations added, not as a
      mandate to renumber: the registry's total order and the generator's disagree across the tree,
      and reconciling them *is* the reordering the second lot exists to take, with the diff now
      written down.
- [x] No behaviour change, and the Lua suite proves it: same tests, same results, before and after —
      45 suites, byte-identical output, and the generated `veaf-config.lua` for a mission enabling
      every module is byte-identical too

## Out of scope

- Calling `veaf.initialize()`. That is the second lot, and it needs this one's table to be safe.
- The per-module `logLevel` itself. It stays broken until the switch — the workaround is
  `global_log_level`, which reaches the logger by another path and works.

---

## Tickets, in full

## 01 — Count the three mechanisms, from the sources rather than from one mission

Status: ✅ done

Type: chore · Files: `src/python/veaf-tools/veaf_libs/lua_module_scanner.py`

The PRD's first task, and the one it says is not established: **which modules the generator calls, and
in what order**. Its own figures came from one built mission, and the generator emits a call only for a
module the mission enables — so an inventory from a single `.miz` is a sample.

### What was done

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

### Definition of done

- [x] The census is derived from the sources, not from a built mission
- [x] Closure registrations are counted
- [x] Commented-out calls are not counted
- [x] The parser's own count is checked against a raw text search of the tree

---

## 02 — Register the five modules the generator already starts

Status: ✅ done

Type: chore · Files: `src/scripts/veaf/veafUnits.lua`, `src/scripts/veaf/veafTime.lua`,
`src/scripts/veaf/veafCacheManager.lua`, `src/scripts/veaf/veafMarkers.lua`,
`src/scripts/veaf/veafSkynetIadsMonitor.lua`

Five modules hold a place in the generator's `_MODULE_INIT_ORDER` and are initialised on every mission
that enables them, yet never call `veaf.registerModule`: `UNITS`, `TIME`, `CACHE`, `MARKERS`,
`SKYNET_MONITOR`. Four of the five are `MANDATORY_MODULES`, so they are on in every mission.

Nobody noticed because nothing reads the registry — and because all five `initialize()` functions are
no-ops that log one line. Their real start-up happens at load: `veafMarkers` installs its DCS event
handler, `veafUnits` fills its tables, the rest are pure helpers.

That is exactly the shape of gap this lot exists to close: after the switch, `veaf.initialize()` would
silently skip five modules the generated config calls today.

### What was done

One `veaf.registerModule` per file, `{ enable = true }`, with the reason in place. Orders 1–4 for the
infrastructure tier (`UNITS`, `TIME`, `CACHE`, `MARKERS`) and 225 for `SKYNET_MONITOR`, just after
`veafSkynet` (220) which it monitors.

The orders cannot be wrong, and the comments say why: none of these five has start-up work to order.
Picking a number that mirrors the generator's own position was not possible for any of them — the two
orders disagree across the whole tree, which is recorded in `docs/agents/module-initialisation.md` as
the second lot's input.

### Why this changes no behaviour

`veaf.registerModule` writes two things: `veaf.modules[id]`, read only by `veaf.initialize()` — which
nothing calls — and `veaf.config[id].enable = true`. The only readers of `veaf.config[<module id>]`
are `veaf.isEnabled`, which already returns `true` for a module with no config, and the four
config-reading closures, each for its own ID. None of the five is one of them.

### Definition of done

- [x] The five modules register, with the reason for their order written where the call is
- [x] `poetry run test-lua` gives byte-identical output before and after
- [x] The generated `veaf-config.lua` for a mission enabling every module is byte-identical

---

## 03 — A test that fails when the two lists drift apart again

Status: ✅ done

Type: chore · Files: `test/python/veaf_libs/test_module_init_registry.py`

The deliverable that outlives the lot. Without it the table is accurate for a week.

The test has to be on the Python side: it is the only place where both lists are visible at once — the
Lua registry is read from the sources, `_MODULE_INIT_ORDER` is a Python constant, and a Lua test can
see neither the generator nor the file tree.

### The rules it enforces

1. A module in `_MODULE_INIT_ORDER` **must** register, unless it defines no `initialize()` at all
   (`_NO_INIT_MODULES`). No exception list — the rule is derivable.
2. A module that registers **must** hold a place in `_MODULE_INIT_ORDER`, or be named in
   `UNORDERED_BY_DESIGN` with its reason in the doc.
3. `UNORDERED_BY_DESIGN` must hold no stale entry.
4. `_NO_INIT_MODULES` must name exactly the listed modules with no `initialize()`.
5. A module in neither mechanism is never initialised at all: it must be declared in
   `LIBRARY_MODULES`.
6. Self-initialising at load is a deliberate exception and must stay a declared one.
7. The table in `docs/agents/module-initialisation.md` is read back and compared, row by row, against
   the scan and the generator.

### Proof it can fail

Both directions were exercised on `GEO`, then reverted:

- adding `veaf.registerModule(veafGeo.Id, …)` with no generator counterpart →
  `test_every_registered_module_has_a_place_in_the_generator_order`,
  `test_modules_in_neither_mechanism_are_the_known_libraries` and `test_every_row_matches_the_sources`
  fail;
- adding `"GEO"` to `_MODULE_INIT_ORDER` with no registration →
  `test_every_module_the_generator_initialises_registers` and the same two others fail.

### Definition of done

- [x] Fails when a `registerModule` is added without its generator counterpart
- [x] Fails when a generator entry is added without its registration
- [x] Fails when the documented table stops describing the code
- [x] Every failure message names what to do about it

---

## 04 — The table, and every divergence explained

Status: ✅ done

Type: doc · Files: `docs/agents/module-initialisation.md`, `src/scripts/veaf/veaf.lua`,
`src/scripts/veaf/veafAirWaves.lua`, `src/scripts/veaf/veafCommands.lua`,
`src/scripts/veaf/veafMissionDb.lua`, `src/python/veaf-tools/veaf_libs/lua_config_generator.py`

### Where the table lives, and why there

`docs/agents/module-initialisation.md`, beside `dcs-coordinates.md` — the directory `CLAUDE.md` already
sends an agent to before it writes code that can be wrong in a way tests do not catch. Thirty-seven
rows do not belong in a source comment, and `doc/` is the mission-maker site: nothing here is
mission-maker facing.

The two places where the mistake actually gets made carry a pointer instead of a copy:
`veaf.registerModule`'s docstring in `veaf.lua`, and `_MODULE_INIT_ORDER` in
`lua_config_generator.py`. Each says the one thing that is invisible from where it sits — that the
registry is inert, and that the generator's list is what really orders a mission.

The table is **read back by the test**, so it cannot go stale on its own.

### The divergences

Deliberate, written down where the code is:

- `AIRWAVES` — in the generator's order, never registers: it has no `initialize()`; a mission declares
  `VeafAirWaveZone` chains and there is nothing global to start.
- `GEO`, `I18N`, `MATH`, `SCHEDULER`, `SPAWNER` — in neither list: libraries that publish onto
  `veaf.*` at load.
- `EVENTS`, `MISSIONDB` — self-initialise at load, then again from the generated config.
  `veafEventHandler` guards its DCS registration against exactly that; `veafMissionDb` already
  explained itself and now also says what the second call is.
- `UNITS`, `TIME`, `CACHE`, `MARKERS` at orders 1–4 — see ticket 02.

Accidental, recorded and deliberately not fixed here because the fix changes generated output:

- `COMMANDS` (15) and `MISSIONDB` (5) hold no place in `_MODULE_INIT_ORDER`, so the generator calls
  them from its unordered bucket, near-last. `veafCommands.lua`'s comment claimed the opposite and now
  says what happens.
- `veafI18n` has no `initialize()` and is not in `_NO_INIT_MODULES`, so a mission that enables `I18N`
  gets a call to a nil value. Pinned by an assertion so the fix must come with a doc update.

### Definition of done

- [x] One table, in the repository, covering all 37 modules across the three mechanisms
- [x] Every divergence labelled deliberate or accidental, with its reason
- [x] Deliberate ones written where the code is, as `veafMissionDb` already did
- [x] The registry/generator order disagreement recorded in full, as the second lot's input

---
