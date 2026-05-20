# veafCombatZone — Activatable Combat Zones


**Module ID:** `COMBATZONE` | **Version:** 1.22.x | **File:** `veafCombatZone.lua`

---

## Purpose

Defines named combat zones in the mission editor that players can activate and deactivate via the F10 radio menu. Each zone tracks enemy unit state, fires objective-completion events, supports scoring, and can contain multiple unit groups with spawning rules.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafSpawn` — unit spawning backend
- `veafMarkers` — optional marker commands

---

## Enable

```lua
veafCombatZone.initialize()
```

Individual zones are created and initialised separately (see below).

---

## Key Module Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafCombatZone.SecondsBetweenWatchdogChecks` | `60` | How often the zone watchdog polls (s) |
| `veafCombatZone.SecondsBetweenSmokeRequests` | `180` | Smoke mark cooldown (s) |
| `veafCombatZone.SecondsBetweenFlareRequests` | `120` | Flare mark cooldown (s) |
| `veafCombatZone.RadioMenuName` | `"COMBAT ZONES"` | F10 submenu label |
| `veafCombatZone.DefaultSpawnRadiusForUnits` | `50` | Default unit scatter radius (m) |

---

## Defining a Zone

```lua
local strikeZone = VeafCombatZone:new()
  :setName("Strike Alpha")                   -- internal name
  :setZoneName("ZONE-STRIKE-ALPHA")          -- DCS trigger zone name
  :setDescription("Armoured column — Senaki")
  :setBriefing("Destroy all vehicles. Expect AAA and MANPADS.")
  :addElement(
    VeafCombatZoneElement:new()
      :setGroupName("STRIKE-ALPHA-ARMOR")    -- DCS group to spawn
      :setSpawnRadius(100)
  )
  :addElement(
    VeafCombatZoneElement:new()
      :setGroupName("STRIKE-ALPHA-AAA")
  )
  :initialize()
```

### VeafCombatZone Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Internal identifier |
| `:setZoneName(zoneName)` | DCS trigger zone that defines the spawn area |
| `:setDescription(text)` | Short name shown in radio menu |
| `:setBriefing(text)` | Full briefing text |
| `:addElement(element)` | Add a unit group to the zone |
| `:setCoalition(side)` | Override spawn coalition |
| `:setRadioGroup(name)` | Group zones under a common radio submenu |
| `:setActivateAtStart(bool)` | Auto-activate when mission starts |
| `:setSilent(bool)` | Suppress status messages |
| `:setOnCompleted(fn)` | Callback when all enemies destroyed |

### VeafCombatZoneElement Builder Methods

| Method | Description |
|--------|-------------|
| `:setGroupName(name)` | DCS group to spawn (must exist in mission editor) |
| `:setSpawnRadius(m)` | Scatter radius around zone centre |
| `:setRespawn(bool)` | Whether to respawn when destroyed |
| `:setRespawnDelay(s)` | Delay before respawn (seconds) |

---

## F10 Radio Menu (per zone)

- **Activate** — spawn the zone's unit groups
- **Deactivate** — despawn units, reset the zone
- **Info** — status, remaining unit count, briefing
- **Smoke** — mark zone with smoke (cooldown applies)
- **Flare** — mark zone with flares

---

## Operations (Grouped Zones)

Multiple zones can be grouped into an **Operation** that completes when all child zones are done:

```lua
VeafCombatOperation:new()
  :setName("Operation Thunder")
  :addZone("Strike Alpha")
  :addZone("Strike Bravo")
  :setBriefing("Destroy both armour columns before they reach Senaki.")
  :initialize()
```

---

## See Also

- [veafCasMission](veafCasMission.md) — generated CAS zones (no pre-placed groups needed)
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCombatZone` API
