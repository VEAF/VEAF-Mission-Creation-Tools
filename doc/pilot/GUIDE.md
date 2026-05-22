# Pilot Guide — VEAF Mission Creation Tools


This guide is for players flying missions that use the VEAF script framework. No technical knowledge required.

---

## Table of Contents

1. [What is VEAF?](#what-is-veaf)
2. [Recognising a VEAF Mission](#recognising-a-veaf-mission)
3. [F10 Radio Menu](#f10-radio-menu)
4. [Marker Commands](#marker-commands)
5. [Assets — Tankers, AWACS, Carriers](#assets)
6. [Missions and Combat Zones](#missions-and-combat-zones)
7. [CAS Training](#cas-training)
8. [Security and Permissions](#security-and-permissions)
9. [Tips by Aircraft Role](#tips-by-aircraft-role)
10. [FAQ](#faq)
11. [Community and Support](#community-and-support)

---

## What is VEAF?

VEAF Mission Creation Tools is a Lua script framework that makes DCS World missions dynamic and interactive. Instead of a static scenario, you can:

- Spawn enemy units on demand via map markers or radio menu
- Create CAS training zones with configurable difficulty
- Activate predefined combat missions
- Manage shared assets (tankers, AWACS, carriers) via F10 menu
- Interact with the environment in real time

---

## Recognising a VEAF Mission

When a mission uses VEAF scripts you will see:

- Startup messages in the lower-right corner listing loaded VEAF modules
- A **VEAF** submenu under **F10 → Other**
- Map markers showing tanker tracks, AWACS orbits or combat zone positions

---

## F10 Radio Menu

All VEAF features are accessible via **F10 → Other → VEAF**.

### Typical Menu Structure

```
F10 → Other → VEAF
├── Assets
│   ├── Tankers
│   │   └── [Tanker name] → Info / Respawn
│   ├── AWACS
│   │   └── [AWACS name] → Info / Respawn
│   └── Carriers
│       └── [Carrier name] → Info / Start Recovery / Stop Recovery
├── CAS Mission
│   ├── Generate
│   ├── Smoke
│   ├── Flare
│   ├── Skip
│   ├── Info
│   └── Cleanup
├── Combat Zones
│   └── [Zone name] → Activate / Deactivate / Info / Smoke / Flare
├── Missions
│   └── [Mission name] → Activate / Deactivate / Info
└── Help
```

The exact structure depends on what the mission maker has enabled.

---

## Marker Commands

Place a marker on the F10 map (right-click → Add marker), type a command in the text field, then confirm. VEAF intercepts the marker, executes the command, and removes the marker.

> On multiplayer servers some commands require a password. See [Security](#security-and-permissions).

### Spawn Commands

#### Spawn a unit: `_spawn unit`

```
_spawn unit, name F-16C
_spawn unit, name T-80, group 4, hdg 270
_spawn unit, name MiG-29S, alt 20000, speed 500, hdg 090
_spawn unit, name SA-6
```

Common options:

| Option | Description | Example |
|--------|-------------|---------|
| `name [TYPE]` | DCS unit type (required) | `name F-16C` |
| `group [N]` | Number of units in the group | `group 4` |
| `hdg [DEG]` | Initial heading in degrees | `hdg 270` |
| `alt [FT]` | Altitude in feet (aircraft) | `alt 15000` |
| `speed [KT]` | Speed in knots | `speed 450` |
| `side [blue/red]` | Coalition override | `side red` |
| `country [NAME]` | Country override | `country Russia` |

#### Spawn a predefined group: `_spawn group`

```
_spawn group, name CAP-2
_spawn group, name RED-SAM-SITE, hdg 180
```

Groups must be defined in the mission's `spawnables.yaml` file by the mission maker.

#### Spawn a CAP patrol: `_spawn cap`

```
_spawn cap, name Su-27, alt 25000, capradius 20000
_spawn cap, name F-15C, group 2, alt 30000, capradius 25000
```

Additional options: `capradius [M]` (orbit radius in metres), `distance [M]`.

#### Spawn a convoy: `_spawn convoy`

Place two markers: one at the start position (with the command), one at the destination.

```
Marker at start:
_spawn convoy, dest [DESTINATION_MARKER_NAME], speed 50, defense 2, armor 2

Marker at destination:
(empty or just a name)
```

Options: `dest [NAME]`, `speed [KMH]`, `defense [0-5]`, `armor [0-5]`, `size [0-5]`, `patrol`, `offroad`.

#### Spawn an AFAC/JTAC: `_spawn afac`

```
_spawn afac, name A-10C, alt 15000, freq 133.0, mod AM, code 1688
_spawn afac, name L-39ZA, freq 135.0, code 1584, immortal
```

#### Spawn smoke: `_spawn smoke`

```
_spawn smoke, color red
_spawn smoke, color green, shells 5
```

Available colors: `red`, `green`, `blue`, `white`, `orange`.

#### Spawn illumination flares: `_spawn flare`

```
_spawn flare, power 1000000, shells 5
```

#### Spawn explosions: `_spawn bomb`

```
_spawn bomb, power 500, shells 3
```

### CAS Command

```
_cas
_cas, size 3, defense 2, armor 3
```

Options: `size [0-5]`, `defense [0-5]`, `armor [0-5]`, `side [blue/red]`.

### Teleport Command

```
_teleport, name Viper Flight
```

Teleports the named group to the marker position.

### Destroy Command

```
_destroy, radius 500
_destroy, name Tank-1
```

### Security Authentication

```
_auth [PASSWORD]
```

Grants temporary elevated permissions. Required on some servers before using advanced spawn commands.

---

## Assets

### Tankers

Find tanker information via **F10 → VEAF → Assets → Tankers → [Name] → Info**.

Displayed: position, TACAN channel, radio frequency, type.

If the tanker has been destroyed, use **Respawn** to bring it back (if the mission maker has allowed it).

### AWACS

Find AWACS via **F10 → VEAF → Assets → AWACS → [Name] → Info**.

Displayed: callsign, frequency, position.

### Carriers

| Action | Menu path |
|--------|-----------|
| Get info (BRC, TACAN, ICLS, radio) | Assets → Carriers → [Name] → Info |
| Turn carrier into wind for recovery | Assets → Carriers → [Name] → Start Recovery |
| Resume normal navigation | Assets → Carriers → [Name] → Stop Recovery |

Operations automatically time out after 45 minutes.

---

## Missions and Combat Zones

### Combat Zones

Pre-built areas the mission maker has defined. You activate them on demand.

| Action | Menu path |
|--------|-----------|
| List available zones | Combat Zones |
| Activate a zone | Combat Zones → [Zone] → Activate |
| Get zone status | Combat Zones → [Zone] → Info |
| Mark zone with smoke | Combat Zones → [Zone] → Smoke |
| Deactivate / cleanup | Combat Zones → [Zone] → Deactivate |

When a zone is activated, enemy units spawn. When all enemies are destroyed, the zone completes and can be replayed.

---

## CAS Training

Generate procedural CAS targets via **F10 → VEAF → CAS Mission**.

| Action | Menu |
|--------|------|
| Create a new target zone | CAS Mission → Generate |
| Mark with smoke | CAS Mission → Smoke |
| Mark with flares | CAS Mission → Flare |
| Skip current target | CAS Mission → Skip |
| Get target info | CAS Mission → Info |
| Remove all units | CAS Mission → Cleanup |

Smoke/flare has a 3-minute cooldown between uses.

### Difficulty Levels

| Level | Size | Defense | Armour | Description |
|-------|------|---------|--------|-------------|
| 0 | Very small | None | Infantry | Beginner |
| 1 | Small | Light | Light vehicles | Easy |
| 2 | Medium | Moderate | APCs | Intermediate |
| 3 | Medium-Large | Medium AA | IFVs + light tanks | Advanced |
| 4 | Large | Heavy AA | Medium tanks | Difficult |
| 5 | Very large | SAM | Heavy tanks | Expert |

Set difficulty via marker: `_cas, size 3, defense 2, armor 3`

---

## Carrier Operations

### Recovery Procedure

1. **Request recovery** (10–15 min before approach):
   F10 → VEAF → Assets → Carriers → [Name] → Start Recovery

2. **Check info**:
   F10 → VEAF → Assets → Carriers → [Name] → Info
   - BRC (Base Recovery Course)
   - TACAN channel (e.g. 73X)
   - ICLS channel (e.g. 13)
   - ATC frequency

3. **Approach and land** using TACAN for navigation and ICLS for glideslope (F/A-18C, F-14).

4. **After landing**:
   F10 → VEAF → Assets → Carriers → [Name] → Stop Recovery

Recovery automatically times out after 45 minutes. The carrier turns into the wind to provide ~30 kt relative wind over deck.

---

## Security and Permissions

On multiplayer servers, some commands are restricted. Authenticate with:

```
_auth [PASSWORD]
```

Ask the server administrator for the password. Authentication persists for your session.

Permission levels:

| Level | Typical access |
|-------|----------------|
| Guest | View info, basic spawning (if allowed) |
| Authenticated | Full spawn commands, CAS, missions |
| Admin | Server management commands |

---

## FAQ

**Q: How do I know if a mission uses VEAF?**
A: Press F10 — if you see a "VEAF" submenu under "Other", it's a VEAF mission.

**Q: My marker commands don't work?**
A: Check syntax (starts with `_`), check you're authenticated on multiplayer, and verify the server allows marker commands.

**Q: What unit names can I use with `_spawn unit`?**
A: Use standard DCS type names: `F-16C`, `Su-27`, `T-80`, `SA-6`, `M1 Abrams`, etc.

**Q: Spawned units disappear?**
A: DCS AI units can be cleaned up if you fly too far away. Stay within ~40–50 NM.

**Q: How to reset a CAS mission?**
A: F10 → CAS Mission → Cleanup, then Generate again.

**Q: Can I spawn friendly units?**
A: Yes — add `side blue` to your spawn command.

---

## Community and Support

- **VEAF Discord**: [veaf.org/discord](https://www.veaf.org/discord) — #support channel for help
- **GitHub**: [github.com/VEAF/VEAF-Mission-Creation-Tools](https://github.com/VEAF/VEAF-Mission-Creation-Tools)
- **Website**: [veaf.org](https://www.veaf.org)

### Scripted Missions

More complex scenarios with objectives and tracking.

| Action | Menu path |
|--------|-----------|
| List missions | Missions |
| Activate | Missions → [Mission] → Activate |
| Read status / objectives | Missions → [Mission] → Info |
| Abort | Missions → [Mission] → Deactivate |

---

## CAS Training

The CAS generator creates a target area with configurable threat packages.

**Workflow:**

1. **Generate** — F10 → CAS Mission → Generate (optionally with parameters via marker `_cas, size 3, defense 2`)
2. **Mark the zone** — F10 → CAS Mission → Smoke or Flare (3-minute cooldown between marks)
3. **Get info** — F10 → CAS Mission → Info (position, unit composition, status)
4. **Engage** — Attack the marked targets
5. **Advance** — Zone auto-advances when all units are destroyed, or use **Skip**
6. **Cleanup** — F10 → CAS Mission → Cleanup removes all remaining units

**Difficulty guide:**

| Level | Typical composition | For |
|-------|---------------------|-----|
| 0 | Infantry, jeeps, no AA | Beginners |
| 1 | Light vehicles, MANPADS | Easy |
| 2 | APCs, light AAA | Intermediate |
| 3 | IFVs, medium AAA + SHORAD | Advanced |
| 4 | MBTs, ZSU + SA-9 | Difficult |
| 5 | Heavy armor, SAMS | Expert |

---

## Security and Permissions

On multiplayer servers the mission maker may restrict certain commands:

| Level | Who can use |
|-------|-------------|
| Public | All players — asset info, combat zone activation, smoke/flare |
| Pilots | Non-spectator players |
| Admin | Server administrators |

To authenticate as admin:

```
_auth [PASSWORD]
```

After authentication you have elevated rights for the configured duration (default: 10 minutes). The password is set by the mission maker or server admin.

---

## Tips by Aircraft Role

### Fighters (F-16C, F/A-18C, F-15C, Su-27…)

- Use AWACS for threat vectors before engaging
- Spawn an enemy CAP with `_spawn cap` for a realistic intercept scenario
- Activate a predefined intercept mission via the F10 menu

### Attack Aircraft (A-10C, Su-25, F/A-18C…)

- Start CAS training at difficulty 1–2
- Use **Smoke** to mark the target before attacking
- Increase difficulty gradually (level 3+ has SEAD-worthy threats)

### Helicopters (AH-64D, Ka-50, Mi-24…)

- Keep difficulty at 0–2 (minimal AA)
- Use `_spawn unit, name BTR-80, group 5` for dispersed APC targets
- Exploit terrain masking to approach below AA radar

### Transports (C-130, Mi-8, UH-1H…)

- Spawn a FARP as a destination: `_spawn farp, name FARP Alpha, side blue`
- Use CTLD integration (if enabled) for troop/cargo missions

---

## FAQ

**Q: How do I know a mission uses VEAF?**
Look for the VEAF submenu under F10 → Other at mission start.

**Q: Why don't my markers work?**
Check the command syntax. On some servers you may need to authenticate first with `_auth [PASSWORD]`.

**Q: What DCS unit type names can I use?**
Standard DCS names: `F-16C`, `Su-27`, `T-80`, `M1 Abrams`, `SA-6`, etc. They are case-sensitive.

**Q: Spawned units disappeared?**
Some missions enforce a range limit (~40–50 NM). Normal behaviour.

**Q: How do I reset a CAS session?**
F10 → CAS Mission → Cleanup, then Generate again.

**Q: Can I spawn friendly units?**
Yes, add `side blue` to any spawn command.

---

## Community and Support

- [VEAF Discord](https://www.veaf.org/discord) — real-time help, `#support` channel
- [VEAF Website](https://www.veaf.org)
- [GitHub](https://github.com/VEAF/VEAF-Mission-Creation-Tools)

---

*See also: [Full User Guide](../USER_GUIDE.md) for the extended reference.*
