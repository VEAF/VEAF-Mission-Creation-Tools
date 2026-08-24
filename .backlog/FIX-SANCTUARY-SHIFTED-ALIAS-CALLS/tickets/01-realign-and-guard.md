# 01 — realign the eight calls and guard the delay

Status: ✅ done

Part of [FIX-SANCTUARY-SHIFTED-ALIAS-CALLS](../PRD.md).

## What

Insert `nil` as the second argument (`delay`) at the eight `veafShortcuts.ExecuteAlias` call sites in
`src/scripts/veaf/veafSanctuary.lua`, so the remaining seven land on the parameters they were written for:

| Argument | Lands on after the fix |
|---|---|
| `ship1` / `ship2` / `sam1` / `sam2` | `aliasName` |
| `nil` *(new)* | `delay` |
| `"radius …, multiplier 2, skynet false, hdg N"` | `remainingCommand` |
| `positionIn20s` / `positionIn40s` | `position` |
| `self:getCoalition()` | `eventCoalition` |
| `nil` | `markId` |
| `true` | `bypassSecurity` |
| `spawnedGroupsNames` | `spawnedGroups` |

`bypassSecurity = true` is right: a sanctuary punishment is a script, not a pilot.

Then guard `ExecuteAlias`: coerce the delay with `tonumber`, and when a caller passes something that is
neither nil, empty, nor numeric, log an error naming the value and run the alias immediately.

## Done when

- The eight calls are realigned and `stylua` is clean
- A test asserts the delay reaching `ExecuteAlias` is numeric or nil, and fails on the shifted form
- A test asserts a non-numeric delay is refused loudly rather than raising
