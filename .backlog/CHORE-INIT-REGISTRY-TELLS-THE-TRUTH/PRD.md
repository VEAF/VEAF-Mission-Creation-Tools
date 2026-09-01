# CHORE-INIT-REGISTRY-TELLS-THE-TRUTH — make the module registry describe what actually happens

Status: ✅ done

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
| 01 | [Count the three mechanisms, from the sources rather than from one mission](tickets/01-count-the-three-mechanisms.md) | none — read-only census | ✅ |
| 02 | [Register the five modules the generator already starts](tickets/02-register-what-the-generator-already-starts.md) | low — writes to an inert registry, proven by identical Lua and generator output | ✅ |
| 03 | [A test that fails when the two lists drift apart again](tickets/03-a-test-that-fails-when-they-drift.md) | none — new test | ✅ |
| 04 | [The table, and every divergence explained](tickets/04-the-table-and-the-divergences.md) | none — doc and comments | ✅ |

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
