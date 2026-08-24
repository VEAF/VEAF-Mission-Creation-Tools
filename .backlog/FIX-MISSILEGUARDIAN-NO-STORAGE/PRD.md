# FIX-MISSILEGUARDIAN-NO-STORAGE — the module never stored a guardian, so activating one raises

Status: ✅ done

Found on 2026-08-22 by the sweep added in
[`FIX-REMOTE-DEAD-MARKER-HANDLER`](../FIX-REMOTE-DEAD-MARKER-HANDLER/PRD.md): the only other call in the
whole script tree reaching a function nothing defines. Closed on 2026-08-24.

## The defect

`veafMissileGuardian.ActivateGuardian` and `DesactivateGuardian` both open with:

```lua
local guardian = veafMissileGuardian.GetGuardian(name)
local result = guardian:activate(silent)
```

`GetGuardian` does not exist. Both raise on their first line of real work.

## What the investigation found, which changed the answer

This PRD proposed either removal or "give it storage". Reading the module through on 2026-08-24 showed
that **storage was one hole out of five**, so the second option was not a small fix:

| Piece | State |
|---|---|
| `GetGuardian` | does not exist |
| `AddGuardian` | returned its argument, registered nothing, had no caller |
| `VeafMG_Guardian:activate` / `desactivate` / `isSilent` | **do not exist** — the three methods the verbs call |
| `getLargeScaleProtector()` | `-- TODO`, returns nil, and sits on the path a fired weapon takes |
| `VeafMG_Protector:start()` / `:stop()` | empty bodies, comment only — **no watchdog anywhere**, so nothing ever destroys a weapon in flight |
| `listGuardians()` | sorted an empty local and printed an empty list |
| `listActiveMissions()` | iterated `veafMissileGuardian.missionsDict`, a table this module never had |
| `buildRadioMenu()` | builds a Help entry and nothing else |
| `executeCommandFromRemote` | never registered with `veafRemote` |

**Removal was also wrong**, for a reason the PRD did not know: the module is shipped in the bundle,
exposed as `MISSILEGUARDIAN` in the module catalogue and the mission-template picker, mentioned in the
default `mission.yaml`, and has its own documentation page in both languages — a page that **already
declares it a skeleton** (version `0.0.2`, *"à utiliser uniquement à des fins exploratoires"*) and names
the protector and the watchdog as drafts. Nothing is sold to a user as working.

So the third option was taken, with David: **keep the skeleton and stop it pretending.** Finishing it is
a feature project — storage, three class methods, a large-scale protector, a watchdog that destroys a
missile in flight, menu entries, a way to declare a guardian in `mission.yaml` — not a fix.

## One thing the first reading of this got wrong

"No player can reach any of this" was too strong, and it mattered. The documentation page teaches a
mission maker to build a guardian by hand in `mission-script.lua` and call `start()`. So the weapon path
**was** reachable by anyone following the documentation — and before this lot it warned the targeted
pilot and then raised on the missing protector, **on every shot**. Guarding that line is what makes the
one behaviour the page promises (warn the target) actually complete.

## Delivered

- The three public verbs (`AddGuardian`, `ActivateGuardian`, `DesactivateGuardian`) and `listGuardians`
  refuse through one helper that logs a warning and returns `false`. A warning rather than a silent
  return: a mission calling one of them asked for protection it is not getting, and the log is the only
  place that can say so. They are kept rather than deleted — removing them would turn a warning into a
  nil-call crash at the caller.
- `listActiveMissions` is **removed**. It iterated a table this module never had, copied from
  `veafCombatMission` where "missions" is a real concept; its only possible outcome was an error.
- The weapon path guards the missing protector instead of raising inside a `world` event handler.
- **A third defect, found by a test written for the second**: `VeafMG_Weapon:setDcsWeapon` passed
  `getLauncher()` straight to `getUnitName`, which indexed it. `getLauncher()` legitimately answers nil
  once the shooter is gone — ordinary for a shot event processed a moment later. The existing
  `setDcsWeapon` test never saw it because its mock always supplied a launcher.
- A header block in the module states all of the above, so the next reader does not spend the hour again.
- The documentation page carries a `{#state}` table in both languages: what works, what refuses, what is
  not implemented.

## Definition of done

- [x] Established whether any mission or documentation uses this module — it is shipped, offered in the
      picker, and documented as an explicit skeleton; nothing in the repository constructs a guardian
- [x] Neither removed nor given storage: made honest, which the investigation showed was the only option
      that is a fix rather than a feature project
- [x] `activate` / `desactivate` exercised **through the public verbs**, since that is where it raised
- [x] `veafMissileGuardian.GetGuardian` removed from `KNOWN_MISSING` in
      `test/python/test_lua_module_calls_resolve.py` — the list is now **empty**

Twelve Lua tests, and three mutations run against them: restoring the raising verbs kills two, removing
the protector guard kills two, unguarding `getUnitName` kills four.
