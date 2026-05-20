# veafSanctuary — Protected Zones


**Module ID:** — | **File:** `veafSanctuary.lua`

---

## Purpose

Defines zones that automatically destroy any unit from the specified coalition that enters them. Useful for protecting carrier operating areas, friendly airbases, or rear-area safe zones from enemy intrusion.

---

## Dependencies

- `veafEventHandler` — for zone-entry detection

---

## Enable

```lua
veafSanctuary.initialize()
```

Then define zones:

```lua
VeafSanctuary:new()
  :setName("Carrier Zone")
  :setZoneName("ZONE-CARRIER-PROTECTION")
  :setCoalition(coalition.side.RED)  -- destroy Red units that enter
  :setMessage("Hostile aircraft eliminated in carrier defense zone")
  :initialize()
```

---

## Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setZoneName(zone)` | DCS trigger zone |
| `:setCoalition(side)` | Coalition of units to destroy |
| `:setMessage(text)` | Message shown when a unit is destroyed |
| `:setSilent(bool)` | Suppress messages |
| `:initialize()` | Activate the zone |

---

## Notes

- The zone uses the DCS trigger zone defined in the mission editor
- Units are destroyed immediately upon zone entry
- Works for both aircraft and ground units
- Does not affect the coalition that owns the sanctuary

---

## See Also

- [veafMissileGuardian](veafMissileGuardian.md) — missile interception system
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafSanctuary` API
