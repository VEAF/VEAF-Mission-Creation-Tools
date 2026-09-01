# CHORE-INIT-REGISTRY-TELLS-THE-TRUTH — make the module registry describe what actually happens

Status: ⬜ ready

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

Established:

- **29 `veaf.registerModule` call sites** across the tree (two of which are the declaration itself
  and a false positive — the real count is part of this lot's work).
- Declared orders run from **5** (`veafMissionDb`) to **230** (`veafRemote`), and they are coherent —
  someone thought about them.
- Some registrations wrap their init in a closure that reads config first
  (`veafWeather`, `veafSkynet`), so "call `initFn`" is not uniformly "call `<module>.initialize()`".
- `veafMissionDb` self-initialises at load time, on purpose.

**Not established, and the first thing to do**: which modules the generator calls, and in what order.
My own count came from **one built mission**, and the generator only emits a call for a module the
mission enables — so a module absent from that config may be perfectly well handled for a mission
that enables it. Any inventory built from a single `.miz` is a sample, not the answer. Read
`lua_config_generator.py`.

## Definition of done

- [ ] A single table, in the repository, listing every VEAF module and, for each: does it register,
      does the generator call it, does it self-initialise, and in what order each of those happens
- [ ] Every divergence explained — deliberate ones written down where the code is (as `veafMissionDb`
      already does), accidental ones fixed by making the registry match reality
- [ ] **A test that fails when the two lists drift apart again.** It is the deliverable that outlives
      this lot: without it the table is accurate for a week
- [ ] `enable` defaults and declared order reflect what happens **today** — this lot does not change
      when anything initialises
- [ ] No behaviour change, and the Lua suite proves it: same tests, same results, before and after

## Out of scope

- Calling `veaf.initialize()`. That is the second lot, and it needs this one's table to be safe.
- The per-module `logLevel` itself. It stays broken until the switch — the workaround is
  `global_log_level`, which reaches the logger by another path and works.
