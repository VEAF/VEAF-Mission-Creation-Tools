# veafSanctuary — Protected Zones


**Module ID:** `SANCTUARY` | **File:** `veafSanctuary.lua`

---

## Purpose

Defines zones that protect a coalition: any unit from another coalition that enters them is warned, then dealt with. Useful for protecting carrier operating areas, friendly airbases, or rear-area safe zones from enemy intrusion.

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
  :setCoalition(coalition.side.BLUE) -- protected coalition: units of other coalitions are handled
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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

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
        coalition: BLUE                 # BLUE | RED — protected coalition; units of other coalitions are handled
        delay_warning: 30              # seconds in the zone before the warning message (default: 0)
        delay_spawn: 60                # seconds in the zone before defenses are deployed (-1 = disabled, default)
        delay_instant: -1              # seconds in the zone before the instant kill (-1 = disabled, default)
        protect_from_missiles: false   # true = also destroy missiles fired at units located inside the zone
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enabled` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `sanctuary_zones` | object[] | `[]` | No | List of sanctuary zones |
| `sanctuary_zones[].name` | string | — | Yes | Internal identifier |
| `sanctuary_zones[].polygon_units` | string[] | — | No | DCS unit names that define the polygon boundary |
| `sanctuary_zones[].coalition` | string | — | No | `BLUE` or `RED` — protected coalition; units of other coalitions are handled on entry |
| `sanctuary_zones[].delay_warning` | integer | `0` | No | Seconds in the zone before the warning message is sent |
| `sanctuary_zones[].delay_spawn` | integer | `-1` | No | Seconds in the zone before defenses are deployed (-1 = disabled) |
| `sanctuary_zones[].delay_instant` | integer | `-1` | No | Seconds in the zone before the trespasser is instantly killed (-1 = disabled) |
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
        coalition: BLUE
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

- A zone is defined by a polygon, a circle (position + radius) or from a DCS trigger zone (`addZoneFromTriggerZone`)
- No instant kill by default: `delay_instant` is -1 (disabled); the warning → defenses → destruction escalation follows the configured delays
- Works for both aircraft and ground units
- Does not affect the coalition that owns the sanctuary

---

## See Also

- [veafMissileGuardian](veafMissileGuardian.en.md) — missile interception system
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafSanctuary` API
