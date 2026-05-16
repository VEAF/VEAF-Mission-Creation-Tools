# veafAirbases — Airbase Data and ATC

**Module ID:** — | **File:** `veafAirbases.lua`

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

Airbase data is read automatically from the DCS environment. Mission makers can override or supplement data:

```lua
-- Register a custom airbase configuration
veafAirbases.setAirbaseData("Senaki-Kolkhi", {
  atcFrequency = 127500000,   -- Hz
  atcModulation = radio.modulation.AM,
  elevation = 43,             -- metres
  runways = {
    { heading = 110, ils = { frequency = 109300000, course = 110 } },
    { heading = 290 },
  },
})
```

---

## Notes

- Most DCS airbases are already known to the module
- Override only when you need custom frequencies or corrections
- TACAN/ILS data is used by `veafNamedPoints` and carrier operations

---

## See Also

- [veafNamedPoints](veafNamedPoints.md) — uses airbase data for named points
- [veafCarrierOperations](veafCarrierOperations.md) — carrier-specific ATC
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafAirbases` API
