# veafCombatZone — Activatable Combat Zones


**Module ID:** `COMBATZONE` | **File:** `veafCombatZone.lua`

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

## Configuration (`mission.yaml`) {#configuration-missionyaml}

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
        radio_group_name: "North"          # gather same-named zones under one shared submenu
        radio_menu_prefix: "BLUE"          # prefix shown before the zone label
        briefing: "Destroy the armoured column."  # shown in mission info
        training: false                     # true = no security, verbose status
        active_at_start: true               # automatically activate the zone at mission start
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
| `radio_group_name` | string | — | No | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
| `radio_menu_prefix` | string | — | No | Prefix shown before the zone label in the menu |
| `briefing` | string | — | No | Briefing text shown to players |
| `training` | boolean | `false` | No | Training mode: no security, verbose status |
| `completable` | boolean | `true` | No | `false`: the zone never completes (nor deactivates) on its own |
| `enemy_coalition` | `RED` \| `BLUE` | `RED` | No | The **hostile** coalition: its units are the ones that must be destroyed for the zone to complete, and the ones the F10 report calls "enemies". Use `BLUE` for a zone played from the **red side** (see below) |
| `radio_menu_coalition` | `RED` \| `BLUE` \| `ALL` | *(the side playing the zone)* | No | Which coalition is offered the zone's F10 menu. Defaults to the opposite of `enemy_coalition`. `ALL` shows it to both sides (see below) |
| `active_at_start` | boolean | `false` | No | Automatically activate the zone at mission start (`veafCombatZone.ActivateZone` after `initialize()`) |
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

### A zone played from the red side {#red-side-zone}

By default a combat zone assumes the players are **blue** and the units to destroy are **red**.
Two behaviours followed from that: the zone completed once no red unit was left, and the F10
report labelled the blue tally "friends" and the red one "enemies".

`enemy_coalition: BLUE` flips both: the zone completes once its **blue** units are destroyed, and
the report calls the blue units "enemies" and the red ones "friends".

```yaml
modules:
  COMBATZONE:
    enabled: true
    combat_zones:
      - type: zone
        zone_name: "CZ-Kobuleti"
        friendly_name: "Kobuleti"
        enemy_coalition: BLUE   # players are red, blue are the enemies
```

Unit counting itself is unchanged — only the side the completion condition looks at. A zone that
says nothing behaves exactly as before.

> A zone holding no red unit previously needed `completable: false`, which did not make it a
> red-side zone: it merely switched auto-completion off, and the report still called the blue
> enemies "friends". `enemy_coalition` replaces that workaround.

In Lua the equivalent is `VeafCombatZone:setEnemyCoalition(coalition.side.BLUE)`; the setter also
accepts the `"blue"` / `"red"` string form.

### Who is offered the F10 menu? {#f10-menu-audience}

A zone's F10 menu is not read-only: it is how the zone gets **activated**, its status requested,
its smoke popped. So it is offered to the **side playing the zone** — the opposite of
`enemy_coalition`:

| `enemy_coalition` | F10 menu visible to |
|-------------------|---------------------|
| `RED` (default) | blue |
| `BLUE` | red |

Nothing to write to get that. To override it, use `radio_menu_coalition`:

```yaml
      - type: zone
        zone_name: "CZ-Alpha"
        radio_menu_coalition: ALL   # both sides see the zone and can activate it
```

`ALL` is what you want for an umpire or Mission Master sitting in a red slot who must be able to
trigger a blue zone. A side can also be named explicitly (`RED` / `BLUE`) when it is not the one
playing the zone.

> **Behaviour change (6.11.8)**: before this version every zone was offered to both sides. A
> mission whose player slots are all blue sees no difference; a mission with red slots that must
> keep access to the blue zones needs `radio_menu_coalition: ALL` on those zones.

The parent menu (`COMBAT ZONES`, and the `radio_group_name` submenu) stays visible to everyone: a
radio group may hold zones of both sides. So each side sees the `COMBAT ZONES` entry without the
other side's zones under it.

In Lua: `VeafCombatZone:setRadioMenuCoalition(coalition.side.RED)` or `"all"`.

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
  :setMissionEditorZoneName("ZONE-ALPHA")     -- DCS trigger zone name
  :setFriendlyName("Alpha")                    -- radio menu label
  :setBriefing("Strike Alpha — Armoured column")
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
| `#alarm=N` | `#alarm=2` | Alarm state given to this group: `0` AUTO (default), `1` GREEN, `2` RED |

### `#alarm` — making a group hold its ground {#alarm-state}

A ground group on **RED** alert stops and deploys: right for a SAM battery, wrong for a convoy, which then never leaves. Zones therefore spawn every group on **AUTO**, where DCS raises the group's own alert level when it detects something — a convoy drives its route, and a defence still fires once it sees a target.

Use `#alarm=2` on the groups you want dug in from the first second, typically air defence you would rather have radars up before the first pass:

```
ALPHA-SA6-BATTERY #alarm=2
ALPHA-SUPPLY-CONVOY
```

An unreadable or out-of-range value (`#alarm=7`, `#alarm=x`) falls back to AUTO rather than failing the zone.

!!! note "Only for mission groups"
    The tag applies to groups the zone spawns itself. On a `#command=` unit, pass the alarm state inside the command instead (`-spawn ..., alarm 2`), since the spawn is handled by the VEAF marker interpreter.

