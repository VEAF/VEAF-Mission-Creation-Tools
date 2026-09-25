# 09 — Propagate `silent` and displace refused units rather than dropping them

Status: 🔄 in-progress
Type: fix

## Two defects, one ticket

**Defect A -- `silent` ignored in `_createDcsUnits`.** `validateSpawnPosition` is called with
`silent = false` hard-coded, so a scripted (silent) spawn that drops a unit in water still broadcasts
the error message to all players. Observed in the log: `_spawn samgroup, defense 4` (silent combat
zone activation) emitted player-visible messages for each Strela that fell in the Elbe.

**Defect B -- refused units are silently dropped.** When `validateSpawnPosition` fails (unit on
water), the unit is skipped without attempting a recovery. A 14-unit battery spawned as 11 units with
no indication that three were lost.

## What this ticket does

- **Defect A**: `_createDcsUnits` gains a `silent` parameter (6th, optional, default nil/false).
  All 6 callers in `veafSpawnGround.lua` are updated to pass their own `silent`.
  `validateSpawnPosition` is called with that value instead of `false`.
- **Defect B**: ticket 08's `settlePosition` is called before `validateSpawnPosition` in
  `_createDcsUnits`. If after settling `checkPositionForUnit` still fails, the unit is logged at
  info and skipped (same as today but after best-effort displacement).

Note: `doSpawnGroup` and `veafCasMission.placeGroup` already handle `settlePosition` in ticket 08.

## Definition of done

- [ ] `_createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest, silent)` -- 6 callers updated
- [ ] `validateSpawnPosition` called with the propagated `silent`
- [ ] `settlePosition` called before `validateSpawnPosition` in `_createDcsUnits`
- [ ] Tests: silent spawn emits no player message on unit refusal; non-silent spawn still does
- [ ] `stylua --check` and `luacheck` clean
