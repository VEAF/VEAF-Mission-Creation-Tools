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

## Configuration (`mission.yaml`)

```yaml
modules:
  COMBATZONE:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    combat_zone_settings: # optional global overrides
      event_message_combatzonecomplete: "Zone objective complete!"  # null = suppress
      watchdog_check_interval: 30          # seconds between zone watchdog polls (default: 60)
      radio_menu_name: "Combat Zones"      # F10 menu label
      combat_zone_menu_name: "Combat Zone Operations"
      operation_menu_name: "Operations"
    combat_zones:         # zone and operation definitions
      - type: zone                          # zone | operation
        zone_name: "CZ-Alpha"              # DCS trigger zone name
        friendly_name: "Alpha Zone"        # label in radio menu
        briefing: "Destroy the armoured column."  # shown in mission info
        training: false                     # true = no security, verbose status
        chained_zones:                      # zones to trigger when this one completes
          - "CZ-Bravo"
        chained_delay: 60                   # seconds before chaining fires
      - type: operation
        zone_name: "Op-Thunder"
        friendly_name: "Operation Thunder"
        tasking_orders:
          - zone_name: "CZ-Alpha"           # first task (no dependencies)
          - zone_name: "CZ-Bravo"
            dependencies:                   # CZ-Bravo unlocks after CZ-Alpha
              - "CZ-Alpha"
```

### `combat_zone_settings` fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `event_message_combatzonecomplete` | string \| null | *(module default)* | Message broadcast when a zone completes. `null` suppresses it. |
| `watchdog_check_interval` | integer | `60` | Seconds between watchdog polls |
| `radio_menu_name` | string | `"COMBAT ZONES"` | F10 top-level menu label |
| `combat_zone_menu_name` | string | *(default)* | Sub-menu label for zone operations |
| `operation_menu_name` | string | *(default)* | Sub-menu label for operations |

### `combat_zones[]` fields — type `zone`

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `type` | string | `zone` | No | `zone` or `operation` |
| `zone_name` | string | — | Yes | DCS trigger zone name |
| `friendly_name` | string | — | No | Label shown in the F10 menu |
| `briefing` | string | — | No | Briefing text shown to players |
| `training` | boolean | `false` | No | Training mode: no security, verbose status |
| `chained_zones` | string[] | `[]` | No | Zone names to trigger on completion |
| `chained_delay` | integer | `0` | No | Seconds before chained zones fire |

### `combat_zones[]` fields — type `operation`

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `type` | string | — | Yes | Must be `operation` |
| `zone_name` | string | — | Yes | DCS trigger zone name |
| `friendly_name` | string | — | No | Label in the radio menu |
| `briefing` | string | — | No | Briefing text |
| `tasking_orders` | object[] | `[]` | No | Ordered task list |
| `tasking_orders[].zone_name` | string | — | Yes | Combat zone name for this task |
| `tasking_orders[].dependencies` | string[] | `[]` | No | Zone names that must complete first |

### Minimal example

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Alpha"
        friendly_name: "Alpha"
```

---

## How it works

Place all the units that should appear in the zone directly in the DCS Mission Editor, inside the trigger zone. When the mission starts VEAF removes them all — the zone is empty. When a player activates the zone via the F10 menu, all units are respawned at randomised positions within the zone radius. When every enemy unit is destroyed, the zone is marked as completed (optional callback fires, optional chained zones activate).

This approach gives you full visual design in the editor while keeping the zone inactive at mission start.

### Setting up in the DCS Mission Editor

1. **Create a trigger zone** — define the combat area. Name it, e.g. `ZONE-ALPHA`.
2. **Place unit groups** inside the zone. Set them to any coalition — VEAF will handle their lifecycle.
3. **Use unit name tags** (see below) to customise spawn behaviour per group.
4. **Register the zone** in `mission-script.lua`:

```lua
VeafCombatZone:new()
  :setName("Alpha")
  :setZoneName("ZONE-ALPHA")
  :setDescription("Strike Alpha — Armoured column")
  :initialize()
