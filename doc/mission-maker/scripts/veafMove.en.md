# veafMove — Unit Movement and Tanker Route Management


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
_move group, name [GROUP_NAME]
```

Moves the named group to the marker position. Ground units will path to the destination; aircraft will fly directly.

### Move a tanker

```
_move tanker, name [GROUP_NAME]
```

Recomputes the named tanker's orbit route so it starts at the marker position. Accepts the optional keywords `speed`/`spd`, `alt`/`altitude`, `heading`/`hdg`, `distance`/`dist`, `teleport` (teleports the tanker near the new orbit instead of flying it there) and `silent` (skips creating the `refuel start`/`refuel end` named points).

### Change a tanker's orbit

```
_move tankermission, name [GROUP_NAME]
```

Finds the tanker nearest the marker and changes its speed (`speed`/`spd`) and altitude (`alt`/`altitude`) without moving the orbit.

### Move an AFAC

```
_move afac, name [GROUP_NAME]
```

Moves the named AFAC's orbit to the marker position. Accepts the optional keywords `speed`/`spd`, `alt`/`altitude`, `heading`/`hdg` and `immortal`.

---

## Tanker Management (Mission Maker API)

### Change a tanker's orbit

`veafMove.changeTanker(eventPos, speed, alt)` — finds the tanker near `eventPos` and changes its speed (knots) and altitude (feet) without moving the orbit.

```lua
-- Set the tanker near the marker to 430 kn / 7000 ft
veafMove.changeTanker(eventPos, 430, 7000)
```

### Move a tanker along a new route

`veafMove.moveTanker(eventPos, groupName, speed, alt, hdg, distance, teleport, silent)` — recomputes the named tanker's orbit route starting from `eventPos`.

```lua
veafMove.moveTanker(eventPos, "KC-135 Texaco", 430, 7000, 270, 30, false, false)
```

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafMove.Keyphrase` | `"_move"` | Marker command prefix |

---

## See Also

- [veafSpawn](veafSpawn.md) — spawning new units
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafMove` API
