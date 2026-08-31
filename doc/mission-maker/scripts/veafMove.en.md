# veafMove — Unit Movement and Tanker Route Management


**Module ID:** `MOVE` | **File:** `veafMove.lua`

---

## Purpose

Provides commands to move or teleport existing DCS groups, and manages tanker orbit routes. Includes helpers to change a tanker's orbit position (`changeTanker`) and altitude/speed, or to move it along a new route (`moveTanker`).

---

## Dependencies

- `veafMarkers` — for marker commands
- `veafRadio` — for radio menu entries
- `veafMissionDb` — reads the mission's unit and route records (`veaf.mist.getAllUnitData` is a VEAF alias, not a MiST call). MiST itself is **not** required.

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

## How the orbit is found {#orbit-search}

Both tanker commands work on the waypoint carrying the **ORBIT** task. Since 6.15.12 that waypoint is **searched for across the whole route**. Before, it was assumed to be the second-to-last one: true of VEAF's own templates, whose route is [approach, orbit, leg end], false of a DCS-Liberation tanker, whose longer route ends with a landing point — both commands then refused with "has no ORBIT task defined".

- **When a route carries several orbits, the first one wins**: it is the one the tanker reaches first, so the one that is active or imminent.
- **With no ORBIT task at all, the command refuses** and says so. Moving a tanker to the wrong place is worse than telling you it cannot be done.
- The orbit may be the **first** or the **last** waypoint of the route; those routes are valid and are no longer refused.

The waypoint **after** the orbit is the far end of the refuelling leg — that is DCS's own semantics for a `Race-Track` orbit, which flies between the waypoint carrying the task and the next one. That is why `_move tanker` repositions it.

> Exception: a `Circle` orbit turns around a single point and gives the next waypoint no role, so it is left alone — on a Liberation route it might be the landing. `_move tanker` then cannot work out the leg: give `distance` and `hdg`.

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafMove.Keyphrase` | `"_move"` | Marker command prefix |

---

## See Also

- [veafSpawn](veafSpawn.en.md) — spawning new units
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafMove` API
