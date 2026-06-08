# Pipeline Reference

This page documents the optional **build pipeline** steps that `veaf-tools build` can run after generating `veaf-config.lua`. Each step injects data into the `.miz` file from a separate YAML configuration file.

---

## Overview

The pipeline runs four optional steps, in this order:

| Step | Config file | What it does |
|------|-------------|--------------|
| `presets` | `src/presets.yaml` | Injects radio frequency presets into human-piloted aircraft groups |
| `waypoints` | `src/waypoints.yaml` or `waypoints.yaml` | Injects waypoint templates into human-piloted aircraft groups |
| `aircraft_groups` | `src/aircraft-templates.yaml`, `src/templates.yaml`, or `aircraft-templates.yaml` | Injects aircraft group definitions (slots/spawnable groups) |
| `weather` | `src/missions.yaml` (legacy, first), `src/versions.yaml`, or `missions.yaml` | Creates multiple mission variants with different weather and time |

Each step is **auto-detected**: it runs if its default config file exists. You can override this behaviour in `mission.yaml`.

---

## Controlling the Pipeline (`mission.yaml`)

```yaml
pipeline:
  presets: false                        # skip even if src/presets.yaml exists
  waypoints: true                       # auto-detect: runs only if the config file exists
  aircraft_groups:
    file: src/my-aircraft.yaml          # non-default file path
    mode: replace                       # add (default) | replace
  weather: false                        # skip weather variants
```

### `pipeline:` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `presets` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `waypoints` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `aircraft_groups` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |
| `weather` | bool \| object | auto | No | `true`/unset = auto-detect (run if file exists), `false` = always skip, object = custom options |

When set to an object, the following sub-fields apply:

| Sub-field | Type | Default | Description |
|-----------|------|---------|-------------|
| `file` | string | *(see step defaults)* | Path to the config file, relative to the mission folder |
| `mode` | `add` \| `replace` | `add` | *(aircraft_groups only)* `add` keeps existing groups; `replace` updates same-named groups |

**Auto-detection** (when not set or `true`): the step runs only if its default file is found. Absence of the file silently skips the step.

---

## Step 1 — Radio Presets (`presets.yaml`)

Injects radio frequency presets into every aircraft group that has at least one human pilot (Client/Player skill). Also generates kneeboard PNG images for each preset.

### Default file location

```
<mission-folder>/src/presets.yaml
```

### Schema

```yaml
# ── Channel definitions ────────────────────────────────────────────────────
channels_collection:
  <set-name>:                           # logical group of channels (e.g. airports-caucasus)
    <channel-name>:                     # individual channel identifier
      title: "Batumi / 16X"            # human-readable label
      freqs:
        uhf: 260                        # UHF frequency (MHz)
        vhf: 131                        # VHF-AM frequency (MHz)
        fm: 40.4                        # FM frequency (MHz)

# ── Radio definitions ──────────────────────────────────────────────────────
radios_collection:
  <set-name>:                           # logical group of radios (e.g. blue_radios)
    <radio-name>:                       # identifier referenced in presets_collection
      title: "UHF"                      # label shown on kneeboard
      type: uhf                         # uhf | vhf | fm
      channels:
        01: Guard                       # channel number → channel-name (from channels_collection)
        02: Batumi
        10: Stennis

# ── Preset definitions ────────────────────────────────────────────────────
presets_collection:
  <set-name>:                           # logical group of presets (e.g. blue_presets)
    <preset-name>:                      # identifier referenced in presets_assignments
      title: "Blue coalition - UHF/VHF/FM"
      radios:
        radio_1: <radio-name>           # slot → radio-name (from radios_collection)
        radio_2: <radio-name>
        radio_3: <radio-name>

# ── Assignment rules ──────────────────────────────────────────────────────
presets_assignments:
  <coalition>:                          # blue | red
    <category>:                         # plane | helicopter
      all: <preset-name>               # default preset for all aircraft of this type
      <aircraft-type>: <preset-name>   # override for a specific DCS aircraft type (e.g. A-10C_2)
```

### Minimal example

```yaml
channels_collection:
  common:
    Guard:
      title: Guard
      freqs:
        uhf: 243.0
        vhf: 121.5

radios_collection:
  blue_radios:
    radio_uhf:
      title: UHF
      type: uhf
      channels:
        01: Guard

presets_collection:
  blue_presets:
    blue_default:
      title: Blue Default
      radios:
        radio_1: radio_uhf

presets_assignments:
  blue:
    plane:
      all: blue_default
    helicopter:
      all: blue_default
```

