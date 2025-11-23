"""
README documentation for the Aircraft Groups Extractor feature.
"""

AircraftGroupsExtractorREADME = r"""
# Aircraft Groups Extractor

## Overview

The Aircraft Groups Extractor is a tool that extracts aircraft groups from:
- **DCS World mission files (.miz)** - Extract templates directly from missions
- **Lua settings files** - Extract from configuration files like `settings-templates.lua`

Extracted groups are written to a YAML file in the `aircraft-templates.yaml` format, 
making it easy to create templates for aircraft group definitions.

### Use Cases

**Spawnable Aircraft**: Extract aircraft groups from a mission to use as spawnable templates with the `_spawn` command:
- Extracted groups are organized by difficulty (EASY, NORMAL, HARD)
- Group names include configuration details (e.g., "F-16 - FOX3 - Radar ON - ECM ON - HARD X2")
- Used with `-cap` shortcut to dynamically spawn aircraft during mission play

**Template Aircraft**: Extract aircraft groups to use as dynamic slot templates:
- Aircraft can be selected as templates in the Warehouse dialog in the mission editor
- Provides standardized group configurations for various aircraft types
- Useful for mission design and aircraft library documentation

## Features

- **Dual Input Support**:
  - Extract from DCS mission files (.miz)
  - Extract from Lua settings files (e.g., settings-templates.lua)
- **Pattern Matching**: Extract groups by matching their names against a regular expression
- **Aircraft Types**: Supports both airplanes and helicopters
- **Coalition Organization**: Automatically organizes groups by coalition (blue/red) and country
- **Unit Type Extraction**: Identifies and lists all unit types within each group
- **YAML Output**: Generates well-formatted YAML output compatible with aircraft-templates.yaml
- **Interactive Selection**: Optional interactive mode to select which groups to include
- **Property Filtering**: Automatically excludes mission-specific properties (like radio configs)

## Usage

### Command Line

#### Extract from a DCS mission file:

```bash
python veaf-tools.py extract-aircraft-groups [MISSION_FILE] [OPTIONS]
```

#### Extract from a Lua settings file:

```bash
python veaf-tools.py extract-aircraft-groups --lua-input settings-templates.lua --output-yaml output.yaml [OPTIONS]
```

## Arguments

- `MISSION_FILE`: (Optional, positional) The DCS mission file (.miz) to extract from (when not using --lua-input)
  - Can be a mission name (will find the most recent .miz file matching the pattern)
  - Can be a full path to a .miz file
  - Defaults to `mission.miz`
  - Not used when `--lua-input` is specified

## Options

- `--output-yaml FILE`: Path where the extracted templates YAML will be saved
  - Default: `aircraft-templates.yaml`
  - Example: `--output-yaml templates.yaml`

- `--lua-input FILE`: Path to a Lua settings file to extract from instead of a mission file
  - Example: `--lua-input settings-templates.lua`
  - Mutually exclusive with MISSION_FILE
  - Expected format: `settings = { categories = { ... } }`

- `--group-name-pattern PATTERN`: Regular expression pattern to match group names
  - Default: `.*` (matches all groups)
  - Examples:
    - `^F-16` - Groups starting with "F-16"
    - `Training` - Groups containing "Training"
    - `^(F-16|F-18)` - Groups starting with either "F-16" or "F-18"
    - `.*[tT]emplate.*` - Groups with "template" in the name (case-insensitive)

- `--interactive`: Enable interactive mode to select which groups to include
  - When enabled, displays all matching groups and asks the user to confirm each one
  - Allows selective extraction of specific groups without modifying the pattern
  - Default: disabled (all matching groups are extracted)

- `--mission-folder FOLDER`: Folder containing mission files (for mission extraction only)
  - Default: current directory

- `--verbose`: Enable detailed debug output

- `--readme`: Display this help documentation

- `--pause`: Pause and wait for user input when finished

## Lua File Format

For Lua file input, the file must contain a `settings` table with the following structure:

```lua
settings = {
    ["categories"] = {
        ["airplane"] = {
            ["coalitions"] = {
                ["blue"] = {
                    ["countries"] = {
                        ["CountryName"] = {
                            ["groups"] = {
                                ["GroupName"] = {
                                    ["name"] = "GroupName",
                                    ["units"] = { ... },
                                    -- ... other properties
                                },
                            },
                        },
                    },
                },
                ["red"] = { ... },
            },
        },
        ["helicopter"] = { ... },
    },
}
```

## Output Format

The generated YAML file follows this structure:

```yaml
airplanes:
  coalitions:
    blue:
      CountryName:
        GroupName:
          name: "GroupName"
          type: "AircraftType"
          units:
            - type: "AircraftType"
              name: "Pilot-1"
            - type: "AircraftType"
              name: "Pilot-2"
helicopters:
  coalitions:
    red:
      CountryName:
        GroupName:
          name: "GroupName"
          type: "HelicopterType"
          units:
            - type: "HelicopterType"
              name: "Heli-1"
```

## Examples

### Extract all groups from a mission

```bash
python veaf-tools.py extract-aircraft-groups mission.miz --output-yaml output.yaml
```

### Extract template groups from a Lua file

```bash
python veaf-tools.py extract-aircraft-groups \
  --lua-input settings-templates.lua \
  --output-yaml templates.yaml \
  --group-name-pattern ".*[tT]emplate.*"
```

### Extract only F-16 groups with verbose output

```bash
python veaf-tools.py extract-aircraft-groups mission.miz \
  --verbose \
  --output-yaml f16-groups.yaml \
  --group-name-pattern "^F-16"
```

### Extract training groups from a specific folder

```bash
python veaf-tools.py extract-aircraft-groups mission.miz \
  --mission-folder ./missions \
  --output-yaml training-groups.yaml \
  --group-name-pattern "Training"
```

### Extract groups interactively

```bash
python veaf-tools.py extract-aircraft-groups mission.miz \
  --interactive \
  --output-yaml spawn-groups.yaml \
  --group-name-pattern "spawn"
```

In interactive mode, the tool will:
1. Search for all groups matching the pattern
2. Display each matching group with details:
   - Group name
   - Coalition and country
   - Aircraft type (airplanes/helicopters)
   - Number of units and their types
3. Ask you to confirm for each group: `Include this group? (y/n/skip) [y]:`
   - Press Enter or type `y` to include the group
   - Type `n` to exclude the group
   - Type `skip` to skip this group and continue
4. Write only the selected groups to the YAML file

## Integration with Aircraft Injection

The extracted YAML can be used as input for the Aircraft Groups Injector to:

- Inject groups into target missions
- Create standardized group definitions
- Document mission structure
- Generate configuration templates
- Analyze aircraft compositions in existing missions

## Complete Workflow

### Extract-Merge Workflow

1. **Extract from mission**: Use `extract-aircraft-groups` with a pattern to find matching groups
   ```bash
   python veaf-tools.py extract-aircraft-groups mission.miz \
     --output-yaml extracted-groups.yaml \
     --group-name-pattern ".*EASY.*"
   ```

2. **Review extracted YAML**: Check the output file and manually edit if needed

3. **Inject into mission**: Use `inject-aircraft-groups` to add/replace groups
   ```bash
   python veaf-tools.py inject-aircraft-groups mission.miz merged-mission.miz \
     --template-file extracted-groups.yaml \
     --mode add
   ```

### Recommended Extraction Patterns

**Extract Spawnable Aircraft**: Use patterns that match naming conventions
- `veafSpawn-.*` - All spawnable groups
- `.*EASY.*` - Easy difficulty spawns
- `.*NORMAL.*` - Normal difficulty spawns
- `.*HARD.*` - Hard difficulty spawns
- `.*X2` - Two-ship formations
- `.*X1` - Single aircraft

**Extract Templates**: Use patterns for template groups
- `.*[tT]emplate.*` - Groups with "template" in name
- `^[A-Z]-.*` - Aircraft starting with single letter designation
- `.*Template.*EASY.*` - Template groups of specific difficulty

## Notes

- The tool preserves the original coalition and country organization from the mission
- When extracting, the complete group data is saved, including units, routes, tasks, and configurations
- This allows later injection of the groups into other missions
- Unit types are extracted directly from the mission data
- The pattern matching is case-sensitive
- If no groups match the pattern, an empty structure is created in the output
"""