!!! warning "Behaviour change"
    Zones used to spawn **every** group on RED, which is why convoys placed in a combat zone never moved ([#290](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/290)). If a zone of yours relied on that — air defence that must be hot at activation — add `#alarm=2` to those groups.

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

In the most common case, elements are populated automatically from the units placed inside the DCS trigger zone via `:addZoneElementsFromZoneNamed(...)`:

```lua
local strikeZone = VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-STRIKE-ALPHA")  -- DCS trigger zone name
  :setFriendlyName("Strike Alpha")                 -- radio menu label
  :setBriefing("Destroy all vehicles. Expect AAA and MANPADS.")
  :addZoneElementsFromZoneNamed("ZONE-STRIKE-ALPHA")
  :initialize()
```

You can also build and attach an element manually with `:addZoneElement(...)`:

```lua
local element = VeafCombatZoneElement:new()
  :setName("STRIKE-ALPHA-ARMOR")
  :setDcsGroup(true)
  :setSpawnGroup("STRIKE-ALPHA-ARMOR")    -- DCS group name to spawn
  :setSpawnRadius(100)

strikeZone:addZoneElement(element)
```

### VeafCombatZone Builder Methods

| Method | Description |
|--------|-------------|
| `:setMissionEditorZoneName(name)` | DCS trigger zone that defines the spawn area |
| `:setFriendlyName(name)` | Label shown in the radio menu |
| `:setBriefing(text)` | Full briefing text |
| `:setOnCompletedHook(fn)` | Callback when all enemies destroyed |
| `:addZoneElement(element)` | Add an element to the zone |
| `:addZoneElementsFromZoneNamed(zoneName)` | Populate elements from the units of a trigger zone |
| `:addSpawnedGroup(groupOrName)` | Register an already-spawned group as belonging to the zone |
| `:setActive(bool)` | Activate the zone at start |
| `:setTraining(bool)` | Training mode |
| `:setCompletable(bool)` | Whether the zone can be marked as completed |
| `:enableUserActivation()` / `:disableUserActivation()` | Allow/forbid player activation |
| `:setRadioGroupName(name)` | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
| `:setRadioMenuPrefix(text)` | Prefix displayed before the zone name in the menu |

### VeafCombatZoneElement Builder Methods

| Method | Description |
|--------|-------------|
| `:setName(name)` | Element name |
| `:setPosition(pos)` | Element position |
| `:setDcsGroup(bool)` | The element references a DCS group |
| `:setDcsStatic(bool)` | The element references a DCS static object |
| `:setSpawnGroup(name)` | DCS group name to spawn |
| `:setVeafCommand(cmd)` | VEAF command to run instead of a spawn |
| `:setRoute(route)` | Element AI route |
| `:setCoalition(side)` | Element coalition |
| `:setSpawnRadius(m)` | Scatter radius around zone centre |
| `:setSpawnChance(pct)` | Spawn probability (0–100) |
| `:setSpawnCount(n)` | Number of instances to spawn |
| `:setSpawnDelay(s)` | Delay before spawn (seconds) |

---

## F10 Radio Menu (per zone)

- **Activate** — spawn the zone's unit groups
- **Deactivate** — despawn units, reset the zone
- **Info** — status, remaining unit count, briefing
- **Smoke** — mark zone with smoke (cooldown applies)
- **Flare** — mark zone with flares

> **Security:** activate and deactivate commands are secured by default: the group acts at the level of its lowest-graded occupant (see [veafSecurity](veafSecurity.en.md)). [Training mode](#training-mode) removes this restriction. Info, smoke, and flare requests are always accessible to everyone.

### Radio menu options

| Method | Description |
|--------|-------------|
| `:disableRadioMenu()` | Disable the radio menu entirely for this zone |
| `:setRadioMenuPrefix(text)` | Prefix displayed before the zone name in the menu |
| `:setRadioGroupName(name)` | Gather this zone (and every zone sharing the same name) under one shared radio submenu |
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
local operation = VeafCombatOperation:new()
  :setMissionEditorZoneName("OP-THUNDER")
  :setFriendlyName("Operation Thunder")
  :setBriefing("Destroy both armour columns before they reach Senaki.")

operation:addTaskingOrder(alphaZone)                 -- first task
operation:addTaskingOrder(bravoZone, { "OP-THUNDER-ALPHA" })  -- unlocked after Alpha
operation:initialize()
```

`VeafCombatOperation = VeafCombatZone:new()` — the operation extends `VeafCombatZone`. Tasks are added with `:addTaskingOrder(zone, requiredComplete)`, where `zone` is a `VeafCombatZone` and `requiredComplete` is the optional list of zone names that must complete before this one is activated. The operation appears in the radio menu as a single entry.

---

## Zone Chaining

A zone can automatically activate one or more follow-on zones when it is completed. This lets you build dynamic campaign progressions without manual scripting:

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-ALPHA")
  :setFriendlyName("Strike Alpha")
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

- **No security**: any player can activate or deactivate the zone via the radio menu (normally these commands are restricted to the group's effective level — see [veafSecurity](veafSecurity.en.md)).
- **Verbose status**: the zone info message lists remaining units and their approximate positions (using smoke or bearings), giving pilots a clear picture of what is left.

```lua
VeafCombatZone:new()
  :setMissionEditorZoneName("ZONE-TRAINING-A")
  :setFriendlyName("Training-A")
  :setTraining(true)
  :initialize()
```

Training mode is ideal for BFM / CAS training scenarios where pilots need to know unit positions.

---

## See Also

- [veafCasMission](veafCasMission.en.md) — generated CAS zones (no pre-placed groups needed)
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafCombatZone` API
