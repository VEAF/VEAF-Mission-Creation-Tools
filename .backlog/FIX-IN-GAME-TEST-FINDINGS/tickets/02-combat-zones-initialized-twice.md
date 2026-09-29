# 02 — Every combat zone is initialized twice

Status: ✅ done — 2026-09-29
Type: fix
Files: `src/scripts/veaf/veafCombatZone.lua` and/or `src/python/veaf-tools/veaf_libs/lua_config_generator.py`,
tests (Lua and generator)

## Origin

In-game test of GermanyCW-v6, 2026-09-28, with `veaf.Diagnostics = true`.

## Measured

- Each zone's startup lines appear twice in `dcs.log`, a few milliseconds apart:
  `reportGroupsExcludedByName` and `DIAG|zone combatZone_Torgau: deactivated, destroying 0
  group(s)` alike, for all 26 zones.
- Torgau, activated in game: `DIAG|zone combatZone_Torgau: activating (8 element(s), …)` for 4 real
  elements; Wünsdorf's element list, read through the bridge, holds each of its 7 elements twice.
- No double spawn was seen (counts came out right: Baumholder 3 of 5, Parchim 5 of 7), so the
  harm is noise in the log and doubled work at start — but a draw over doubled elements is one
  change away from spawning twice.

## Where it comes from

- The generated `veaf-config.lua` ends each zone's builder chain with `:initialize()`
  (`lua_config_generator.py`, 26 times in this mission).
- `veafCombatZone.AddZone(zone)` then calls `zone:initialize()` again (`veafCombatZone.lua:2821`).
- `VeafCombatZone:initialize()` sets `self.initialized = true` on entry and never returns early
  when it is already set.

## Done when

- A zone is initialized once: either the generator stops emitting `:initialize()`, or
  `initialize()` returns when already initialized — decided and written, with the other callers
  of `AddZone` (hand-written `mission-script.lua` in older missions) in mind.
- A test builds a zone through the generated chain and `AddZone`, and counts one initialization and
  unique elements.

## Done — 2026-09-29

Decided: `VeafCombatZone:initialize()` returns when the zone is already initialized. The generator
keeps its `:initialize()`: the hand-written `mission-script.lua` of older missions do the same, and
so does `VeafCombatOperation:initialize()` for its tasking zones, so only a guard in the runtime
covers every caller. `VeafCombatOperation:initialize()` gets the same guard (it deactivated
twice). Tests: the generated chain plus `AddZone` reports once, for a zone and for an operation
(red before: 2 each).
