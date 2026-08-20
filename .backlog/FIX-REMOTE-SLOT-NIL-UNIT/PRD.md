# FIX-REMOTE-SLOT-NIL-UNIT — a player who leaves his slot is registered in a unit called "nil"

Status: ⬜ ready

Found on 2026-08-20 while instructing whether the server hook could carry a game master's identity
(`FEAT-ROLE-AWARE-RADIO-MENU`, cancelled). This defect is **independent of that lot** and survives its
cancellation.

## The defect, in two halves that were each written correctly

The server hook reports every slot change to the mission, including the case where a player ends up in
no unit at all — a spectator, or a game master. It formats the payload like this
([`VEAF-Server-hook.lua:311`](../../src/scripts/Hooks/VEAF-Server-hook.lua:311)):

```lua
local payload = string.format(REGISTER_PLAYER_SLOT, tostring(playerName), tostring(ucid), tostring(unitName or "nil")) -- unitName will be nil if the player is a spectator
```

The mission side is written for exactly that case
([`veafRemote.lua:249`](../../src/scripts/veaf/veafRemote.lua:249)):

```lua
if not username or not unitName then
  return false
end
...
remoteUser.unitName = unitName -- can be nil if the player got out of the unit
```

**Both comments describe the intended behaviour, and neither happens.** `tostring(unitName or "nil")`
produces the four-character **string** `"nil"`, which is truthy in Lua, so the guard never fires and the
player is registered as occupying a unit named `nil`:

```lua
veafRemote.remoteUnitsPilots["nil"] = remoteUser
```

## What it actually costs

Not a security hole — the refusals still refuse — but a lying one, and an inconsistency:

- **`veafSecurity.getUnitNameForPlayer`** ([`veafSecurity.lua:652`](../../src/scripts/veaf/veafSecurity.lua:652))
  walks that table by pilot name and returns the key it finds, so for a player who left his slot it
  returns the string `"nil"` instead of nothing.
- **`handleElevationRequest`** then calls `getGroupIdForUnit("nil")`, gets nothing, and logs
  *"cannot resolve a group for unit [nil], refusing to elevate"*. The refusal is correct; the reason
  given is fiction, and it is the kind of message someone will one day spend an evening chasing.
- **Two players in the same state disagree.** `remoteUnitsPilots["nil"]` holds one entry, so if A leaves
  his slot and then B leaves his, A is no longer findable and B is — the same state, two behaviours,
  depending on who moved last.

## What ships

Both sides, and deliberately both:

- **The hook** stops sending the string `"nil"` for "no unit".
- **The mission** treats `nil`, `"nil"` and `""` alike as "no unit", and *unregisters* rather than
  registering a fictional one — so the state "this player occupies nothing" is represented by absence,
  which is what the code already claims.

Fixing only the hook would be tempting and wrong: **the hook is deployed by hand**, server by server,
with no pipeline. A mission built from a newer framework will meet an older hook for as long as it takes
someone to copy a file, so the mission side has to be robust to the old payload rather than assume the
new one.

## Definition of done

- [ ] A player leaving his slot leaves no entry behind in `remoteUnitsPilots`
- [ ] `getUnitNameForPlayer` returns nil for him, not `"nil"`
- [ ] Two players leaving their slots in sequence behave identically
- [ ] The hook no longer sends the literal string for an absent unit
- [ ] The mission still handles the **old** hook payload correctly (an older hook against a newer mission
      is the normal state of affairs here, not an edge case)
- [ ] Lua tests on both paths
