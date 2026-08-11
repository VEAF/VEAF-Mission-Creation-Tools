# 01 — Read a unit's life once, not four times

Status: ⬜ ready
Type: fix
Finding: VMR-088 (Error / bug, LOW), `src/scripts/veaf/veafCombatMission.lua:778`

## What is there

`VeafCombatMission:getRemainingEnemies` calls `veaf.getUnitLifeRelative(unit)` **four times per unit**
— the review reported three; the fourth hides inside a trace:

```lua
:trace(string.format("veaf.getUnitLifeRelative(unit) = %f", veaf.getUnitLifeRelative(unit)))  -- 781
if veaf.getUnitLifeRelative(unit) == 1.0 then                                                 -- 782
elseif veaf.getUnitLifeRelative(unit) > whatsInAKill then                                      -- 785
  :trace(string.format("unit[%s] is damaged (%d %%)", …, veaf.getUnitLifeRelative(unit) * 100)) -- 788
```

## Two problems, and the classification one is the real finding

**A unit can be classified inconsistently.** The value is read fresh for each test, and a unit under
fire changes between reads. So `== 1.0` can be false while the *next* read is back at 1.0, or a unit can
fall past `whatsInAKill` between line 782 and line 785 and land in the `else` — the branch whose own
comment says *"should never come to that"*. The counts feeding
`veaf.t("combatmission.enemies_count", …)` are then wrong, and a mission's remaining-enemies message is
exactly the kind of thing a player trusts without checking.

**And two of the four calls are made for logs that may not be emitted.** `Logger:trace` checks the level
before formatting, and `veaf.lp` defers serialisation through a `__tostring` metatable — 726 uses in the
tree get this right. These sites defeat both: they call `string.format` themselves, and the argument is a
**DCS API call**, so the work happens whatever the log level.

## Tasks

- [ ] Read it once into a local, before the branch, and use that local everywhere including the traces.
- [ ] A test that a unit whose life changes between reads is still counted exactly once — the point of
      the fix, and the part a reader will want pinned.
- [ ] Do **not** widen this to the other 794 pre-formatted calls (see the PRD).

## Acceptance criteria

- [ ] One `getUnitLifeRelative` call per unit per pass.
- [ ] `nbLiveUnits + nbDamagedUnits + nbDeadUnits` stays consistent with the group's spawned count.
- [ ] `poetry run test-lua` green.

## Worth knowing while you are in there

The `else` branch counts nothing at all — it only traces "is dead", on the assumption that dead units do
not come back from `getUnits()`. With one read that assumption becomes checkable rather than racy, so if
you make it reachable, decide deliberately whether it should increment anything.
