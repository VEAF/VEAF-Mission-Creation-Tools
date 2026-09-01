# 02 — Register the five modules the generator already starts

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

## What was done

One `veaf.registerModule` per file, `{ enable = true }`, with the reason in place. Orders 1–4 for the
infrastructure tier (`UNITS`, `TIME`, `CACHE`, `MARKERS`) and 225 for `SKYNET_MONITOR`, just after
`veafSkynet` (220) which it monitors.

The orders cannot be wrong, and the comments say why: none of these five has start-up work to order.
Picking a number that mirrors the generator's own position was not possible for any of them — the two
orders disagree across the whole tree, which is recorded in `docs/agents/module-initialisation.md` as
the second lot's input.

## Why this changes no behaviour

`veaf.registerModule` writes two things: `veaf.modules[id]`, read only by `veaf.initialize()` — which
nothing calls — and `veaf.config[id].enable = true`. The only readers of `veaf.config[<module id>]`
are `veaf.isEnabled`, which already returns `true` for a module with no config, and the four
config-reading closures, each for its own ID. None of the five is one of them.

## Definition of done

- [x] The five modules register, with the reason for their order written where the call is
- [x] `poetry run test-lua` gives byte-identical output before and after
- [x] The generated `veaf-config.lua` for a mission enabling every module is byte-identical
