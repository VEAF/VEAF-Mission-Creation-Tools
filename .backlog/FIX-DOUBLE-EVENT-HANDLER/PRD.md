---
Status: ✅ done
---

# FIX-DOUBLE-EVENT-HANDLER — every DCS event was delivered to VEAF twice

## The defect

`veafEventHandler.initialize()` ends with `world.addEventHandler(veafEventHandler.eventHandler)`, and
it runs **twice on every mission**:

1. the script initialises itself on load (last line of `veafEventHandler.lua`), so a mission that
   generates no `veaf-config.lua` still handles events;
2. the generated `veaf-config.lua` initialises each module in turn, this one included.

Both calls are deliberate. What was not is that each one registered the handler again — so DCS
delivered every event twice, and every callback behind it ran twice: two radio menu rebuilds on a
birth, two QRA evaluations, two FARP warehouse refills.

Found while diagnosing an unrelated report, and visible in that server log as two lines per session:

```
18:38:43.067  VEAF-EVENTS|I|?|22085: loaded /INFO             (script load)
18:38:44.730  VEAF-EVENTS|I|initialize|22085: loaded /INFO    (veaf-config.lua)
```

The log proves the double *initialisation*; the double *registration* is proven by the test, which
counts the calls: **expected 1, actual 2** before the fix.

## Why it stayed invisible

Every consumer that would have shown it has an idempotence guard of its own — the welcome brief's
`briefedUnits`, the QRA's state machine — so the second delivery is usually swallowed. It surfaces
only where no guard exists, which is exactly the kind of defect that gets attributed to DCS.

## Fix

A registration flag in `initialize()`. Guarded there rather than by deleting one of the two calls:
each covers a case the other does not, and a third caller would reintroduce the defect. The rest of
`initialize()` still runs every time — the events map is rebuilt, and a test holds that.

## Scope check

Enumerated rather than sampled: three modules self-initialise at load
(`veafAirbases`, `veafEventHandler`, and `veafWeather` calling `veafAirbases`).
`veafAirbases.initialize` already guards on `if veafAirbases.Airbases then return end`, so
`veafEventHandler` was the only one with a repeatable side effect.

## Definition of done

- A second `initialize()` registers nothing; a first one registers once.
- The events map is still rebuilt on every call.
- `poetry run test-lua` green, `stylua --check` clean, luacheck via CI.
