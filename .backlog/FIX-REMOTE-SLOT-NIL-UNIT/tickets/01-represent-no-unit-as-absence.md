# 01 — Represent "this player occupies no unit" as absence, on both sides

Status: ⬜ ready
Type: fix

## The two lines

Hook side ([`VEAF-Server-hook.lua:311`](../../../src/scripts/Hooks/VEAF-Server-hook.lua:311)):

```lua
local payload = string.format(REGISTER_PLAYER_SLOT, tostring(playerName), tostring(ucid), tostring(unitName or "nil"))
```

Mission side ([`veafRemote.lua:249-269`](../../../src/scripts/veaf/veafRemote.lua:249)):

```lua
if not username or not unitName then
  return false
end
...
remoteUser.unitName = unitName -- can be nil if the player got out of the unit
if unitName then
  veafRemote.remoteUnitsPilots[unitName] = remoteUser
end
```

`tostring(unitName or "nil")` yields the string `"nil"`, which is truthy, so every guard written for the
absent case is stepped over and the player is filed under a unit named `nil`.

## What to change

**Hook.** Send an empty payload field for an absent unit rather than the word. `REGISTER_PLAYER_SLOT`
passes it through `%q`, so an empty string arrives as `""` and is unambiguous.

**Mission.** `registerUserSlot` treats `nil`, `""` and `"nil"` alike as "no unit", and in that case:

- keeps updating `remoteUsers` — the player's **name, ucid and level stay known**, which is the whole
  value of the hook and must not be lost just because he is between slots;
- clears his previous unit from `remoteUnitsPilots`;
- registers **nothing** under any key.

Note the asymmetry to preserve: the early `return false` currently rejects the whole call when there is
no unit, which would *also* throw away the identity. The fix is not to relax the guard into accepting
`"nil"` as a unit name — it is to split "no username" (nothing to do) from "no unit" (register the
person, not a unit).

## Why the mission must accept the old payload too

`"nil"` has to be understood as "no unit" **for good**, not just until the hook is updated. The hook is
copied onto each server by hand, with no pipeline, so a mission built from a newer framework will meet
an older hook for as long as nobody has copied the file. Accepting both spellings is the whole point of
fixing both sides rather than one.

## Definition of done

- [ ] A player leaving his slot leaves no entry in `remoteUnitsPilots`
- [ ] His identity and level survive in `remoteUsers`
- [ ] `veafSecurity.getUnitNameForPlayer` returns nil for him, not `"nil"`
- [ ] Two players leaving their slots in sequence behave identically
- [ ] The hook sends `""` rather than `"nil"`
- [ ] The mission handles `nil`, `""` and `"nil"` identically — asserted for all three
- [ ] Lua tests, including the "old hook, new mission" combination
