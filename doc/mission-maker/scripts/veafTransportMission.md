# veafTransportMission — Transport and Logistics Missions

> 🇫🇷 [Version française](veafTransportMission.md)

**Module ID:** `TRANSPORT` | **Version:** — | **File:** `veafTransportMission.lua`

---

## Purpose

Creates helicopter/transport pickup-and-delivery missions. Defines cargo or troop pickup zones and drop-off zones. Integrates with CTLD (Combined Arms Transport and Logistics) when available.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafMarkers` — optional marker commands
- CTLD script — optional third-party integration

---

## Enable

```lua
veafTransportMission.initialize()
```

---

## Key Concepts

- **Loading zone** — where helicopters or transports pick up cargo/troops
- **Delivery zone** — where cargo/troops must be dropped
- Missions can have objectives (e.g., deliver N crates to win)
- Supports both pre-placed and dynamically spawned cargo

---

## Example Configuration

```lua
-- Simple troop transport mission
local transportMission = VeafTransportMission:new()
  :setName("Evac-Alpha")
  :setDescription("Evacuate troops from Firebase Alpha")
  :setPickupZoneName("ZONE-PICKUP-ALPHA")
  :setDeliveryZoneName("ZONE-DELIVERY-BASE")
  :setCargoType("Troops")
  :setCargoCount(8)
  :setBriefing("8 soldiers are stranded at Firebase Alpha. Extract them to Senaki base.")
  :initialize()
```

---

## Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setDescription(text)` | F10 menu label |
| `:setPickupZoneName(zone)` | DCS trigger zone for pickup |
| `:setDeliveryZoneName(zone)` | DCS trigger zone for delivery |
| `:setCargoType(type)` | `"Troops"`, `"Crates"`, `"Vehicles"` |
| `:setCargoCount(n)` | Number of cargo units |
| `:setBriefing(text)` | Mission briefing text |
| `:setCoalition(side)` | Mission coalition |
| `:initialize()` | Register and activate |

---

## F10 Radio Menu

- **Info** — pickup zone position, cargo description, delivery zone
- **Activate** — spawn pickup zone units
- **Deactivate** — clean up mission

---

## See Also

- [veafCombatZone](veafCombatZone.md) — for combat objective zones
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafTransportMission` API
