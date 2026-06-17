# veafSanctuary — Protected Zones


**Module ID:** `SANCTUARY` | **File:** `veafSanctuary.lua`

---

## Purpose

Defines zones that automatically destroy any unit from the specified coalition that enters them. Useful for protecting carrier operating areas, friendly airbases, or rear-area safe zones from enemy intrusion.

---

## Dependencies

---

## Enable

```lua
veafSanctuary.initialize()
```

Then define zones:

```lua
local zone = VeafSanctuaryZone:new()
  :setName("Carrier Zone")
  :setCoalition(coalition.side.RED)  -- protect against Red units that enter
  :setPolygonFromUnits({ "SANCT-NW", "SANCT-NE", "SANCT-SE", "SANCT-SW" }, true)
  :setDelayWarning(30)               -- seconds before warning
  :setDelaySpawn(60)                 -- seconds before defenses are deployed
  :setProtectFromMissiles()          -- also destroy missiles fired at units inside
veafSanctuary.addZone(zone)
```

You can also build a zone from a DCS trigger zone:

```lua
veafSanctuary.addZoneFromTriggerZone("ZONE-CARRIER-PROTECTION")
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
        protect_from_missiles: false   # true = also destroy missiles fired at units located inside the zone
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
| `sanctuary_zones[].protect_from_missiles` | boolean | `false` | No | Also destroy missiles fired at units located inside the zone |

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

Zones are built with `VeafSanctuaryZone:new()` then registered via `veafSanctuary.addZone(zone)`. Each setter returns the zone, allowing chaining.

| Method | Description |
|--------|-------------|
| `:setName(value)` | Internal identifier |
| `:setCoalition(value)` | Protected coalition (units of other coalitions are handled) |
| `:setRadius(value)` | Radius of the circular zone (metres) |
| `:setPosition(value)` | Centre of the circular zone |
| `:setPolygonFromUnits(unitNames, markPositions)` | Define a polygon from a list of DCS unit names; `markPositions` set to `true` draws the zone on the map |
| `:setPolygonFromUnitsInSequence(unitNamePrefix, markPositions)` | Define a polygon from units named `prefix #001`, `prefix #002`, ... |
| `:setProtectFromMissiles()` | Enable destruction of missiles fired at units inside the zone (no argument — flag) |
| `:setDelayWarning(value)` | Seconds before the warning message is sent |
| `:setOffensesBeforeDestruction(value)` | Number of shots at players before the shooter is destroyed |
| `:setMessageWarning(value)` | Warning message |
| `:setMessageShotTarget(value)` | Message to the target when a shot is detected |
| `:setMessageShotLauncher(value)` | Message to the shooter when a shot is detected |
| `:setDelayInstant(value)` | Seconds before the trespasser is instantly killed (-1 to disable) |
| `:setDelaySpawn(value)` | Seconds before defenses are deployed (-1 to disable) |
| `:setMessageSpawn(value)` | Message shown when defenses are deployed |
| `:addSpawnedGroups(names)` | Register deployed groups associated with the zone |

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
