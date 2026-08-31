# FIX-UNGUARDED-DCS-LOOKUPS — the rest of the family

Status: ⬜ ready

Origin: the sweep run by `FIX-COMBATMISSION-UNGUARDED-GROUP` (PR #872). Every location below was
re-checked against `develop` before this lot was written.

## The family

A DCS lookup — `Group.getByName`, `Unit.getByName`, `trigger.misc.getZone` — returns `nil` when the
object is gone, and the result is dereferenced without a check. Two lots already closed the two
instances that were the most reachable (#872 in `veafCombatMission`, and
`FIX-SPAWNAIRCRAFT-UNGUARDED-GROUP` on the `-spawn` path). These are the rest.

They are **not** all the same severity, and the lot should not treat them as one batch:

| Where | What it is | Note |
|---|---|---|
| `veafCasMission.lua:1042` | `Group.getByName(name):getController()`, chained | **Functional.** And the `veaf.addGroup` just above has its return **discarded** — yet it returns `false` on an unknown country or an empty unit list, which is exactly when the lookup will fail |
| `veafCarrierOperations.lua:107` | `Group.getByName(groupName)` then `group:getUnits()` | **Functional** |
| `veaf.lua:2201-2206` | `getAvgGroupPos` | **A different bug.** The parameter may be a name *or* a group. If it is a string and the group does not exist, `group` keeps the **string** and `group:getSize()` is called on it. The fallback is wrong, not merely unguarded |
| `veafSkynetIadsHelper.lua:348-350` | `Unit.getByName` → `Unit.getGroup(unit)` → `Group.getName(group)` | Two dereferences, neither checked |
| `veafSanctuary.lua:767` | Guard on the **wrong variable** | `local triggerZone = trigger.misc.getZone(name)` then `if triggerZoneName then` — it tests the *parameter*, which is always truthy. See below |
| `veafMove.lua:856/864` | Guard testing the wrong variable | Same shape |
| `veafAirbases.lua:105` | `dcsUnit:getPoint()`, reached from `veafWeather.lua:1258` | Verify the caller before deciding: the unit may be guaranteed by its call site |

## The one that says the most

`veafSanctuary.lua:766-769`:

```lua
local triggerZone = trigger.misc.getZone(triggerZoneName)
if triggerZoneName then                          -- the parameter, not the result
  ---@diagnostic disable-next-line: need-check-nil
  local zone = ...:setRadius(triggerZone.radius)  -- raises when the zone is missing
```

The linter **caught this**, and the warning was silenced rather than fixed. A misnamed trigger zone
in `mission.yaml` therefore crashes the sanctuary set-up instead of reporting a missing zone.

## A better search than a list

`---@diagnostic disable-next-line: need-check-nil` marks a place where the tooling found exactly
this and was told to be quiet. There are **four** in `src/scripts/veaf/`: `veaf.lua`,
`veafCasMission.lua`, `veafCombatZone.lua`, `veafSanctuary.lua`. Start there — it is enumerable,
unlike a list somebody wrote by hand, and each one is a confession.

## Definition of done

- [ ] Each location is judged on its own: guarded, or shown to be unreachable and **said so in a
      comment** so the next sweep does not re-open it
- [ ] A failed lookup reports something — a group that vanished is worth a `warning`; silence is
      what made these survive
- [ ] `veaf.lua`'s `getAvgGroupPos` gets the fix its case needs, which is not a guard: the string
      fallback is the defect
- [ ] The four silenced `need-check-nil` warnings are either resolved or re-justified in place
- [ ] Tests where the path is reachable through the mocks; where it is not, say why rather than
      writing a test that proves nothing
- [ ] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Guard, or prove unreachable](tickets/01-guard-or-prove.md) | fix |

## Out of scope

- `src/scripts/community/CSAR.lua:1059` — vendored code; a local patch there is lost at the next
  refresh unless it goes upstream first.
- The `unit:getGroup()` chains where the unit is guarded and the group is not: reachable only in a
  narrow window, and `veafScheduler.lua:93` wraps scheduled tasks in a `pcall`, which degrades them
  to a logged error rather than a lost mission.
