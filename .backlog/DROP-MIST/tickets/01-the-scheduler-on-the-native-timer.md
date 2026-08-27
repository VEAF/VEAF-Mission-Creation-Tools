# 01 — The scheduler on the native timer

Status: ⬜ ready
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

## Definition of done

- [ ] `veafScheduler.lua` exists, with `veaf.scheduleFunction` / `veaf.removeFunction` façades in
      `veaf.lua`
- [ ] All 85 call sites migrated; `grep -E 'mist\.(scheduleFunction|removeFunction|addEventHandler|removeEventHandler)' src/scripts/veaf/` returns nothing
- [ ] Lua tests covering: a one-shot task, a repeating task, `st` stopping a repeat, removal before
      first run, removal of an unknown id, and **a task that raises — the chain survives and the error
      is logged**
- [ ] The event-handler question is settled explicitly: native `world.*` or `veafEventHandler`, with
      the reason recorded
- [ ] `stylua --check` and `luacheck` clean
