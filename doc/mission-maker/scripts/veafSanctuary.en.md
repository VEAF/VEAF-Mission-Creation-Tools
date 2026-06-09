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

## Configuration (`mission.yaml`)

```yaml
modules:
  SANCTUARY:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    sanctuary_zones:      # list of protected zones
      - name: "Carrier Zone"            # internal identifier
        polygon_units:                  # DCS unit names defining the polygon boundary
          - "Sanctuary-Unit-1"
          - "Sanctuary-Unit-2"
        coalition: RED                  # BLUE | RED — coalition whose units are destroyed on entry
        delay_warning: 30              # seconds before warning message is sent (default: 0)
        delay_spawn: 60                # seconds before the zone becomes active after mission start
        delay_instant: 0               # seconds between repeated destruction checks (default: 0)
        protect_from_missiles: false   # true = also intercept missiles heading into the zone
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enable` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `sanctuary_zones` | object[] | `[]` | No | List of sanctuary zones |
| `sanctuary_zones[].name` | string | — | Yes | Internal identifier |
| `sanctuary_zones[].polygon_units` | string[] | — | No | DCS unit names that define the polygon boundary |
| `sanctuary_zones[].coalition` | string | — | No | `BLUE` or `RED` — units of this coalition are destroyed on entry |
| `sanctuary_zones[].delay_warning` | integer | `0` | No | Seconds before the warning message is sent |
| `sanctuary_zones[].delay_spawn` | integer | `0` | No | Seconds before the zone activates after mission start |
| `sanctuary_zones[].delay_instant` | integer | `0` | No | Seconds between repeated destruction checks |
| `sanctuary_zones[].protect_from_missiles` | boolean | `false` | No | Also intercept missiles heading into the zone |

### Minimal example

```yaml
modules:
  SANCTUARY:
    enabled: true
    sanctuary_zones:
      - name: "Carrier Protection"
        polygon_units:
          - "SANCT-NW"
          - "SANCT-NE"
          - "SANCT-SE"
          - "SANCT-SW"
        coalition: RED
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
