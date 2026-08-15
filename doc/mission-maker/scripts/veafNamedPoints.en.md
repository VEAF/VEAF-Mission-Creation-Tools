# veafNamedPoints — Named Map Positions


**Module ID:** `NAMEDPOINTS` | **File:** `veafNamedPoints.lua`

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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  NAMEDPOINTS:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    custom_points:        # pre-defined named points
      - name: "Battle Area Alpha"    # point name (referenced in commands)
        lat: "41.123456"             # latitude as string (decimal degrees)
        lon: "44.987654"             # longitude as string (decimal degrees)
      - name: "FARP Bravo"
        lat: "41.200000"
        lon: "44.100000"
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enabled` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `custom_points` | object[] | `[]` | No | Pre-defined named points |
| `custom_points[].name` | string | — | Yes | Point name — referenced in spawn commands and radio menus |
| `custom_points[].lat` | string | — | Yes | Latitude as a decimal string (e.g. `"41.123456"`) |
| `custom_points[].lon` | string | — | Yes | Longitude as a decimal string (e.g. `"44.987654"`) |

> Coordinates are geographic (WGS84). Use decimal degrees as strings.

### Minimal example

```yaml
modules:
  NAMEDPOINTS:
    enabled: true
    custom_points:
      - name: "BULLSEYE"
        lat: "41.100000"
        lon: "43.850000"
```

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafNamedPoints.Keyphrase` | `"_name point"` | Marker command prefix |
| `veafNamedPoints.RadioMenuName` | `"NAMED POINTS"` | F10 submenu label |

---

## Pre-defining Points in mission-script.lua

Named points can be pre-defined programmatically. `addPoint(name, point)` takes a vec3 (`{x=…, y=0, z=…}`; `y` defaults to `0`). ATC/TACAN/ILS/tower data is attached via `addDataToPoint(point, data)`:

```lua
veafNamedPoints.initialize()

-- Add a static named point
local point = veafNamedPoints.addPoint("FARP Alpha", { x = 123456, y = 0, z = 654321 })

-- Attach ATC/TACAN/tower/ILS data to the point
veafNamedPoints.addDataToPoint(point, {
  atc   = true,
  tower = "V131, U260",
  tacan = "16X BTM",
  ils   = "110.30",
})
```

`addAirbases()` bulk-adds every airbase on the map (called automatically by `initialize()`); there is no per-airbase add function. `addCities()` likewise adds the theatre's cities.

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

- [veafSpawn](veafSpawn.en.md) — uses named points for convoy destinations
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafNamedPoints` API
