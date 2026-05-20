# veafWeather — Dynamic Weather and ATC Conditions

> 🇫🇷 [Version française](veafWeather.md)

**Module ID:** `WEATHER` | **Version:** — | **File:** `veafWeather.lua`

---

## Purpose

Provides weather reporting and dynamic weather injection for DCS missions. Generates human-readable METAR-style reports and integrates with `veaf-tools.exe weather-inject` for injecting real-world or configured weather at build time.

---

## Dependencies

- `veafRadio` — optional weather menu
- `veafNamedPoints` — for location-based weather reports

---

## Enable

```lua
veafWeather.initialize()
```

---

## Design-Time Weather Injection

Weather is injected at build time (before the mission is loaded) using `veaf-tools.exe`:

```powershell
veaf-tools.exe weather-inject --mission mission.miz --config weather.yaml
```

### weather.yaml Example

```yaml
weather:
  source: metar          # "metar" (real-world) or "manual"
  icao: UGSS             # ICAO airport code for METAR (Senaki)
  # manual override (used when source: manual)
  wind:
    speed: 10            # knots
    direction: 270       # degrees
  visibility: 8000       # metres
  clouds:
    base: 2500           # feet
    density: 5           # 0-10
  temperature: 18        # °C
  qnh: 1013              # hPa
```

---

## Runtime Weather Report

Get a weather report for a position:

```lua
local report = veaf.weatherReport(position, altitude, withLASTE)
veaf.outTextForUnit(unitName, report, 30)
```

---

## F10 Radio Menu

If enabled, provides a **Weather** submenu where players can request local weather reports.

---

## See Also

- [Tools Reference](../../TOOLS_REFERENCE.md) — `veaf-tools.exe weather-inject` full reference
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafWeather` API
