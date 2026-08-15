# veafAirbases — Airbase Data and ATC


**Module ID:** `AIRBASES` | **File:** `veafAirbases.lua`

---

## Purpose

Provides airbase data (position, elevation, runway headings) and configures ATC services for DCS airbases used in the mission. Feeds data to `veafNamedPoints` and the F10 radio menu.

---

## Enable

```lua
veafAirbases.initialize()
```

---

## Usage

Airbase data (runways and headings) is read automatically from the DCS environment during `veafAirbases.initialize()`. You can then query an airbase for its runway in service based on wind:

```lua
veafAirbases.initialize()

local airbase = veafAirbases.getAirbaseByName("Senaki-Kolkhi")
if airbase then
  -- runway in service for a given true wind direction (degrees)
  local runway = airbase:getRunwayInServiceString(270)
  veaf.outTextForUnit(unitName, airbase:toString(), 20)
end
```

You can also get the nearest airbase to a unit with `veafAirbases.getNearestAirbase(dcsUnit)`.

---

## Notes

- Most DCS airbases are detected automatically at initialization
- The runway in service is computed from the wind direction (`getRunwayInService` / `getRunwayInServiceString`)
- Get an airbase by name (`getAirbaseByName`) or the nearest to a unit (`getNearestAirbase`)

---

## See Also

- [veafNamedPoints](veafNamedPoints.en.md) — uses airbase data for named points
- [veafCarrierOperations](veafCarrierOperations.en.md) — carrier-specific ATC
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafAirbases` API
