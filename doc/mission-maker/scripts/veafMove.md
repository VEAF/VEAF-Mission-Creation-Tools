# veafMove — Unit Movement and Tanker Route Management

> 🇫🇷 [Version française](../fr/scripts/veafMove.md)

**Module ID:** `MOVE` | **Version:** — | **File:** `veafMove.lua`

---

## Purpose

Provides commands to move or teleport existing DCS groups, and manages tanker orbit routes. Includes helpers to change a tanker's orbit position (`changeTanker`) and altitude/speed, or to move it along a new route (`moveTanker`).

---

## Dependencies

- `veafMarkers` — for marker commands
- `veafRadio` — for radio menu entries
- `mist` — for route management

---

## Enable

```lua
veafMove.initialize()
```

---

## Marker Commands (Player-Facing)

### Move a group

```
_move unit, name [GROUP_NAME]
```

Moves the named group to the marker position. Ground units will path to the destination; aircraft will fly directly.

### Teleport a group

```
_teleport, name [GROUP_NAME]
```

Instantly moves the group to the marker position. Useful for testing.

---

## Tanker Management (Mission Maker API)

### Change tanker orbit

`veafMove.changeTanker(groupName, point, altitude, speed)` — moves the tanker's orbit waypoint to a new position.

```lua
-- Move Texaco to a new orbit position
veafMove.changeTanker("KC-135 Texaco", { x=1000, y=7000, z=2000 }, 7000, 430)
```

### Move tanker along new route

`veafMove.moveTanker(groupName, startPoint, endPoint, altitude, speed)` — sets a new race-track orbit route.

```lua
veafMove.moveTanker("KC-135 Texaco", startPoint, endPoint, 7000, 430)
```

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafMove.SpawnKeyphrase` | `"_move"` | Marker command prefix for move |

---

## See Also

- [veafSpawn](veafSpawn.md) — spawning new units
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafMove` API
