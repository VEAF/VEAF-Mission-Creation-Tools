# 02 — `logger:warning` does not exist

Status: ✅ done
Type: fix

## Measured

A wave whose element was not a valid command (`-spawn shilka`, the session mission's own mistake)
logged on 2026-10-03:

```
VEAF|E|safeCall: ... veaf-scripts.lua:39176: attempt to call method 'warning' (a nil value)
```

`veaf.Logger` has `warn`. `AirWaveZone._onEnterActive` called `:warning(` in the branch that reports
a failed deployment, so the report raised. The zone then logged no `check()` again: it stayed
`STATUS_ACTIVE` with nothing deployed, for the rest of the mission, until `start()` was called by
hand. One bad wave element froze its zone for good.

The same call sat in `veafSkynetIadsMonitor.lua`.

## Done

Both sites call `warn`. `test/python/test_lua_names_that_exist.py` checks that every
`veaf.loggers.get(...):m(` names a method `veaf.Logger` defines; it found exactly these two.
