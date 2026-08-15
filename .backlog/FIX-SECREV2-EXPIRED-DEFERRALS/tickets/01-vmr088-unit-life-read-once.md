# 01 — Read a unit's life once, not four times

Status: ✅ done
Type: fix
Finding: VMR-088 (Error / bug, LOW), `src/scripts/veaf/veafCombatMission.lua:778`

## What is there

`VeafCombatMission:getRemainingEnemies` calls `veaf.getUnitLifeRelative(unit)` up to **four times per
unit** — measured afterwards: **2 on the alive path, 4 on the damaged one**, since each branch reads
again. The review reported three; nobody had counted:

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

- [x] Read it once into a local, before the branch, and use that local everywhere including the traces.
- [x] A test that a unit whose life changes between reads is still counted exactly once — the point of
      the fix, and the part a reader will want pinned.
- [x] Do **not** widen this to the other 794 pre-formatted calls (see the PRD).

## Acceptance criteria

- [x] One `getUnitLifeRelative` call per unit per pass.
- [x] `nbLiveUnits + nbDamagedUnits + nbDeadUnits` stays consistent with the group's spawned count.
- [x] `poetry run test-lua` green.

## Worth knowing while you are in there

The `else` branch counts nothing at all — it only traces "is dead", on the assumption that dead units do
not come back from `getUnits()`. With one read that assumption becomes checkable rather than racy, so if
you make it reachable, decide deliberately whether it should increment anything.

## Delivered — 2026-08-11

One `local unitLife = veaf.getUnitLifeRelative(unit)` before the branch, used by the test, the threshold
and both traces.

**Measured, before and after**, with a counting stub in place of the DCS call:

| Unit state | Calls before | Calls after |
|---|---:|---:|
| full health | 2 | 1 |
| damaged | **4** | 1 |

So the review's "three" and my own "four" were both partly wrong: it is **two on the alive path and four
on the damaged path**, because each branch reads again. Only measuring gave the real numbers, and the fix
is the same either way.

10 tests. Three were red before the change and are the ones that matter: the call count, a unit reading
1.0 then 0.0, and a unit reading 0.5 then 1.0 — both counted exactly once now, whichever value the single
read returns.

### A truncated `head` nearly hid one

The first run looked like two failures because I piped the output through `head -12`. There were **three**
— the call-count assertion was the one cut off. Worth recording: a filtered test report is not a test
report, and this session had already been caught by a probe that sampled instead of enumerating.

### The `else` branch is now reachable, and deliberately counts nothing

Its comment claimed *"should never come to that, Moose do not return dead units in getUnits()"*. With one
read the branch is reachable for a unit at or below `whatsInAKill`, and the correct behaviour is exactly
what it does: increment nothing, and let the group's spawned count turn it into a dead unit below.
Comment rewritten to say that rather than to deny the branch exists. A test pins it
(`test_below_the_kill_threshold_the_unit_is_dead` → `{0, 0, 1}`).