### Frequency validation

At injection time, every frequency assigned to an aircraft is checked against the hardware specs of that aircraft's radios. If a frequency falls outside all valid ranges, a warning is emitted:

```
WARNING: Group 'Bassel MiG-19 #1' (MiG-19P): frequency 284.0 MHz is outside all valid radio
ranges for this aircraft — DCS will reject it at mission load.
```

The check is **non-blocking**: the mission is still written, but the invalid frequency will cause a DCS error when the mission loads (typically `Invalid frequency X MHz`).

Specs cover 85 player-flyable aircraft and are sourced from [dcs-lua-datamine](https://github.com/Quaggles/dcs-lua-datamine). If an aircraft is not in the database the check is silently skipped.

> **See also**: [`doc/mission-maker/dcs-radio-specs.md`](dcs-radio-specs.md) — full reference table of valid frequency ranges per aircraft.  
> To regenerate after a DCS update: `poetry run update-radio-specs`

---

## Step 2 — Waypoints (`waypoints.yaml`)

Injects waypoint templates into human-piloted aircraft groups. Only groups with at least one Client/Player unit are modified.

### Default file location

```
<mission-folder>/src/waypoints.yaml

Also accepted: waypoints.yaml  (mission root)
```

### Schema

```yaml
# ── Waypoint definitions ───────────────────────────────────────────────────
waypoints:
  <WAYPOINT_NAME>:
    type: "Turning Point"               # DCS waypoint type
    action: "Turning Point"             # DCS waypoint action
    alt: 6096                           # Altitude in metres
    alt_type: "BARO"                    # BARO | RADIO
    speed: 200                          # Speed in m/s
    speed_type: "TAS"                   # TAS | IAS
    x: 75869                            # Mission X coordinate
    y: 48674                            # Mission Y coordinate
    name: "BULLSEYE"                    # Waypoint label (optional)
    ETA: 364.89                         # Estimated time of arrival in seconds (optional)
    ETA_locked: false                   # Lock ETA (optional)

# ── Flight plan assignments ────────────────────────────────────────────────
settings:
  <PLAN_NAME>:
    category: "plane"                   # plane | helicopter (optional filter)
    coalition: "blue"                   # blue | red (optional filter)
    type: "F-16C_50"                    # DCS aircraft type (optional filter)
    country: "USA"                      # Country name (optional filter)
    waypoints:
      <WAYPOINT_NAME>: "<WAYPOINT_NAME>"  # map waypoint definition to slot
```

### Matching priority

Flight plans are matched to groups using this priority order:
1. Aircraft type (`type`)
2. Aircraft category (`category`)
3. Coalition (`coalition`)
4. Country (`country`)
5. All other groups (no filters = wildcard)

### Minimal example

```yaml
waypoints:
  BULLSEYE:
    type: "Turning Point"
    action: "Turning Point"
    alt: 6096
    alt_type: "BARO"
    speed: 999
    speed_type: "TAS"
    x: 75869
    y: 48674
    name: "BULLSEYE"

settings:
  BLUE_PLANES:
    category: "plane"
    coalition: "blue"
    waypoints:
      BULLSEYE: "BULLSEYE"
```

---

## Step 3 — Aircraft Groups (`aircraft-templates.yaml`)

Injects aircraft group definitions into the mission. Used for spawnable groups and player slot templates.

### Default file location

```
<mission-folder>/src/aircraft-templates.yaml

Also accepted: src/templates.yaml
                aircraft-templates.yaml  (mission root)
```

### Injection modes

| Mode | Behaviour |
|------|-----------|
| `add` *(default)* | Appends all groups from the file; existing groups are preserved |
| `replace` | Groups with the same name in the mission are updated; others are preserved |

### Schema

```yaml
airplanes:
  coalitions:
    <coalition>:                        # blue | red
      <Country Name>:                   # DCS country name (e.g. "France", "USA")
        <Group Name>:
          name: "Group Name"            # REQUIRED — must match the key
          type: "M-2000C"               # REQUIRED — primary DCS aircraft type
          units:                        # REQUIRED — at least one unit
            - type: "M-2000C"
              name: "Pilot-1"
            - type: "M-2000C"
              name: "Pilot-2"

helicopters:
  coalitions:
    <coalition>:
      <Country Name>:
        <Group Name>:
          name: "Group Name"
          type: "UH-1H"
          units:
            - type: "UH-1H"
              name: "Helo-1"
```

### Minimal example

```yaml
airplanes:
  coalitions:
    blue:
      France:
        Mirage-Flight:
          name: "Mirage-Flight"
          type: "M-2000C"
          units:
            - type: "M-2000C"
              name: "Mirage-1"
            - type: "M-2000C"
              name: "Mirage-2"
```

---

## Step 4 — Weather & Time Versions (`versions.yaml`)

Creates multiple `.miz` variants from a single base mission, each with a different time and/or weather configuration.

### Default file location

```
<mission-folder>/src/missions.yaml  (legacy, checked first)
<mission-folder>/src/versions.yaml

Also accepted: missions.yaml  (mission root)
```

### Schema

```yaml
# ── Geographic position for solar calculations ─────────────────────────────
position:
  latitude: 33.5                        # Decimal degrees, -90 to 90
  longitude: 35.5                       # Decimal degrees, -180 to 180
  timezone: "Asia/Damascus"             # IANA timezone string

# ── Base date for all versions ─────────────────────────────────────────────
base_date: "2024-03-15"                 # ISO 8601 (YYYY-MM-DD)

# ── Mission variants ───────────────────────────────────────────────────────
versions:
  - name: dawn                          # REQUIRED — output filename (without .miz)
    time: "sunrise+30*60"               # Time expression (see below)
    date: "today"                       # Date expression (see below, optional)
    metar: "METAR OSDI 151420Z 27015G25KT 9999 SKC 15/10 Q1018"  # optional

  - name: noon
    time: "12:00"
    weather:                            # manual weather (alternative to metar)
      temperature: 25.0                 # °C, range -50..50
      wind_speed: 8.0                   # m/s
      wind_direction: 270.0             # degrees (0=North)
      visibility: 9999                  # metres
      cloud_type: "clear"               # clear | few | scattered | broken | overcast
      cloud_height: 2000                # cloud base in metres
      fog_enabled: false                # enable fog effect
```

### `versions[]` fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Output filename (no `.miz`); e.g. `dawn` → `dawn.miz` |
| `time` | string | No | Time expression — see below |
| `date` | string | No | Date expression — see below |
| `metar` | string | No | Full METAR string — parsed for weather data |
| `weather` | object | No | Manual weather override (used when no `metar`) |

### Time expressions

| Format | Example | Meaning |
|--------|---------|---------|
| `HH:MM` | `14:30` | Absolute time (14:30 local) |
| `sunrise` | `sunrise` | Sunrise time (requires `position:`) |
| `sunset` | `sunset` | Sunset time (requires `position:`) |
| Expression | `sunrise+30*60` | Arithmetic — seconds offset |
| Seconds | `54000` | Raw seconds since midnight |

### Date expressions

| Format | Example | Meaning |
|--------|---------|---------|
| ISO 8601 | `2024-03-15` | Specific date |
| Keyword | `today`, `tomorrow`, `yesterday` | Relative to run date |
| Relative | `+1`, `-7` | Days from `base_date` |

### `weather` object fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `temperature` | number | — | Air temperature in °C |
| `wind_speed` | number | — | Wind speed in m/s |
| `wind_direction` | number | — | Wind direction in degrees (0 = North) |
| `visibility` | number | — | Visibility in metres |
| `cloud_type` | string | — | `clear` \| `few` \| `scattered` \| `broken` \| `overcast` |
| `cloud_height` | number | — | Cloud base altitude in metres |
| `fog_enabled` | boolean | `false` | Enable fog effect |

### Minimal example

```yaml
position:
  latitude: 42.3
  longitude: 43.4
  timezone: "Asia/Tbilisi"

base_date: "2024-06-01"

versions:
  - name: dawn
    time: "sunrise+20*60"
    metar: "METAR UGTB 010500Z 27010KT 9999 FEW030 18/10 Q1016"

  - name: afternoon
    time: "15:00"
    weather:
      temperature: 28.0
      wind_speed: 5.0
      wind_direction: 180.0
      cloud_type: "few"
      cloud_height: 2500
```

---

## See Also

- [mission.yaml Reference](MISSION_YAML_REFERENCE.md) — top-level mission configuration
- [Mission Maker Guide](mission-maker/GUIDE.md) — complete workflow
