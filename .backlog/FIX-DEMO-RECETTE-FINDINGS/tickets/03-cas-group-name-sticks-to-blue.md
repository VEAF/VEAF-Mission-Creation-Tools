# 03 — The CAS group name sticks to « Blue CAS Group »

Status: ✅ done
Type: fix
Files: `src/scripts/veaf/veafCasMission.lua` (`generateCasMission`, l. ~1097), `test/lua/test_veafCasMission*.lua`

## What happens

```lua
if side == veafCasMission.SIDE_BLUE then
  veafCasMission.casGroupName = veafCasMission.BlueCasGroupName
end
```

`casGroupName` starts as `RedCasGroupName` and is switched to `BlueCasGroupName` for a blue CAS group, but never switched back.
After one blue CAS (an interpreter or remote `_cas` for the blue side), every later CAS group is named « Blue CAS Group », whatever its side — and the group-alive watchdog, the smoke and flare commands all follow that name.

## Measured

Demo test mission, 2026-10-05: a `_cas` sent as a blue player's marker spawned a coalition 1 (red) group of 36 units named « Blue CAS Group », after an earlier `_cas` had run through the interpreter for the blue side.

## Fix

Set the name from the side on every generation: red → `RedCasGroupName`, blue → `BlueCasGroupName`.

## Test

Generate a blue CAS, end it, generate a red one: the red group is named `RedCasGroupName`.
