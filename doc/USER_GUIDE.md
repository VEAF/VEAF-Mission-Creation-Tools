# VEAF Mission Creation Tools - User Guide

**Version:** 6.0.5
**Date:** December 16, 2025
**Project:** VEAF (Virtual European Air Force)

---

## 📋 Table of Contents

### For Players
1. [Introduction](#introduction)
2. [Getting Started with VEAF](#getting-started-with-veaf)
3. [F10 Radio Menu](#f10-radio-menu)
4. [Marker Commands](#marker-commands)
5. [Main Features](#main-features)
6. [Mission Guide](#mission-guide)
7. [Resources and Support](#resources-and-support)

### For Mission Makers
8. [Mission Maker Guide](#mission-maker-guide)
9. [Mission Setup](#mission-setup)
10. [Build Tools](#build-tools)
11. [Advanced Customization](#advanced-customization)
12. [Troubleshooting](#troubleshooting)

---

# For Players

## Introduction

### What is VEAF?

VEAF Mission Creation Tools is a script framework for DCS World that makes missions **dynamic and interactive**. Instead of playing a static mission created in the editor, you can:

- 🎯 **Spawn enemy units** on demand
- ✈️ **Create combat missions** (air-to-air and air-to-ground)
- 🎮 **Interact** with the environment via radio menu (F10)
- 🗺️ **Use map markers** on the F10 map to issue commands
- 🚁 **Manage resources** (tankers, AWACS, carriers)
- 🎲 **Generate procedural content** for infinite replayability

### Key Features

| Feature | Description |
|---------|-------------|
| **Dynamic Spawning** | Create enemies, convoys, CAP flights anytime |
| **CAS Missions** | Generate CAS combat zones with variable difficulty |
| **Managed Assets** | Control tankers, AWACS and carriers via F10 |
| **Dynamic Weather** | Inject real-world weather into your missions |
| **Radio Menu** | Complete interface via F10 menu |
| **Security** | Permission system for multiplayer servers |
| **Transport** | Transport missions with CTLD (cargo/troops) |
| **Combat Zones** | Predefined zones activatable on demand |

---

## Getting Started with VEAF

### Recognizing a VEAF Mission

When you load a VEAF mission, you'll see:

1. **Startup messages** indicating loaded VEAF modules
2. **F10 "VEAF" menu** with multiple submenus
3. **Map markers** on F10 map with information (tankers, zones, etc.)

### First Flight

**Startup checklist:**

1. ✅ Start your aircraft normally
2. ✅ Press **F10** to open radio menu
3. ✅ Navigate to **F10 → VEAF** to see options
4. ✅ Press **F10 → F1** to close menu and continue

**Tip:** Explore submenus to discover what's available in this mission.

---

## F10 Radio Menu

### VEAF Menu Structure

```
F10 - Radio Menu
├── VEAF (main menu)
│   ├── Assets (tankers, AWACS, carriers)
│   ├── Missions (activatable missions)
│   ├── CAS Mission (CAS generator)
│   ├── Spawn (if enabled)
│   ├── Weather (weather)
│   └── Help (help)
```

### Navigation

- **F10**: Opens radio menu
- **F1-F9**: Selects an option
- **F10 or Esc**: Closes menu

### Common Submenus

#### 🛢️ Assets

Manages airborne resources:

- **Tankers**:
  - Info: Position, TACAN, radio frequency
  - Respawn: Respawn tanker if destroyed

- **AWACS**:
  - Info: Position, radio frequency
  - Respawn: Respawn AWACS

- **Carriers** (aircraft carriers):
  - Info: Position, heading, BRC, TACAN, ICLS
  - Start Recovery: Turn carrier into wind
  - Stop Recovery: Resume normal navigation

**Usage example:**
```
F10 → VEAF → Assets → Tankers → Texaco → Info
Result: Displays "Texaco-1 | KC-135 | TACAN 61X | 251.0 MHz AM | Position N42°15' E041°30'"
```

#### 🎯 Missions

Activates missions predefined by the mission maker:

- **List**: See all available missions
- **Activate**: Start a mission
- **Deactivate**: Stop an active mission
- **Info**: Details about a mission (objectives, status)

Missions can include:
- Air-to-air combat (CAP, Intercept)
- Ground strikes (Strike, SEAD)
- CAS (Close Air Support)
- Transport (Cargo, Troops)

#### 🎲 CAS Mission

CAS training mission generator:

- **Generate**: Creates a new target zone
- **Smoke**: Marks zone with smoke
- **Flare**: Marks zone with flares
- **Skip**: Skip to next target
- **Info**: Current target information
- **Cleanup**: Cleans up CAS mission

**Difficulty options:**
- **Size** (0-5): Number of units
- **Defense** (0-5): AA defense level
- **Armor** (0-5): Armor level

#### 🌤️ Weather

If enabled, allows you to:
- Check weather conditions
- Modify weather (mission maker)

---

## Marker Commands

### Principle

On some missions, you can **place F10 markers** on the map with **text commands** to interact with the mission.

### How To

1. **Open F10 map**
2. **Right-click** on map → "Add marker"
3. **Type a command** in marker text
4. **Validate** - command executes and marker disappears

### Basic Commands

#### Individual Unit Spawning: `_spawn unit`

**Syntax:** `_spawn unit, name [TYPE], [OPTIONS]`

**Examples:**

```
_spawn unit, name F-16C, group 2
→ Spawns 2 F-16Cs at marker position

_spawn unit, name SA-6
→ Spawns an SA-6 battery

_spawn unit, name M1 Abrams, group 4, hdg 270
→ Spawns 4 M1 Abrams tanks facing 270°

_spawn unit, name MiG-29S, alt 5000, hdg 090, speed 450
→ Spawns MiG-29S at 5000ft, heading 090°
```

**Common options:**

| Option | Description | Example |
|--------|-------------|---------|
| `name [TYPE]` | DCS unit type (required) | `name F-16C` |
| `group [N]` | Number of units | `group 4` |
| `hdg [DEGREES]` | Heading in degrees | `hdg 270` |
| `alt [FEET]` | Altitude in feet | `alt 15000` |
| `speed [KNOTS]` | Speed in knots | `speed 450` |
| `country [NAME]` | Country | `country USA` |
| `side [blue/red]` | Coalition | `side red` |

**Note:** `_spawn unit` creates DCS units directly. To spawn **predefined groups** from the `spawnables.yaml` file, use `_spawn group` (see below).

#### Predefined Group Spawning: `_spawn group`

**Syntax:** `_spawn group, name [GROUP_NAME], [OPTIONS]`

**Examples:**

```
_spawn group, name CAP-2
→ Spawns CAP-2 group defined in spawnables.yaml

_spawn group, name ARMOR-PLATOON, hdg 270
→ Spawns armor platoon facing 270°

_spawn group, name RED-SAM-SITE
→ Spawns predefined SAM site
```

**Description:** Groups must be defined in the mission's `spawnables.yaml` file. This command allows reusing predefined unit compositions created by the mission maker.

#### CAP Patrol: `_spawn cap`

**Syntax:** `_spawn cap, name [AIRCRAFT], [OPTIONS]`

**Examples:**

```
_spawn cap, name F-15C, alt 25000, hdg 090, speed 450, capradius 20000
→ Spawns F-15C CAP patrol at 25000ft with 20km orbit

_spawn cap, name Su-27, group 2, alt 30000, capradius 25000
→ Spawns 2 Su-27s on CAP at 30000ft
```

**Specific options:**
- `capradius [METERS]`: CAP orbit radius
- `distance [METERS]`: Orbit distance from marker

#### AFAC (Airborne Controller): `_spawn afac`

**Syntax:** `_spawn afac, name [AIRCRAFT], [OPTIONS]`

**Examples:**

```
_spawn afac, name A-10C, alt 15000, speed 250, freq 133.0, mod AM, code 1688
→ Spawns A-10C AFAC with lasing code 1688 on 133.0 AM

_spawn afac, name L-39ZA, freq 135.0, code 1584, immortal
→ Spawns invulnerable L-39 AFAC
```

**Specific options:**
- `code [XXXX]`: Laser code (e.g., 1688)
- `freq [MHZ]`: Radio frequency
- `mod [AM/FM]`: Radio modulation
- `immortal`: Makes AFAC invulnerable

#### Convoy Spawning: `_spawn convoy`

**Syntax:** `_spawn convoy, [OPTIONS], dest [MARKER]`

**Example:**
```
Marker 1 (start position):
_spawn convoy, name Convoy1, dest marker2, speed 50, defense 2

Marker 2 (destination):
(just an empty marker as destination point)

→ Spawns a convoy moving from marker 1 to marker 2 at 50 km/h
```

**Convoy options:**

| Option | Description |
|--------|-------------|
| `dest [MARKER]` | Destination (marker number or name) |
| `speed [KMH]` | Speed in km/h |
| `patrol` | Return to start after arrival |
| `offroad` | Allow off-road movement |
| `defense [0-5]` | AA defense level |
| `armor [0-5]` | Armor level |
| `size [0-5]` | Convoy size |

#### CAS Mission: `_cas`

**Syntax:** `_cas, [OPTIONS]`

**Example:**
```
_cas, size 3, defense 2, armor 3
→ Generates medium CAS zone with moderate defense and armor
```

**Options:**
- `size [0-5]`: Force size (0=small, 5=huge)
- `defense [0-5]`: AA defense (0=none, 5=heavy SAM)
- `armor [0-5]`: Armor (0=infantry, 5=heavy tanks)
- `side [blue/red]`: Coalition

#### Effects: Smoke, Explosions, Illumination

**Smoke:**
```
_spawn smoke, color red
→ Red smoke at position

_spawn smoke, color green, shells 5
→ 5 green smoke grenades
```

**Available colors:** `red`, `green`, `blue`, `white`, `orange`

**Explosions:**
```
_spawn bomb, power 500, shells 3
→ 3x 500kg explosions

_spawn bomb, power 1000, radius 100
→ 1000kg explosion dispersed over 100m
```

**Illumination:**
```
_spawn flare, power 1000000, shells 5, heading 90, distance 500
→ 5 illumination flares spaced 500m on heading 090°
```

#### Destruction: `_destroy`

**Syntax:** `_destroy, [OPTIONS]`

**Examples:**
```
_destroy, radius 500
→ Destroys all units within 500m radius

_destroy, name Tank-1
→ Destroys unit named "Tank-1"
```

#### Teleportation: `_teleport`

**Syntax:** `_teleport, name [GROUP_NAME]`

**Example:**
```
_teleport, name Viper Flight
→ Teleports group "Viper Flight" to marker position
```

### Named Markers

You can **name your markers** to reference them:

```
Marker "Zone Alpha":
(zone position)

Command marker:
_spawn convoy, dest "Zone Alpha", speed 40
→ Convoy moves to marker named "Zone Alpha"
```

---

## Main Features

### 🛢️ Air Refueling

**Finding a Tanker:**

1. F10 → VEAF → Assets → Tankers → [NAME] → Info
2. Note the **TACAN** and **radio frequency**
3. Contact tanker on its frequency (SRS if enabled)

**Typical Tanker Information:**
- **Position:** Displayed in coordinates
- **TACAN:** Ex: 61X (1088 MHz)
- **Radio:** Ex: 251.0 MHz AM
- **Type:** KC-135, KC-130, S-3B, etc.

**Tips:**
- Tankers typically fly in orbit
- Typical altitude: 20,000 - 25,000 ft
- Approach from behind and below

### 📡 AWACS

**Usage:**

1. F10 → VEAF → Assets → AWACS → [NAME] → Info
2. Contact AWACS on its frequency
3. Request vectors to threats

**AWACS Information:**
- **Callsign:** Ex: Magic, Overlord
- **Frequency:** Ex: 133.0 MHz AM
- **Position:** Patrol zone

### 🚢 Carrier Operations

**Carrier Recovery:**

1. **10-15 minutes before recovery:**
   - F10 → VEAF → Assets → Carriers → [NAME] → Start Recovery

2. **Displayed information:**
   - BRC (Base Recovery Course): Carrier heading
   - Relative wind (should be ~30 kts into wind)
   - TACAN: Ex: 73X
   - ICLS: Ex: 13
   - ATC frequency: Ex: 127.5 MHz AM

3. **After recovery:**
   - F10 → VEAF → Assets → Carriers → [NAME] → Stop Recovery

**Tips:**
- Carrier automatically turns into wind
- Use TACAN for navigation
- ICLS for approach (F/A-18C)
- Marshal on 127.5 MHz typically

### 🎯 Combat Missions

**Activating a Mission:**

1. F10 → VEAF → Missions → List
2. Read available mission descriptions
3. F10 → VEAF → Missions → [MISSION NAME] → Activate
4. Read displayed briefing
5. F10 → VEAF → Missions → [MISSION NAME] → Info (for status)

**Typical Mission Example:**

**"Strike Alpha - Destroy Armor Column"**
- **Briefing:** "Enemy armor advancing on friendly position at Grid XY1234. Destroy all tanks. Expect heavy AAA defense."
- **Objectives:**
  1. Destroy all enemy tanks (0/8)
  2. RTB safely
- **Status:** In progress / Completed / Failed

**Deactivating a Mission:**

F10 → VEAF → Missions → [MISSION NAME] → Deactivate

### 🎲 CAS Training

**Typical Scenario:**

1. **Target generation:**
   - F10 → VEAF → CAS Mission → Generate
   - Choose difficulty (or leave random)

2. **Zone marking:**
   - F10 → VEAF → CAS Mission → Smoke
   - OR F10 → VEAF → CAS Mission → Flare
   - *Cooldown: 3 minutes between marks*

3. **Information:**
   - F10 → VEAF → CAS Mission → Info
   - Displays: position, composition, status

4. **Engagement:**
   - Attack marked targets
   - Units may disperse when attacked

5. **Next target:**
   - If too difficult: F10 → CAS Mission → Skip
   - OR destroy all units to auto-advance

6. **Cleanup:**
   - F10 → VEAF → CAS Mission → Cleanup (removes all units)

**Difficulty Levels:**

| Level | Size | Defense | Armor | Description |
|-------|------|---------|-------|-------------|
| 0 | Very small | None | Infantry | Perfect beginner |
| 1 | Small | Light | Light vehicles | Easy |
| 2 | Medium | Moderate | APCs | Intermediate |
| 3 | Medium-Large | Medium AA | IFVs + light tanks | Advanced |
| 4 | Large | Heavy AA | Medium tanks | Difficult |
| 5 | Huge | SAM | Heavy tanks | Expert |

### 🚁 Transport and Logistics (CTLD)

If CTLD is enabled in mission:

**Loading Cargo:**

1. Land near loading zone (FARP, base)
2. F10 → CTLD → Load Cargo
3. Choose cargo type
4. Take off to destination

**Unloading:**

1. Hover over delivery zone
2. F10 → CTLD → Unload Cargo
3. Cargo is paradropped or delivered

**Cargo Types:**
- **Troops**: Troops (can capture zones)
- **Vehicles**: Vehicles
- **Crates**: Crates (ammo, fuel)
- **FOB**: Forward Operating Base

### 📻 Radio Communication (SRS)

If **Simple Radio Standalone (SRS)** is installed:

**Features:**
- Realistic VOIP communication
- Tankers respond to calls
- AWACS gives vectors
- ATC for carriers
- Automatic message transmission

**Setup:**
1. Launch SRS before DCS
2. Radio frequencies are auto-synced
3. Use your in-game radio to communicate

### 🔐 Security and Permissions

On **multiplayer servers**, some commands may be **restricted**:

**Public Commands:**
- Asset info
- Activating predefined missions
- Smoke/flare marking

**Restricted Commands (require password):**
- Unit spawning
- Weather modification
- Teleportation
- Destruction

**Usage:**
```
_spawn unit, name F-16C, password [PASSWORD]
```

Password is set by mission maker or server admin.

---

## Mission Guide

### VEAF Mission Types

#### 🔵 "Sandbox" Missions

**Characteristics:**
- No predefined objectives
- Free unit spawning via markers
- Perfect for training
- Create your own scenario

**Typical Usage:**
1. Take off
2. Place markers to spawn enemies
3. Engage as desired
4. Create new scenarios at will

#### 🎯 Objective-Based Missions

**Characteristics:**
- Predefined objectives
- Tracked progression
- Victory/defeat conditions
- Detailed briefings

**Usage:**
1. Read startup briefing
2. Activate missions via F10
3. Track progress via Info
4. Complete objectives

#### 🌐 Dynamic Missions

**Characteristics:**
- Activatable combat zones
- Procedurally generated enemies
- Infinite replayability
- Variable difficulty

**Usage:**
1. Choose a combat zone
2. Activate zone via F10
3. Enemies spawn dynamically
4. Deactivate to cleanup

### Tips by Aircraft Type

#### ✈️ Fighter Aircraft (Air-to-Air)

**F-16C, F/A-18C, F-15C:**

**Recommended Missions:**
- CAP (Combat Air Patrol)
- Intercept
- Escort

**VEAF Usage:**
```
Spawn enemy aircraft:
_spawn cap, name Su-27, group 2, alt 25000, hdg 180, speed 450, capradius 25000
→ Generates enemy patrol

F10 → VEAF → Missions → CAP Alpha → Activate
→ Activates predefined intercept mission
```

**Tips:**
- Use AWACS for vectors
- Refuel before engaging
- Spawn enemy CAP at distance for realistic simulation

#### 💣 Attack Aircraft (Air-to-Ground)

**A-10C, F/A-18C, F-16C:**

**Recommended Missions:**
- CAS
- Strike
- SEAD

**VEAF Usage:**
```
Generate CAS zone:
F10 → VEAF → CAS Mission → Generate → Difficulty 3

OR place marker:
_cas, size 3, defense 2, armor 3

Mark zone:
F10 → VEAF → CAS Mission → Smoke
```

**Tips:**
- Start with low difficulty (0-2)
- Request smoke to locate
- Watch for AA defenses (level 3+)

#### 🚁 Helicopters

**AH-64D, Ka-50, Mi-24P:**

**Recommended Missions:**
- Close CAS
- Transport (Mi-8)
- Anti-tank

**VEAF Usage:**
```
Spawn helo targets:
_spawn unit, name BTR-80, group 5, spacing 50
→ Dispersed APCs, perfect for helo engagement

_cas, size 2, defense 1, armor 2
→ CAS adapted for helos (limited AA defense)
```

**Tips:**
- Stay at difficulty 0-2 (light AA defense)
- Use terrain masking
- Engage at max range from AA guns

#### 🛩️ Transport

**C-130, Mi-8, UH-1H:**

**Recommended Missions:**
- Troop/cargo transport
- Resupply
- CASEVAC

**VEAF Usage:**
```
Spawn destination FARP:
_spawn farp, name FARP Alpha, side blue

Activate CTLD:
F10 → CTLD → Load Troops
(near base)

Deliver:
F10 → CTLD → Deploy Troops
(above FARP Alpha)
```

---

## Resources and Support

### 📖 Documentation

- **VEAF Website:** https://www.veaf.org
- **Full Documentation:** https://veaf.github.io/documentation/
- **GitHub:** https://github.com/VEAF/VEAF-Mission-Creation-Tools

### 💬 Community

- **VEAF Discord:** https://www.veaf.org/discord
  - #support channel for help
  - #missions channel to share creations
  - French and international community

- **Forum:** https://www.veaf.org/forum

### 🎓 Tutorials

**On Discord/YouTube:**
- Basic tutorial videos
- Mission-specific guides
- Demonstration streams

### ❓ Player FAQ

**Q: How do I know if a mission uses VEAF?**
A: Check F10 menu - if there's a "VEAF" menu, it's a VEAF mission.

**Q: Why don't my markers work?**
A:
- Check command syntax
- On servers, you may need a password
- Some missions disable spawn markers

**Q: How do I know which aircraft types to spawn?**
A: Use standard DCS names: "F-16C", "Su-27", "MiG-29S", etc.

**Q: Spawned units disappear?**
A: Normal if you get too far. Stay within 40-50 NM radius.

**Q: How to reset a CAS mission?**
A: F10 → VEAF → CAS Mission → Cleanup, then Generate again.

**Q: Can I spawn allies?**
A: Yes, use `side blue` in your spawn command.

---

# For Mission Makers

## Mission Maker Guide

### 🎯 What is a VEAF Mission Maker?

As a **DCS mission creator**, VEAF allows you to:

- ✅ **Reduce creation time** by 80%
- ✅ **Create replayable missions** infinitely
- ✅ **Automate** spawning, weather, assets
- ✅ **Customize** mission behavior
- ✅ **Manage** multiplayer servers easily
- ✅ **Integrate** community systems (CTLD, CSAR, Skynet IADS)

### VEAF Philosophy

**Static Missions vs VEAF:**

| Aspect | Static Mission | VEAF Mission |
|--------|----------------|--------------|
| **Creation** | Place each unit manually | Define spawn rules |
| **Replayability** | Always identical | Different each time |
| **Complexity** | Simple but limited | Rich and flexible |
| **.miz Size** | Heavy (many units) | Light (scripts) |
| **Maintenance** | Difficult (re-edit) | Easy (config files) |

**VEAF Approach:**
1. **Define** zones, assets, rules
2. **Configure** via simple YAML files
3. **Let** players generate content dynamically

---

## Mission Setup

### Prerequisites

**Required Software:**
- ✅ DCS World (stable or open beta)
- ✅ DCS Mission Editor
- ✅ Text editor (VS Code recommended)
- ✅ VEAF Mission Creation Tools (latest version)

**Download:**
- **GitHub Releases:** https://github.com/VEAF/VEAF-Mission-Creation-Tools/releases
- Download `published.zip`
- Extract to working folder

### VEAF Mission Structure

```
MyMission/
├── src/                          # Source folder
│   ├── mission/                  # DCS mission
│   │   └── mission.lua           # Main mission script
│   ├── scripts/                  # Custom scripts
│   │   ├── missionConfig.lua     # Mission configuration
│   │   └── veafDynamicConfig.lua # Dynamic config
│   ├── presets.yaml              # Radio presets
│   ├── spawnables.yaml           # Spawnable groups
│   ├── waypoints.yaml            # Navigation points
│   └── versions.yaml             # Component versions
└── MyMission.miz                 # Compiled mission file
```

### Step 1: Create Base Mission

**In DCS Editor:**

1. **Create new mission**
   - Choose theater (Caucasus, Persian Gulf, Syria, etc.)
   - Set base weather
   - Place player aircraft (client slots)

2. **Add Base Assets** (optional but recommended)
   - Tankers: Place KC-135, KC-130 in orbit
   - AWACS: E-3A, E-2D in orbit
   - Carriers: CVN-73, CVN-74 navigating

3. **Define Trigger Zones** (for VEAF)
   - Spawn zones
   - Combat zones
   - CAS zones
   - Security zones

4. **Save** mission: `MyMissionBase.miz`

### Step 2: Prepare VEAF Structure

**Create source folder:**

1. **Create** folder `MyMission/src/`

2. **Extract** `.miz` file:
   - A `.miz` file is a ZIP
   - Rename `.miz` → `.zip`
   - Extract to `src/mission/`

3. **Copy** default config files from VEAF:
   ```
   VEAF-Mission-Creation-Tools/src/defaults/mission-folder/
   → Copy all to MyMission/src/
   ```

### Step 3: Basic Configuration

#### File `missionConfig.lua`

**Location:** `src/scripts/missionConfig.lua`

**Configuration example:**

```lua
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Mission Configuration: Strike Training
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Mission name
veaf.config.MISSION_NAME = "Strike Training - Caucasus"

-- Player coalition (default)
veaf.config.DEFAULT_COALITION = coalition.side.BLUE

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF Modules to Load
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Core (always required)
veaf.config.LOAD_VEAF_CORE = true
veaf.config.LOAD_VEAF_MARKERS = true
veaf.config.LOAD_VEAF_EVENT_HANDLER = true

-- Spawn
veaf.config.LOAD_VEAF_SPAWN = true  -- Enable spawn via markers
veaf.config.VEAF_SPAWN_ALLOW_PUBLIC = false  -- Requires password

-- Missions
veaf.config.LOAD_VEAF_COMBAT_MISSION = true  -- Predefined missions
veaf.config.LOAD_VEAF_CAS_MISSION = true     -- CAS generator

-- Assets
veaf.config.LOAD_VEAF_ASSETS = true          -- Tanker/AWACS management

-- Carrier
veaf.config.LOAD_VEAF_CARRIER_OPERATIONS = true  -- If carrier present

-- Transport
veaf.config.LOAD_CTLD = true                 -- CTLD for transport

-- Weather
veaf.config.LOAD_VEAF_WEATHER = false        -- No dynamic weather

-- Security
veaf.config.LOAD_VEAF_SECURITY = true
veaf.config.VEAF_SECURITY_PASSWORD = "strike2024"  -- Spawn password

-- Misc
veaf.config.LOAD_VEAF_RADIO = true           -- Radio menus
veaf.config.LOAD_VEAF_SHORTCUTS = true       -- Command shortcuts

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Assets Configuration
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Tankers
veafAssets.Assets = {
    -- Tanker Texaco (Blue)
    {
        name = "Texaco-1",
        description = "KC-135 Tanker",
        information = "TACAN 61X | 251.0 MHz AM",
        disposable = false,  -- Cannot be destroyed
        linked = {}          -- Linked groups (respawn together)
    },

    -- Tanker Shell (Blue)
    {
        name = "Shell-1",
        description = "KC-130 Tanker",
        information = "TACAN 62X | 252.0 MHz AM",
        disposable = false
    },

    -- AWACS
    {
        name = "Magic-1",
        description = "E-3A AWACS",
        information = "133.0 MHz AM",
        disposable = false
    }
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Combat Zones Configuration
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Combat zone activatable via F10
local combatZone1 = veafCombatZone:new()
combatZone1:setName("Batumi Sector")
combatZone1:setDescription("Enemy forces attacking Batumi")
combatZone1:setBriefing("Destroy enemy ground forces advancing on Batumi airbase")
combatZone1:setZone("COMBAT_ZONE_BATUMI")  -- DCS trigger zone name
combatZone1:setCoalition(coalition.side.RED)
combatZone1:setCountry(country.id.RUSSIA)

-- Add zone
veafCombatZone.AddZone(combatZone1)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Missions Configuration
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- CAP Mission
local missionCAP1 = veafCombatMission:new()
missionCAP1:setName("CAP Alpha")
missionCAP1:setDescription("Eliminate enemy CAP")
missionCAP1:setBriefing("Enemy fighters patrolling north of Batumi. Destroy all hostile aircraft.")
missionCAP1:setSpawnZone("CAP_SPAWN_ZONE")  -- DCS zone
missionCAP1:setRadioMenuEnabled(true)        -- Visible in F10
missionCAP1:setSecured(false)                -- No password required

-- Objective: Destroy enemies
local objective1 = VeafCombatMissionObjective:new()
objective1:setName("Destroy Enemy CAP")
objective1:setDescription("All enemy fighters destroyed")

missionCAP1:addObjective(objective1)
veafCombatMission.AddMission(missionCAP1)

-- Generate variants (difficulty)
veafCombatMission.AddMissionsWithSkillAndScale(
    missionCAP1,
    false,  -- Don't include original
    {"Average", "Good", "High"},      -- Skill levels
    {0.5, 1.0, 1.5}                   -- Scale factors
)
-- Result: 9 missions (3 skills × 3 scales)

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Initialization
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Everything will be initialized automatically by VEAF
```

#### File `presets.yaml`

**Location:** `src/presets.yaml`

**Example:**

```yaml
radios_collection:
  # Presets for Blue coalition
  blue_radios:
    # UHF Radio (30-399 MHz)
    radio_uhf_30:
      title: UHF
      type: uhf
      channels:
        01:
          name: Guard/UHF
          frequency: 243.0
          modulation: AM
        02:
          name: Texaco
          frequency: 251.0
          modulation: AM
        03:
          name: Shell
          frequency: 252.0
          modulation: AM
        04:
          name: Magic AWACS
          frequency: 133.0
          modulation: AM
        05:
          name: Batumi Tower
          frequency: 131.0
          modulation: AM
        # ... up to 20 channels

    # VHF Radio (30-87 MHz)
    radio_vhf_30:
      title: VHF
      type: vhf_am
      channels:
        01:
          name: Guard/VHF
          frequency: 121.5
          modulation: AM
        02:
          name: Tac 1
          frequency: 135.0
          modulation: AM
        # ...

  # Presets for Red coalition (optional)
  red_radios:
    radio_uhf_30:
      title: UHF
      type: uhf
      channels:
        01:
          name: Guard
          frequency: 243.0
          modulation: AM
        # ...
```

**Inject into mission:**

```bash
# Command line
veaf-tools.exe inject-presets src/presets.yaml src/mission/mission.lua

# Or via automatic build (see Build section)
```

### Step 4: Advanced Configuration

#### Security Zones

**In `missionConfig.lua`:**

```lua
-- Sanctuaries (zones where units cannot be attacked)
veafSanctuary.AddZone(
    "SAFE_ZONE_KUTAISI",  -- DCS trigger zone name
    true,                 -- Protects Blue
    false                 -- Doesn't protect Red
)

-- Protected zone around Kutaisi airfield
```

#### Community Systems

**CTLD (Transport Helicopters):**

```lua
-- In missionConfig.lua
veaf.config.LOAD_CTLD = true

-- CTLD configuration
ctld.hoverPickup = true              -- Pickup in hover
ctld.enableCrates = true             -- Enable crates
ctld.slingLoad = true                -- Sling loading (compatible helos)
ctld.enableSmokeDrop = true          -- Marking smoke

-- Pickup zones
ctld.logisticUnits = {
    "FARP Alpha",     -- FARP group name in mission
    "FARP Bravo"
}

-- Deployment zones
ctld.deployableFOBs = {
    "FOB Zone 1",     -- Zones where FOB can be deployed
    "FOB Zone 2"
}
```

---

## Build Tools

### veaf-tools CLI

**veaf-tools** is the command-line tool to automate mission creation.

#### Installation

1. **Download** `published.zip` from GitHub Releases
2. **Extract** `veaf-tools.exe` to your working folder
3. **Test**:

```bash
veaf-tools.exe --version
# Result: veaf-tools version 6.0.4
```

#### Command: Prepare Mission

**Create base structure:**

```bash
veaf-tools.exe prepare "D:\DCS\Missions\MyMission"
```

**Result:**
```
✓ Folder created: MyMission/src/
✓ Folder created: MyMission/src/mission/
✓ Folder created: MyMission/src/scripts/
✓ Config files copied
✓ presets.yaml created
✓ spawnables.yaml created
✓ waypoints.yaml created
✓ versions.yaml created
```

#### Command: Inject Radio Presets

**Inject `presets.yaml` into mission:**

```bash
veaf-tools.exe inject-presets "MyMission\src\presets.yaml" "MyMission\src\mission\mission.lua"
```

**Result:**
- Radio frequencies automatically configured in all player aircraft
- Channel 1 = frequency 1, Channel 2 = frequency 2, etc.

#### Command: Build Complete Mission

**Assemble all elements and create .miz:**

```bash
veaf-tools.exe build-mission "MyMission\src" "MyMission\MyMission.miz"
```

**Automatic steps:**
1. ✅ Load `src/mission/`
2. ✅ Inject VEAF scripts
3. ✅ Apply `missionConfig.lua`
4. ✅ Inject radio presets
5. ✅ Inject waypoints
6. ✅ Compile to `.miz`

**Result:**
```
✓ Mission compiled: MyMission.miz (12.5 MB)
✓ Ready for DCS World
```

### Automated Build Script

**Create `build.bat` file:**

```batch
@echo off
echo ========================================
echo Build VEAF Mission: Strike Training
echo ========================================

set MISSION_DIR=D:\DCS\Missions\StrikeTraining
set VEAF_TOOLS=D:\VEAF\veaf-tools.exe

echo.
echo [1/3] Injecting radio presets...
%VEAF_TOOLS% inject-presets "%MISSION_DIR%\src\presets.yaml" "%MISSION_DIR%\src\mission\mission.lua"

echo.
echo [2/3] Injecting waypoints...
%VEAF_TOOLS% inject-waypoints "%MISSION_DIR%\src\waypoints.yaml" "%MISSION_DIR%\src\mission\mission.lua"

echo.
echo [3/3] Building final mission...
%VEAF_TOOLS% build-mission "%MISSION_DIR%\src" "%MISSION_DIR%\StrikeTraining.miz"

echo.
echo ========================================
echo Build complete!
echo ========================================
echo File: %MISSION_DIR%\StrikeTraining.miz
pause
```

**Usage:**
```bash
build.bat
```

---

## Advanced Customization

### Creating Complex Missions

See the French version for detailed examples of:
- Multi-objective missions
- Timed missions
- Custom event handling
- Dynamic zones
- Procedural mission generation

---

## Troubleshooting

### Common Problems

#### Mission won't load

**Symptoms:**
- Black screen on loading
- Return to main menu
- Error message

**Solutions:**

1. **Check DCS logs:**
   - `Saved Games/DCS/Logs/dcs.log`
   - Search for "error" or "VEAF"

2. **Check Lua syntax:**
   ```lua
   -- Common error: missing comma
   local bad = {
       name = "Test"
       description = "Test"  -- ERROR: missing comma on previous line
   }

   -- Correct:
   local good = {
       name = "Test",        -- Comma
       description = "Test"
   }
   ```

3. **Check zone names:**
   - Trigger zone names are case-sensitive
   - Verify they exist in DCS mission

4. **VEAF version:**
   - Use latest version
   - Check DCS compatibility (stable vs open beta)

#### Markers don't work

**Symptoms:**
- Marker placed but nothing happens
- No error message

**Solutions:**

1. **Verify module is loaded:**
   ```lua
   veaf.config.LOAD_VEAF_SPAWN = true
   veaf.config.LOAD_VEAF_MARKERS = true
   ```

2. **Check command syntax:**
   ```
   Correct: _spawn unit, name F-16C, group 2
   Incorrect: _spawn, name F-16C, group 2  (missing "unit" keyword)
   Incorrect: spawn unit, name F-16C, group 2  (missing "_")
   ```

3. **Check security:**
   ```lua
   -- If spawn secured
   veaf.config.VEAF_SPAWN_ALLOW_PUBLIC = false

   -- Player must use:
   _spawn unit, name F-16C, password YOUR_PASSWORD
   ```

### Debug and Logging

#### Enable Detailed Logs

**In `missionConfig.lua`:**

```lua
-- Enable trace logging for all modules
veaf.loggers.setBaseLevel("trace")

-- Or for specific module
veafSpawn.LogLevel = "trace"
veafCombatMission.LogLevel = "debug"
```

**Logs available in:**
- `Saved Games/DCS/Logs/dcs.log`

### Support and Community

**Getting Help:**

1. **VEAF Discord:** https://www.veaf.org/discord
   - #support-mission-makers channel
   - Quick community response

2. **GitHub Issues:** https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues
   - For bugs and feature requests

3. **VEAF Forum:** https://www.veaf.org/forum
   - In-depth discussions
   - Mission sharing

**Providing Information:**

When requesting help, include:
- VEAF version (in logs)
- DCS version (stable/open beta)
- `missionConfig.lua` file
- `dcs.log` logs (relevant part)
- Detailed problem description
- Steps to reproduce

---

## Additional Resources

### Mission Templates

**Available on GitHub:**
- Basic CAS mission
- Multi-zone CAP mission
- CTLD transport mission
- Complete dynamic mission

**Link:** https://github.com/VEAF/VEAF-Mission-Creation-Tools/tree/master/examples

### Documentation

- **[developer/GUIDE.md](developer/GUIDE.md)** - Complete technical manual, build workflow and system architecture
- **[LUA_API_REFERENCE.md](LUA_API_REFERENCE.md)** - Complete Lua API reference
- **[TOOLS_REFERENCE.md](TOOLS_REFERENCE.md)** - CLI tools reference
- **[TESTING.md](TESTING.md)** - Testing infrastructure

---

## Conclusion

### For Players

VEAF transforms your DCS experience by giving you **control** over the mission. Instead of experiencing a static scenario, you **create your own story** every flight.

**Start simply:**
1. ✅ Learn the F10 menu
2. ✅ Experiment with CAS missions
3. ✅ Discover marker commands
4. ✅ Create your own scenarios

### For Mission Makers

VEAF is a **force multiplier** for mission creation:
- ⏱️ **Save time**: No need to manually place 200 units
- 🎲 **Create variety**: Replayable procedural missions
- 🛠️ **Automate**: Scripts, weather, radios, everything is managed
- 🌐 **Share**: Missions easy to maintain and distribute

**Your Journey:**
1. ✅ Start with simple mission (CAS trainer)
2. ✅ Add assets (tankers, AWACS)
3. ✅ Create missions with objectives
4. ✅ Explore advanced scripting
5. ✅ Share with community!

---

**Happy flying and creating! 🚀**

---

## Credits

**VEAF Project**
- Website: https://www.veaf.org
- GitHub: https://github.com/VEAF/VEAF-Mission-Creation-Tools
- Discord: https://www.veaf.org/discord

**Lead Developers**
- Zip (davidp57)
- And the entire VEAF community

**Contributors**
- Thanks to all testers and contributors!

**Integrated Community Systems**
- CTLD - Ciribob
- CSAR - Ciribob
- Skynet IADS - Walder
- MIST - Grimes

---

**Documentation Version:** 1.0
**Last Updated:** December 16, 2025
**For VEAF Mission Creation Tools:** v6.0.5

**License:** ISC - Free to use and modify
