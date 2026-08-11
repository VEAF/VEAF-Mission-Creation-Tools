# Lot FIX-LUA-RUNNER-VERSION-CHECK — `test-lua` silently ran on the wrong interpreter

Status: ✅ done

**Goal**: `veaf_build/lua_tests.py` `_find_lua()` tried `lua5.1`, then fell back to plain `lua`
— **without ever asking what version that is**. On a Windows workstation where scoop provides `lua`
as 5.4, `poetry run test-lua` ran the whole suite on an interpreter the VEAF scripts do not target,
and reported the resulting breakage as test failures.

**Branch**: `fix/lua-runner-version-check` → [#654](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/654) → `develop`

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | Verify the interpreter version | fix | ✅ |

## What it cost, measured

**34 tests failed across 6 suites on a clean checkout.** CI installs `lua5.1`, so it stayed green
there — which is exactly why this went unnoticed.

- `unpack` was removed in 5.2 (it is `table.unpack`) → breaks `veaf.safeCall`, 2 errors in
  `test_veaf.lua`
- `string.format('%d', …)` rejects a fractional number since 5.3 → breaks `veafUnits.lua`,
  `veafSpawnEffects.lua`, `veafSpawnAircraft.lua` and others

And it was **intermittent**: `veaf.lua` calls `math.randomseed(os.time())` at load, so the heading
through `mist.utils.toDegree` lands fractional on roughly 40 % of runs and `traceGroup`'s `%03d` then
errors. Measured 5 green / 3 red over 8 runs **at constant code** — `test_veafUnits.lua` looked flaky.

A runner reporting "34 failures" when the real answer is "you have the wrong interpreter" costs
whoever hits it a debugging session on code that is not broken. It happened during
`FEAT-SCENERY-AWARE-SPAWN` (PR #653): a suite flipping red had to be proved *not* to be a regression
before that lot could land.

## What shipped

`_find_lua()` verifies every candidate with `lua -v` and returns only an interpreter reporting Lua
5.1. When none does, it fails with what it found and how to install the right one:

```
No Lua 5.1 interpreter available.

Found, but not Lua 5.1:
  lua -> Lua 5.4.8  Copyright (C) 1994-2025 Lua.org, PUC-Rio
```

`lua51` joins the candidate list — it is the shim `scoop install lua51` creates, and the one that
survives when a 5.4 is also installed. The Windows fallback path is version-checked like the rest, and
a candidate that cannot be executed at all is rejected rather than crashed on.

**The Lua sources were not touched.** DCS runs Lua 5.1 and that is the only target; making
`veaf.safeCall` 5.4-compatible would have been fixing the wrong thing. The defect was the runner's
silent fallback, nothing else.

The refusal path was verified live on the 5.4-only machine — the message above is real output. The
green-suite-under-5.1 path was left to CI's `lua-unit-tests` job, because **David declined the local
`scoop install lua51`**: the package declares a `lua` shim, so installing it would have replaced the
`lua` of any other Lua installed through scoop, for a one-off check.

## Out of scope

- Making the VEAF Lua sources run under 5.4 — wrong target, see above.
- `test_veafUnits.lua`'s "flakiness": a symptom of the wrong interpreter, not a defect of the suite.
  Under 5.1, `%03d` accepts the value whatever the seed.

> **Later note (2026-08-11)**: Lua 5.1.5 *is* installed on `DAVID-BUREAU` now
> (`C:\Program Files (x86)\Lua\5.1`), and the 36 suites run locally. Any lot PRD from early August
> claiming "the Lua unit tests cannot run on this machine" is stale — `TOOLING-DOC-AUTOGEN`'s does.
