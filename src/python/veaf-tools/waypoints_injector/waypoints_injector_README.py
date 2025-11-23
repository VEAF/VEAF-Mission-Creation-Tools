"""
README content for the Waypoints Injector feature.
"""

WaypointsInjectorREADME = """
# Waypoints Injector

Inject waypoints from a YAML configuration file into DCS mission aircraft groups.

## Overview

The Waypoints Injector allows you to:
- Define waypoint templates in a YAML file
- Create flight plan settings that target specific aircraft groups
- Automatically inject waypoints into human-piloted aircraft groups in missions

## Usage

```bash
veaf-tools inject-waypoints [OPTIONS] [MISSION_NAME_OR_FILE] [OUTPUT_MISSION]
```

### Options

- `--waypoints-file TEXT`: Path to the YAML file containing waypoint definitions (default: waypoints.yaml)
- `--mission-folder TEXT`: Folder containing the mission files (default: current directory)
- `--verbose`: Enable verbose output
- `--pause`: Pause when finished and wait for user input
- `--help`: Show help message
- `--readme`: Display this README

### Examples

**Basic injection using default settings:**
```bash
veaf-tools inject-waypoints my-mission
```

**Inject with a custom waypoints file:**
```bash
veaf-tools inject-waypoints --waypoints-file my-waypoints.yaml my-mission my-mission-with-waypoints.miz
```

**Verbose mode:**
```bash
veaf-tools inject-waypoints --verbose my-mission
```

## YAML Configuration Format

### Basic Structure

```yaml
waypoints:
  WAYPOINT_NAME:
    type: "Turning Point"
    action: "Turning Point"
    alt: 5000                # Altitude in meters
    alt_type: "BARO"        # BARO or RADIO
    speed: 100              # Speed in m/s
    speed_type: "TAS"       # TAS or IAS
    x: 75869                # X coordinate
    y: 48674                # Y coordinate
    name: "WAYPOINT_NAME"   # Optional waypoint name
    ETA: 364.89             # Optional estimated time of arrival
    ETA_locked: false       # Whether ETA is locked

settings:
  FLIGHT_PLAN_NAME:
    category: "plane"       # plane or helicopter, optional
    coalition: "blue"       # blue or red, optional
    type: "F-16C_50"        # Specific aircraft type, optional
    country: "USA"          # Country name, optional
    waypoints:
      WAYPOINT_NAME: "WAYPOINT_NAME"
```

### Targeting Logic

Flight plans are matched to aircraft groups using this priority:
1. Aircraft type (unit_type)
2. Aircraft category (plane/helicopter)
3. Coalition (blue/red)
4. All other groups (if no specific criteria are met)

A flight plan without specific criteria will apply to all matching groups.

### Example

```yaml
waypoints:
  BULLSEYE:
    type: "Turning Point"
    action: "Turning Point"
    alt: 6096          # 20000 ft
    alt_type: "BARO"
    speed: 999
    speed_type: "TAS"
    x: 75869
    y: 48674
    name: "BULLSEYE"
    ETA: 364.89
    ETA_locked: false

  INITIAL_POINT:
    type: "Turning Point"
    action: "Turning Point"
    alt: 3048          # 10000 ft
    alt_type: "BARO"
    speed: 50
    speed_type: "TAS"
    x: 70000
    y: 50000

settings:
  ALL_BLUE_PLANES:
    category: "plane"
    coalition: "blue"
    waypoints:
      BULLSEYE: "BULLSEYE"
      INITIAL_POINT: "INITIAL_POINT"

  ALL_RED_HELOS:
    category: "helicopter"
    coalition: "red"
    waypoints:
      BULLSEYE: "BULLSEYE"
```

## Behavior

- Only human-piloted aircraft groups (with Client/Player skill) receive waypoints
- Existing waypoints in groups are replaced with the new waypoints
- Groups are matched based on their category, coalition, type, and country
- Non-matching groups are left unchanged

## Notes

- Waypoints are applied to flight plans that are attached to aircraft groups
- The injector only processes groups with at least one human pilot
- Empty waypoint lists will clear existing waypoints
- All coordinates should be in mission coordinates (not lat/lon)
"""

WaypointsExtractorREADME = """
# Waypoints Extractor

Extract waypoints from DCS missions or Lua settings files and save them as YAML templates.

## Overview

The Waypoints Extractor allows you to:
- Extract waypoints from aircraft groups in DCS missions
- Extract waypoint definitions from Lua settings files
- Filter extracted groups using regular expressions
- Optionally select groups interactively
- Save waypoints in YAML format for reuse in other missions

## Usage

### From a Mission File

```bash
veaf-tools extract-waypoints [OPTIONS] [MISSION_NAME_OR_FILE]
```

### From a Lua Settings File

```bash
veaf-tools extract-waypoints --lua-input path/to/settings.lua [OPTIONS]
```

### Options

- `--mission-folder TEXT`: Folder containing mission files (default: current directory)
- `--output-yaml TEXT`: Output YAML file path (default: waypoints.yaml)
- `--group-name-pattern TEXT`: Regular expression to match group/waypoint names (default: .*)
- `--lua-input TEXT`: Path to a Lua settings file to extract from instead of a mission
- `--interactive`: Interactive mode - select which groups to extract
- `--verbose`: Enable verbose output
- `--pause`: Pause when finished
- `--help`: Show help
- `--readme`: Display this README

### Examples

**Extract all waypoints from a mission:**
```bash
veaf-tools extract-waypoints my-mission
```

**Extract waypoints matching a pattern:**
```bash
veaf-tools extract-waypoints --group-name-pattern ".*[Tt]emplate.*" my-mission
```

**Extract from a Lua settings file:**
```bash
veaf-tools extract-waypoints --lua-input settings-waypoints.lua --output-yaml templates.yaml
```

**Interactive mode:**
```bash
veaf-tools extract-waypoints --interactive my-mission
```

**Verbose output:**
```bash
veaf-tools extract-waypoints --verbose --group-name-pattern "F-16" my-mission
```

## Regular Expression Examples

- `.*` - Match all groups (default)
- `[Tt]emplate.*` - Match names containing "template" (case-insensitive)
- `F-16.*` - Match F-16 groups
- `^(ALPHA|BRAVO).*` - Match groups starting with ALPHA or BRAVO
- `.*[Ss]trike.*` - Match names containing "strike"

## Extraction Process

### From Missions

The extractor:
1. Reads the .miz mission file
2. Scans all aircraft groups in all coalitions and countries
3. Filters groups by the provided pattern
4. Extracts the route/waypoint data from matched groups
5. Saves the waypoints to a YAML file

### From Lua Files

The extractor:
1. Reads the Lua file
2. Looks for a `waypoints` table
3. Filters waypoint definitions by pattern
4. Saves them to YAML

## Output Format

The extracted YAML file will contain:

```yaml
waypoints:
  EXTRACTED_GROUP_NAME_waypoints:
    type: "Turning Point"
    action: "Turning Point"
    alt: 5000
    alt_type: "BARO"
    # ... other waypoint fields
```

You can then modify this file and use it with the waypoints injector.

## Interactive Mode

In interactive mode, the extractor will:
1. Load and scan the mission/Lua file
2. Display a table of matched groups
3. Ask for confirmation before extraction
4. Save only the confirmed groups

## Tips

- Use patterns to extract specific aircraft types (e.g., `--group-name-pattern "F-16.*"`)
- Extract from template missions to build reusable waypoint libraries
- Review extracted waypoints before injecting them into other missions
- Use `--verbose` to see detailed extraction progress
"""
