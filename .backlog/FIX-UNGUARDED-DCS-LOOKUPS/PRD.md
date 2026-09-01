# FIX-UNGUARDED-DCS-LOOKUPS — the rest of the family

Status: ✅ done

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

- [x] Each location is judged on its own: guarded, or shown to be unreachable and **said so in a
      comment** so the next sweep does not re-open it
- [x] A failed lookup reports something — a group that vanished is worth a `warning`; silence is
      what made these survive
- [x] `veaf.lua`'s `getAvgGroupPos` gets the fix its case needs, which is not a guard: the string
      fallback is the defect
- [x] The four silenced `need-check-nil` warnings are either resolved or re-justified in place
- [x] Tests where the path is reachable through the mocks; where it is not, say why rather than
      writing a test that proves nothing
- [x] `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean

## What each location turned out to be

| Where | Outcome |
|---|---|
| `veafCasMission` `generateCasMission` | **Guarded**, both halves: `veaf.addGroup`'s return is read now, and the `Group.getByName` after it is checked. The mission stops and warns rather than building an AFAC, radio menus and a watchdog around a group that does not exist |
| `veafCarrierOperations.startCarrierOperations` | **Guarded**: warns and tells the pilot, instead of raising on `group:getUnits()` |
| `veaf.lua` `getAvgGroupPos` | **Removed.** It was not merely unguarded, it was **dead**: `veafGeo.getAvgGroupPos` (DROP-MIST ticket 04, PR #832) answers nil for a missing group and assigns over it, and veafGeo loads right after veaf.lua in the bundle, in VeafDynamicLoader and in the test harness. Its "correct the string fallback" fix would have corrected a function nothing could call. A test now pins `veaf.getAvgGroupPos == veafGeo.getAvgGroupPos` so a copy cannot reappear and win the assignment race |
| `veafSkynetIadsHelper` EWR resolution | **Guarded**: an EWR whose unit DCS no longer knows is warned about and skipped, instead of taking the whole point-defence search down |
| `veafSanctuary.addZoneFromTriggerZone` | **Condition fixed** (it tested the parameter), suppression removed. A misnamed trigger zone is now named in a warning |
| `veafMove` `replaceMission` (856/864) | **Guarded at the three lookups that feed it.** The dereference site itself is left unguarded *deliberately*, with a comment: `moveTanker`, `moveAfac` and `teleportEscort` each re-looked the group up **after** a teleport — which destroys and recreates it — while the guard above vouched for the pre-teleport object. All three check now; the fourth caller always did |
| `veafAirbases.getNearestAirbaseList` (105) | **Shown reachable, and fixed one level up.** Both callers are in `veafWeather`: `buildWelcomeBrief` always guarded its unit; `messageAtcClosestAirbase` did not, and its `Unit.getByName` comes off an F10 menu entry — a pilot can die between opening the menu and choosing the item. That lookup is guarded now, and `getNearestAirbaseList` carries a comment saying its callers vouch for the unit |

### The four silenced `need-check-nil`

| Where | Outcome |
|---|---|
| `veafSanctuary.lua:769` | Removed — the guard was testing the parameter |
| `veafCombatZone.lua:2241` | Removed. `GetZone` answers nil for a prerequisite misspelled in `mission.yaml`, having already said so on screen. A zone that does not exist cannot be active, so it cannot block: the requirement is skipped with a warning, rather than treated as unfulfilled, which would deadlock the operation for the rest of the mission over a typo |
| `veafCasMission.lua:1126` | Removed — and it was pointing one line too late. `veaf.getBullseye` answers nil for a side the mission declares no bullseye for, and `veaf.makeVec3` reads `vec.z` immediately, so the report raised *before* the silenced line. Only the bullseye line of the report is dropped now |
| `veaf.lua:542` | **Kept and re-justified in place.** It is in the vendored JSON parser, not a DCS lookup: `key` is checked for nil six lines above and the loop returns there. What the linter cannot see is the control flow |

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
