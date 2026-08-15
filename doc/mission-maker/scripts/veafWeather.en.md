# veafWeather — Dynamic Weather and ATC Conditions


**Module ID:** `WEATHER` | **File:** `veafWeather.lua`

---

## Purpose

Two distinct roles:

1. **Design-time**: inject real-world or configured weather into a `.miz` at build time, before players load the mission. Handled by `veaf-tools.exe content inject-weather`.
2. **Runtime**: players can request weather reports and ATC information via the F10 radio menu, and the mission maker can script dynamic fog changes.

---

## Dependencies

- `veafRadio` — optional weather menu
- `veafNamedPoints` — for location-based weather reports

---

## Enable

```lua
veafWeather.initialize()
```

No parameters required.

---

## Design-Time Weather Injection

Weather is injected at build time (before the mission is loaded) using `veaf-tools.exe`:

```powershell
veaf-tools.exe content inject-weather mission.miz --config-file versions.yaml
```

### versions.yaml example

```yaml
position:
  latitude: 33.5
  longitude: 35.5
  timezone: "Asia/Damascus"
base_date: "2024-03-15"
versions:
  - name: noon-clear
    time: "12:00"
    weather:
      temperature: 25.0
      wind_speed: 8.0
      wind_direction: 270.0
      visibility: 10000.0
      cloud_type: "clear"
      fog_enabled: false
  - name: with-metar
    time: "14:00"
    metar: "METAR OSDI 151420Z 27015G25KT 9999 BKN025 18/12 Q1018 NOSIG"
```

---

## F10 Radio Menu

When the `WEATHER` module is enabled, a **"WEATHER AND ATC"** submenu appears in the F10 menu:

| Entry | Available to | What it shows |
|-------|-------------|---------------|
| Weather on closest point | Per group | Wind, visibility, QNH, temperature at nearest named point |
| ATC on closest airbase | Per group | Runway in use, QFE/QNH, pattern info at nearest airbase |
| ATC and weather in one go | Per group | Both reports combined |
| Fog settings → ... | All (secured) | Change fog conditions (see below) |

---

## Runtime Weather Reports

Get a weather report programmatically for a position (a `vec3`):

```lua
local report = veafWeatherData.getWeatherString(position)
veaf.outTextForUnit(unitName, report, 30)
```

The remaining arguments are optional: `getWeatherString(vec3, dcsElementName, unitSystem, iSurfaceAltitudeMeters)`. Passing a DCS unit name as `dcsElementName` tailors the report to the aircraft type (unit system, LASTE data for the A-10).

---

## Fog Management

The runtime fog system lets you change visibility conditions during a mission — useful for immersion, training scenarios, or scripted events.

> ⚠️ **Map/DCS-version dependent**: fog control uses the modern DCS API (`world.weather.setFogThickness` / `setFogAnimation`). It is verified working on **Caucasus**. If fog does not change in-game on a given map, that is a **DCS limitation** (fog support varies by map/version), not a VEAF bug.

### Pre-defined fog constants

Three fog families are available. Activate any constant with `:activate()`:

**Dynamic fog** — recalculates density periodically based on weather conditions:

```lua
veafWeather.FOG_DYNAMIC_HEAVY:activate()
veafWeather.FOG_DYNAMIC_MEDIUM:activate()
veafWeather.FOG_DYNAMIC_SPARSE:activate()
```

**Static fog** — fixed visibility:

```lua
veafWeather.FOG_STATIC_HEAVY:activate()
veafWeather.FOG_STATIC_MEDIUM:activate()
veafWeather.FOG_STATIC_MEDIUM_LOW:activate()
veafWeather.FOG_STATIC_SPARSE:activate()
veafWeather.FOG_STATIC_SPARSE_LOW:activate()
veafWeather.FOG_STATIC_NO:activate()    -- clears all fog
```

**Animated fog** — transitions smoothly to a target state over a set duration. The pattern is `FOG_ANIMATED_<DURATION>M_<DENSITY>`:

| Duration | Density variants |
|----------|-----------------|
| `1M`, `5M`, `10M`, `15M`, `30M`, `60M`, `90M` | `HEAVY`, `MEDIUM`, `MEDIUM_LOW`, `SPARSE`, `SPARSE_LOW`, `NO` |

Examples:

```lua
veafWeather.FOG_ANIMATED_10M_MEDIUM:activate()   -- fade to medium fog over 10 minutes
veafWeather.FOG_ANIMATED_30M_NO:activate()       -- clear fog over 30 minutes
veafWeather.FOG_ANIMATED_5M_HEAVY:activate()     -- roll in heavy fog over 5 minutes
```

### Activating a fog object directly

```lua
veafWeather.setAndActivateFog(veafWeather.FOG_STATIC_MEDIUM)
```

This is equivalent to calling `:activate()` on the constant. Any previously active fog is cancelled first.

### Scripting fog changes on a trigger

```lua
-- On a DCS trigger "Begin Night Phase", enable heavy fog
mist.scheduleFunction(function()
  veafWeather.FOG_ANIMATED_15M_HEAVY:activate()
end, {}, timer.getTime() + 0)
```

---

## Chat / Remote Commands

These commands go through the chat window (requires `veafRemote` and the
[server hook](veafServerHook.en.md)) — this module has no marker command. The three aliases
`/weather`, `/atc` and `/atis` are interchangeable; the word that follows picks the action:

| Chat command | Effect |
|-------------|--------|
| `/atis` (or `/weather`, `/atc`, with no argument) | ATC + weather report at current position |
| `/weather weather` | Weather report only |
| `/atc atc` | ATIS of the nearest airbase only |
| `/weather fog FOG_STATIC_MEDIUM` | Activate a named fog constant |
| `/weather fog FOG_ANIMATED_10M_NO` | Animated fog clear over 10 minutes |

The fog name is case-insensitive. Use the exact constant names listed above (without the `veafWeather.` prefix).

---

## See Also

- [CLI Reference](../../CLI_REFERENCE.en.md#inject-weather) — every option of `veaf-tools content inject-weather`
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafWeather` API
