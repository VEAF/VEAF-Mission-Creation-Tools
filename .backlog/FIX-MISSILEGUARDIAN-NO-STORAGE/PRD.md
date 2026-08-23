# FIX-MISSILEGUARDIAN-NO-STORAGE — the module never stored a guardian, so activating one raises

Status: ⬜ ready

Found on 2026-08-22 by the sweep added in
[`FIX-REMOTE-DEAD-MARKER-HANDLER`](../FIX-REMOTE-DEAD-MARKER-HANDLER/PRD.md): the only other call in the
whole script tree reaching a function nothing defines.

## The defect

`veafMissileGuardian.ActivateGuardian` and `DesactivateGuardian` both open with:

```lua
local guardian = veafMissileGuardian.GetGuardian(name)
local result = guardian:activate(silent)
```

`GetGuardian` does not exist. Both raise on their first line of real work.

It is not an isolated typo. `AddGuardian`, right above them, is:

```lua
function veafMissileGuardian.AddGuardian(guardian)
  veaf.loggers.get(veafMissileGuardian.Id):debug(...)
  return guardian
end
```

It registers **nothing**. The module has no storage at all: nothing to add to, nothing to get from.
Inventing a getter would be guessing what the container should hold, which is why this is a lot of its
own rather than a line bolted onto the marker repair.

## Decide whether it should exist before writing anything

Worth answering first, because the answer may be "delete it": is this module reachable at all, does any
mission enable it, is it documented as usable? A module whose two public verbs have never run is a
candidate for removal, not repair.

If it is kept, the shape is the one every other VEAF module already uses — a list plus a lower-cased
dictionary, as `veafCombatMission` does with `missionsList` / `missionsDict`.

## Definition of done

- [ ] Established whether any mission or documentation uses this module
- [ ] Either removed, or given storage: `AddGuardian` registers, `GetGuardian` resolves by lower-cased
      name, both tested
- [ ] `activate` / `desactivate` exercised **through the public verbs**, since that is where it raises
      today
- [ ] `veafMissileGuardian.GetGuardian` removed from `KNOWN_MISSING` in
      `test/python/test_lua_module_calls_resolve.py` — the ratchet only ever shrinks
