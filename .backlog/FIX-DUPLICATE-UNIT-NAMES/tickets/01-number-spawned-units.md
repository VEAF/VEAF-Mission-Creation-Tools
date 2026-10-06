# 01 — Give every spawned unit a unique name

Status: ⬜ ready
Type: fix
Files: `src/scripts/veaf/veafSpawnGround.lua` (unit loop near l. 373), other spawn paths that build unit names the same way, `test/lua/`, `CHANGELOG.md`

## What happens

See the [PRD](../PRD.md): `"%s - %s"` (group name, display name) with no index gives two units of the same type one name; DCS then resolves neither by name.

## Fix

Append the unit's index to every generated unit name, e.g. `"%s - %s #%d"` (and `"%s #%d"` when `HideTypeFromGroupNames` is set), so names are unique within the group — the group name is already unique.
Then look for the same pattern in the other spawn paths (`grep -n "unitName\s*=" src/scripts/veaf/veafSpawn*.lua src/scripts/veaf/veafGrass.lua src/scripts/veaf/veafCasMission.lua`, convoys, FARP, ships, infantry) and fix those that can repeat a name.
Check what reads these names back before changing them: a caller that parses `"<group> - <type>"` (the JTAC, CTLD, the spotter network, the combat-zone unit lists shown by « Infos ») must keep working.

## Test

A Lua test (see `test/lua/test_veafSpawn.lua` and `dcs_mocks.lua`) spawning a group with two units of the same type: the two names handed to `coalition.addGroup` differ.
