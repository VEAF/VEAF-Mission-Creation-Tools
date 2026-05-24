# veafInterpreter — Unit-Embedded Commands


**Module ID:** `INTERPRETER` | **Version:** 1.6.x | **File:** `veafInterpreter.lua`

---

## Purpose

The VEAF Interpreter lets you embed VEAF commands directly in unit or static object names in the DCS Mission Editor, without writing a single line of Lua. When the mission starts, the interpreter scans all units, detects the embedded commands, executes them, and removes the trigger unit.

The result: your entire spawn setup lives in the DCS editor as named units — no scripts, no triggers, no magic.

---

## How it works

1. Place a unit (or static object) in the DCS Mission Editor anywhere on the map.
2. Name it with the `#veafInterpreter["command"]` tag — where `command` is any VEAF marker command.
3. One second after the mission starts, the interpreter scans all units in the mission database.
4. For each unit carrying a valid tag, it executes the command at that unit's position, then **destroys the unit** (and its group).

The unit's position becomes the command position — perfect for JTAC setups, convoy waypoints, or SAM battery locations that you want to position visually in the editor.

If the hosting unit belongs to a group with **waypoints**, those waypoints are passed to the spawned groups. Convoys and patrols spawned this way will follow the route you drew in the editor.

---

## Unit naming convention

```
#veafInterpreter["<command>"]
```

The tag can appear anywhere in the unit name. Text before and after is ignored — which is useful for making unit names unique when DCS requires it:

```
#veafInterpreter["-spawn sa-11, side red"] #001
#veafInterpreter["-spawn sa-11, side red"] #002
```

Both units carry the same command but have different names.

---

## Command syntax

The command inside the tag is the same syntax used for F10 map markers — the `-` prefix followed by a VEAF command and its options:

```
-spawn sa-11, side red
-jtac, laserCode 1688
-convoy from ZONE-A to ZONE-B
-arty, rounds 10
```

All commands understood by the VEAF marker system work here. See the [VEAF command reference](../../LUA_API_REFERENCE.md) for the full list.

---

## Examples

### JTAC at a fixed position

Place a dummy infantry unit named:
```
#veafInterpreter["-jtac, laserCode 1688, smoke red"]
```

At mission start the interpreter creates a JTAC at that position with laser code 1688 and pops red smoke. The dummy infantry disappears.

### SA-11 battery

```
#veafInterpreter["-spawn sa-11, side red, defense 2, size 2"]
```

A full SA-11 battery spawns at the unit's editor position. Adjust `defense` and `size` to taste.

### Convoy following an editor route

1. In the DCS editor, create a ground group and draw **waypoints** from A to B.
2. Name the group (or one unit in it):
   ```
   #veafInterpreter["-convoy, defense 1, size 8, patrol"]
   ```
3. At mission start the interpreter creates a convoy at the group's position, following the drawn route. The original group is destroyed.

### Multiple SAM sites with unique names

```
#veafInterpreter["-spawn sa-10, side red"] NORTH-01
#veafInterpreter["-spawn sa-10, side red"] NORTH-02
#veafInterpreter["-spawn sa-6, side red"]  SOUTH-01
```

### Artillery in a defensive position

```
#veafInterpreter["-arty, rounds 20, defense 2"]
```

---

## Configuration

The interpreter needs no per-mission configuration. The only tunable is the startup delay:

```lua
-- Change before initialize() is called (default: 1 second)
veafInterpreter.DelayForStartup = 3
```

Increase this if your mission has many scripts loading in parallel and the interpreter fires before other modules are ready.

---

## Tips

- Use a visually representative unit type so you can see spawn positions clearly in the editor (e.g. a soldier for a JTAC, a SAM radar type for an IADS element).
- All units carrying interpreter tags should be **late-activation** is not required — VEAF will destroy them anyway, but late-activation avoids them briefly appearing in-game.
- The interpreter is a one-shot scan. It does not re-run during the mission.

---

## See Also

- [veafSpawn](veafSpawn.md) — manual spawn commands
- [veafCombatZone](veafCombatZone.md) — activatable zones (the `#command` tag in unit names uses the same mechanism)
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafInterpreter` API
