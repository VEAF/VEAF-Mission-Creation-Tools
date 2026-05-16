# veafNamedPoints — Named Map Positions

**Module ID:** `NAMED POINTS` | **Version:** 1.16.x | **File:** `veafNamedPoints.lua`

---

## Purpose

Allows mission makers (and players with appropriate permissions) to define named positions on the map. Named points can be referenced by other systems (convoys, missions, smoke commands) and can optionally expose an ATC frequency or TACAN channel.

---

## Dependencies

- `veafMarkers` — for the `_name point` marker command
- `veafRadio` — optional radio menu entry

---

## Enable

```lua
veafNamedPoints.initialize()
```

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafNamedPoints.Keyphrase` | `"_name point"` | Marker command prefix |
| `veafNamedPoints.RadioMenuName` | `"NAMED POINTS"` | F10 submenu label |

---

## Pre-defining Points in missionconfig.lua

Named points can be pre-defined programmatically:

```lua
veafNamedPoints.initialize()

-- Add a static named point
veafNamedPoints.addNamedPoint({
  name      = "FARP Alpha",
  position  = { x = 123456, y = 0, z = 654321 },  -- DCS vec3
  atcFreq   = 127500000,  -- Hz
  atcMod    = radio.modulation.AM,
})

-- Add a point at a known DCS airbase
veafNamedPoints.addNamedPointFromAirbase("Senaki-Kolkhi")
```

---

## Player Marker Command

Players can create named points via map markers (if allowed by security):

```
_name point Alpha
```

Places a named point called "Alpha" at the marker position.

---

## Referencing Named Points

Named points can be used as destinations in spawn commands:

```
_spawn convoy, dest Alpha, speed 40
```

---

## See Also

- [veafSpawn](veafSpawn.md) — uses named points for convoy destinations
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafNamedPoints` API
