---
Status: ✅ done
---

# FIX-WELCOME-BRIEF-EVENT-INITIATOR — the welcome brief never fired on a server

## The defect

Reported 2026-08-26: no welcome brief on a dedicated server, on a mission built with 6.16.0 — the
release that introduced the feature.

`veafEventHandler` does not hand callbacks a DCS object. `transformEvent` replaces the initiator
with the **data table** `completeUnitFromName` returns: `unitName`, `unitType`, `unitCoalition`, …
and no methods. `veafWeather.onPlayerEnterUnit` read the other shape:

```lua
local dcsUnit = event and event.initiator
if not dcsUnit or not dcsUnit.getName then
  return                       -- always taken, for any slot declared in the mission
end
```

So the handler returned on every event it received — **before its own log line**, which is why the
symptom was total silence rather than an error. Only a dynamic-slot unit, which has no mist table
entry and so arrives as a raw DCS object, would have passed.

## How it was diagnosed

Statically, from the mission and the server log, without a running DCS:

- the bundled scripts were 6.16.0 and contained the whole feature (subscription, sweep, 5 s delay);
- the module was enabled and `veafWeather.initialize()` was called with no argument, so the brief was
  on by default;
- every module initialised *after* it logged, so nothing raised — the subscription was in place;
- the pilot had flown (take-off, then killed 23 minutes later);
- and in **three sessions** the log carried not one `welcome brief` line, although that line is
  deliberately `INFO` for exactly this question.

That combination leaves only a silent early return in the handler, which the code confirms.

`veafQraCore` and `veafGrass` read `initiator.unitName` first and fall back to `:getName()` — the
same logic, inline, in both. The brief kept only the fallback.

## Fix

`veafEventHandler.unitNameFromEvent(event)`: the data table's `unitName` first, `:getName()` as the
dynamic-slot fallback, nil when neither. The three callers now share it instead of carrying a third
and fourth copy.

## Why the tests did not catch it

They handed the handler a DCS object mock, with `getName` — a shape the event handler never
produces. Passing the runtime shape makes the two new tests fail on the old code (`expected: 1,
actual: 0`, verified by reverting the fix), and the object-mock tests are kept: that is exactly what
a dynamic-slot unit looks like, and both paths must work.

A comment in `test_veafWeather.lua` stated that the timing of the event was the whole problem. It
was not, and the sweep added on that belief is what made the feature look healthy in single player.
The note is corrected rather than removed: it explains why this shipped.

## Definition of done

- Both initiator shapes brief the pilot; neither-name is ignored without crashing.
- The three modules share one helper.
- `poetry run test-lua` green (37 suites), `stylua --check` clean, luacheck via CI.
- `CHANGELOG.md` entry, version bump with both agent manifests.
