# Lot FIX-LUA-RUNNER-VERSION-CHECK — `test-lua` silently runs on the wrong interpreter

Status: ✅ done
Branch: `fix/lua-runner-version-check`

## Problem Statement

`veaf_build/lua_tests.py` `_find_lua()` tried `lua5.1`, then fell back to plain `lua` — **without
ever asking what version that is**. On a Windows workstation where scoop provides `lua` as 5.4,
`poetry run test-lua` therefore ran the whole suite on an interpreter the VEAF scripts do not
target, and reported the resulting breakage as test failures.

Measured on this machine (`lua -> C:\Users\…\scoop\shims\lua.exe`, Lua 5.4.8):

- `unpack` was removed in 5.2 (it is `table.unpack`) → breaks `veaf.safeCall`
  (`src/scripts/veaf/veaf.lua:3102`), 2 errors in `test_veaf.lua`
- `string.format('%d', …)` rejects a number with a fractional part since 5.3 → breaks
  `veafUnits.lua:108`, `veafSpawnEffects.lua`, `veafSpawnAircraft.lua` and others

**34 tests fail across 6 suites on a clean checkout.** CI installs `lua5.1`, so it is green there,
which is why this went unnoticed.

Worse, the failure is **intermittent**: `veaf.lua` calls `math.randomseed(os.time())` at load, so
the heading passed through `mist.utils.toDegree` lands on a fractional value on roughly 40 % of
runs, and `traceGroup`'s `%03d` then errors. Measured 5 green / 3 red over 8 runs at constant code —
`test_veafUnits.lua` looks flaky.

## Why it matters

A test runner that reports "34 failures" when the real answer is "you have the wrong interpreter"
costs whoever hits it a debugging session on code that is not broken. It happened during
FEAT-SCENERY-AWARE-SPAWN (PR #653): a suite flipping red had to be proved *not* to be a regression
before the lot could land. The intermittency makes it worse — a run that passes hides the problem
until the next one.

## Solution

`_find_lua()` **verifies the version** of every candidate with `lua -v` and returns only an
interpreter reporting Lua 5.1. When none does, it fails with what it found and how to install the
right one, instead of running the suite on something incompatible:

```
No Lua 5.1 interpreter available.

Found, but not Lua 5.1:
  lua -> Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio
…
```

`lua51` joins the candidate list (`lua5.1`, `lua51`, `lua`) — it is the shim
`scoop install lua51` creates, and the one that survives when a 5.4 is also installed. The Windows
fallback path is version-checked like the rest.

**The Lua sources are not touched.** DCS runs Lua 5.1 and that is the only target; making
`veaf.safeCall` 5.4-compatible would be fixing the wrong thing. The defect is the runner's silent
fallback, nothing else.

Documentation gains the scoop trade-off, which is real: the `lua51` package declares a `lua` shim,
so installing it replaces the `lua` of any other Lua already installed through scoop. The `lua51`
shim keeps both reachable, and the runner now knows that name.

## Definition of Done

- [x] `_find_lua()` version-checks each candidate and refuses anything that is not 5.1
- [x] `lua51` in the candidate list; Windows fallback path version-checked too
- [x] a candidate that cannot be executed at all is rejected, not crashed on
- [x] unit tests in `test/python/veaf_build/test_lua_interpreter_check.py`
- [x] `doc/TESTING.md` + `.en.md` and `doc/developer/GUIDE.md` + `.en.md` updated (both languages)
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` + `plugin/.claude-plugin/plugin.json`
- [x] refusal path verified live on the 5.4-only machine (the message in *Solution* is real output)
- [x] green-suite-under-5.1 path left to CI's `lua-unit-tests` job — **David declined the local
      `scoop install lua51`**, which would have replaced his `lua` shim for a one-off check

## Out of Scope

- Making the VEAF Lua sources run under 5.4 — see above, wrong target.
- The `test_veafUnits.lua` "flakiness": it is a symptom of the wrong interpreter, not a defect of
  the suite. Under 5.1, `%03d` accepts the value whatever the seed.
