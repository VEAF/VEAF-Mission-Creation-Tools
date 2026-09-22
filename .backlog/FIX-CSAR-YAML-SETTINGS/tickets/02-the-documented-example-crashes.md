# 02 — The documented example must not crash

Status: ⬜ ready

## What is wrong

The YAML-first CSAR example in `doc/mission-maker/GUIDE.md` (and its `.en.md` twin) reads:

```yaml
modules:
  CSAR:
    enabled: true
    settings:
      enableAllslots: true
      useprefix: true
      csarPrefix: "MEDEVAC"
```

`CSAR.lua:32` defaults `csarPrefix` to a **table**, and `CSAR.lua:1916` iterates it with `pairs`
inside the `csar.useprefix == true` branch — the branch this very example turns on. A string there
raises, measured on Lua 5.1.5:

```
bad argument #1 to 'pairs' (table expected, got string)
```

Copying the documented block is enough to break CSAR at runtime.

## What done means

- The example uses a value CSAR can consume. After ticket 01 that is a YAML list
  (`csarPrefix: ["helicargo", "MEDEVAC"]`); if 01 lands differently, the example drops `csarPrefix`
  rather than showing a form that raises.
- A test covers it. A doc example that raises is a defect the doc build cannot see, so the guard
  belongs in the test suite: feed the documented block through the generator and run the generated
  assignments against the CSAR mocks, asserting the prefix branch survives.
- Both language versions change together, and the support bot's page index is refreshed if titles
  move (`services/support-bot/scripts/refresh_doc_pages.py`).

## Note

Check the same pattern for the other two documented examples, `enableAllslots` and `useprefix`:
both are plain booleans in `CSAR.lua`, so they are fine — but check rather than assume, because
this ticket exists precisely because an example was never run.