```

`veafCombatZone.initialize()` must be called at the module level first.

---

## Unit Name Tags

Unit and group names in the DCS Mission Editor can carry special tags that control how VEAF handles them when the zone activates. Tags are embedded in the name and do not affect DCS itself.

| Tag | Example | Description |
|-----|---------|-------------|
| `#spawnradius=N` | `#spawnradius=200` | Scatter radius in metres around the zone centre for this group |
| `#spawnchance=N` | `#spawnchance=50` | Percentage chance (0–100) this group will actually spawn |
| `#spawncount=N` | `#spawncount=3` | Number of instances to spawn (can be >1 for repeated units) |
| `#spawngroup="name"` | `#spawngroup="SAM"` | Override the spawn group name (useful to target a named template) |
| `#spawndelay=N` | `#spawndelay=120` | Delay in seconds before this group spawns after zone activation |
| `#command="cmd"` | `#command="-spawn sa-11"` | Execute a VEAF command instead of spawning this group; the unit acts as a trigger and is destroyed |

### Practical example — MANPADS ambush

You want four MANPADS positions in a zone, but only two should actually be occupied. Place four dummy infantry units named:

```
ALPHA-MANPAD-1 #spawnchance=50
ALPHA-MANPAD-2 #spawnchance=50
ALPHA-MANPAD-3 #spawnchance=50
ALPHA-MANPAD-4 #spawnchance=50
```

Each position has a 50% chance of spawning — statistically, around two will be active each time the zone is triggered.

### `#command` — spawning via VEAF marker syntax

The `#command` tag turns a unit into a one-shot trigger. When the zone activates, VEAF executes the command at the unit's position and destroys the unit. This is equivalent to dropping a map marker at that location.

```
SPAWN-SA11 #command="-spawn sa-11, side red"
CONVOY-TRIGGER #command="-convoy from ZONE-ALPHA to ZONE-BRAVO"
```

This lets you set up complex spawns (SA-11 battery, convoys with AI routes) without any Lua code.

---

## Module Constants

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

> **Security:** activate and deactivate commands require `/secu login` by default. [Training mode](#training-mode) removes this restriction. Info, smoke, and flare requests are always accessible without login.

### Radio menu options

| Method | Description |
|--------|-------------|
| `:disableRadioMenu()` | Disable the radio menu entirely for this zone |
| `:setRadioMenuPrefix(text)` | Prefix displayed before the zone name in the menu |
| `:setRadioGroup(name)` | Group zones under a common radio submenu |
| `:setEnableSmokeAndFlare(bool)` | Enable/disable smoke and flare requests (default: `true`) |
| `:setShowUnitsList(bool)` | Include remaining unit list in the info message (default: `true`) |
| `:setShowZonePositionInfo(bool)` | Include zone coordinates and weather in the info message (default: `true`) |

### Wreck cleanup

By default, vehicle wrecks and corpses are automatically removed when a zone is deactivated. To keep them:

```lua
:disableJunkCleanup()
```

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

`VeafCombatOperation` extends `VeafCombatZone` — all the builder methods above apply, and the operation itself appears in the radio menu as a single activatable entry.

---

## Zone Chaining

A zone can automatically activate one or more follow-on zones when it is completed. This lets you build dynamic campaign progressions without manual scripting:

```lua
VeafCombatZone:new()
  :setName("Strike Alpha")
  :setZoneName("ZONE-ALPHA")
  :addChainedCombatZone("Strike Bravo")     -- triggers when Alpha is done
  :addChainedCombatZone("Strike Charlie")   -- one is chosen at random
  :setChainedCombatZonesDelay(60)           -- wait 60 s before chaining
  :initialize()
```

When multiple chained zones are defined, **one is picked at random** — useful for branching narratives or avoiding predictability.

| Method | Description |
|--------|-------------|
| `:addChainedCombatZone(name)` | Add a zone to trigger after completion |
| `:setChainedCombatZonesDelay(s)` | Seconds to wait before chaining (default: 0) |

---

## Training Mode

Setting a zone to training mode changes two things:

- **No security**: any player can activate or deactivate the zone via the radio menu (normally the zone activation is logged and can be restricted by `/secu login`).
- **Verbose status**: the zone info message lists remaining units and their approximate positions (using smoke or bearings), giving pilots a clear picture of what is left.

```lua
VeafCombatZone:new()
  :setName("Training-A")
  :setZoneName("ZONE-TRAINING-A")
  :setTraining(true)
  :initialize()
```

Training mode is ideal for BFM / CAS training scenarios where pilots need to know unit positions.

---

- [veafCasMission](veafCasMission.md) — generated CAS zones (no pre-placed groups needed)
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCombatZone` API
