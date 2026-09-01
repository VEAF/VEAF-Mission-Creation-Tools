# FIX-PER-MODULE-LOGLEVEL-INERT — a documented setting that has never done anything

Status: ⬜ ready

Found 2026-09-01 while trying to trace one module during the release-gate session. Setting
`logLevel: trace` under a module changed nothing, and the reason is not the module.

## What was measured

The session mission was built with `logLevel: trace` under `SPAWN`, and the generated config carries
it:

```lua
veaf.setConfig("SPAWN", "logLevel", "trace")
```

DCS loaded that mission at **18:11:11 UTC**, two minutes after the `.miz` was built at **18:09:15
UTC** — checked by the clock rather than assumed, since the log writes UTC and the file system
writes local time. And still:

- **zero** `VEAF-SPAWN|T|` lines;
- **zero** `Module [X] log level forced to [Y]`, the line the applying loop writes.

## Why

`veaf.setConfig` only stores the value:

```lua
function veaf.setConfig(moduleId, key, value)
  veaf.config[moduleId][key] = value
end
```

The loop that pushes it into the logger lives inside **`veaf.initialize()`** (`veaf.lua:6128`). And
`veaf.initialize()` is **never called** — not by the generated `veaf-config.lua`, which calls each of
the twenty-three modules directly, nor anywhere in `src/scripts/` or `test/`.

Its own docstring already suspected as much: *"simply ignored if veaf.initialize() is never called"*.

## It is wider than the log level

**29 `veaf.registerModule` calls across 27 files** feed a registry that nothing reads at runtime. With
`veaf.initialize()` uncalled, three declared features never happen:

| Declared | What happens today |
|---|---|
| per-module `logLevel` | never applied — this defect |
| declared init order (`order` argument) | the generator's own order decides |
| `enable` flag via `veaf.isEnabled` | 4 call sites, fed by defaults the registry never merges |

So there are **two initialisation mechanisms**, and the one the Lua side documents is the dead one.

## The decision this lot needs

Two routes, and they are not equivalent:

- **a — call `veaf.initialize()`** from the generated config instead of listing modules. The registry
  becomes real: order, enable and logLevel all start working. But the generator currently decides the
  order and passes per-module arguments (`veafRadio.initialize(true)`, `veafNamedPoints.initialize({})`),
  so this is a change of contract, not a one-liner.
- **b — apply the logLevel where it is set.** Make `veaf.setConfig` push a `logLevel` straight into
  the logger, and leave the registry as it is. Small, honest, and it fixes what a mission maker
  actually asked for — but it leaves 29 registrations pretending to do something.

**Whichever is chosen, the dead half must stop pretending.** If the registry stays unused, say so
where it is declared, or delete it.

## Definition of done

- [ ] `logLevel: trace` under a module produces trace lines from that module and from no other
- [ ] A test asserts it end to end: config in, logger level out — not that `setConfig` stored a value
- [ ] The other two registry features are either made real or documented as inert **in the code**
- [ ] `doc/mission-maker/GUIDE.md` line ~999 (*"surchargez-le par module avec `logLevel`"*) matches
      what happens, in both languages
- [ ] The global level keeps working: it reaches the logger by another path (`veaf.ForcedLogLevel`,
      read inside `Logger:setLevel`) and is what made this session's diagnosis possible at all

## Why it matters more than it looks

A mission maker chasing one module's behaviour has to turn **everything** to trace. During this
session that meant 20 000 log lines to answer one question about the CAP watchdog — and the first
conclusion drawn from the quiet log was **wrong**, because the absent lines were read as absent
behaviour rather than as an absent log level.
