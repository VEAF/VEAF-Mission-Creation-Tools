# 02 — Fail loudly instead of crashing on an unstarted CTLD

Status: ✅ done 2026-08-16 — the guard went into the shared predicate, closing all 9 call sites rather than the 1 reported
Type: fix
Files: `src/scripts/veaf/veaf.lua`, `veafAssets.lua`, `veafGrass.lua`, `veafSpawnAircraft.lua`,
`veafSpawnEffects.lua`, `veafSpawnGround.lua`, `test/lua/dcs_mocks.lua`, `test/lua/test_veaf.lua`,
`test/lua/test_veafSpawn.lua`

## The change

`veafSpawn.spawnFob` already refuses to build when CTLD is absent or its module is disabled. It does
not cover the third state this lot uncovered: **CTLD present, module enabled, engine never started**.
In that state the function walks straight into `CTLDZoneManager.getInstance()` and the mission maker
gets `CTLD.lua:9109: attempt to perform arithmetic on local 'interval' (a nil value)` — a stack trace
pointing inside a vendored script, naming nothing that would let them find the cause.

The probe is `CTLDConfig.get().isLoaded`, the flag `ctld.initialize()` sets when it loads the
configuration: it is the exact condition the crash depends on, unlike a proxy such as "does the radio
menu exist".

## The whole family, not just the reported call

The ticket was written against `spawnFob`, the path in Tripack's log. Enumerating the predicate
showed it is **not** the only door: `ctld and veaf.isEnabled("ctld")` appears **9 times in 5 files**
(`veafAssets` ×2, `veafGrass` ×2, `veafSpawnAircraft` ×2, `veafSpawnEffects` ×1, `veafSpawnGround`
×2), each guarding a call into a CTLD manager and each crashing the same way. Guarding only the
reported one would leave eight identical traps armed, so the third condition goes into the shared
predicate instead: `veaf.isCtldReady()` replaces all nine, and logs the actionable message.

> CTLD is loaded but was never initialized - rebuild the mission with an up-to-date veaf-tools,
> or add [if ctld then veaf.ctld_initialize() end] to its mission-script.lua

## Why here and not in `CTLD.lua`

`CTLD.lua` is vendored verbatim (ADR 0016) and the same hole exists upstream — ticket 03 reports it.
Guarding on the VEAF side protects our own callers now, whatever upstream decides.

## Tests

- `veaf.isCtldReady()`: the nominal case plus each of the three ways to fail, and the log line an
  unstarted engine produces (a silent `false` would send the mission maker to their `mission.yaml`,
  so the message is part of the contract).
- `spawnFob` with CTLD loaded but never started: returns nil **and** touches no CTLD manager.
- CTLD initialised: every existing CTLD test keeps passing — which is why the `CTLDConfig` mock
  starts with `isLoaded = true`, and `dcs_mocks.reset()` restores it.

## Done when

The Lua suite passes, and the failure mode of a mission built by an older veaf-tools is a readable
VEAF error line instead of a vendored stack trace.
