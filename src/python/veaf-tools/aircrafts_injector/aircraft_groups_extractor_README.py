"""
README documentation for the Aircraft Groups Extractor feature.
"""

AircraftGroupsExtractorREADME = r"""
# Aircraft Groups Extractor

## Overview

The Aircraft Groups Extractor is a tool that extracts aircraft groups from DCS World mission files (.miz) 
based on a regular expression pattern. The extracted groups are written to a YAML file in the 
`aircraft-templates.yaml` format, making it easy to create templates for aircraft group definitions.

## Features

- **Pattern Matching**: Extract groups by matching their names against a regular expression
- **Aircraft Types**: Supports both airplanes and helicopters
- **Coalition Organization**: Automatically organizes groups by coalition (blue/red) and country
- **Unit Type Extraction**: Identifies and lists all unit types within each group
- **YAML Output**: Generates well-formatted YAML output compatible with aircraft-templates.yaml
- **Interactive Selection**: Optional interactive mode to select which groups to include

## Usage

```bash
python veaf-tools.py extract-aircraft-groups [OPTIONS] [MISSION_FILE] [OUTPUT_FILE]
```

## Arguments

- `MISSION_FILE`: The DCS mission file (.miz) to extract from
  - Can be a mission name (will find the most recent .miz file matching the pattern)
  - Can be a full path to a .miz file
  - Defaults to `mission.miz`

- `OUTPUT_FILE`: Path where the extracted templates YAML will be saved
  - Defaults to `aircraft-templates.yaml`

## Options

- `--group-name-pattern PATTERN`: Regular expression pattern to match group names
  - Default: `.*` (matches all groups)
  - Examples:
    - `^F-16` - Groups starting with "F-16"
    - `Training` - Groups containing "Training"
    - `^(F-16|F-18)` - Groups starting with either "F-16" or "F-18"

- `--interactive`: Enable interactive mode to select which groups to include
  - When enabled, displays all matching groups and asks the user to confirm each one
  - Allows selective extraction of specific groups without modifying the pattern
  - Default: disabled (all matching groups are extracted)

- `--mission-folder FOLDER`: Folder containing mission files
  - Default: current directory

- `--verbose`: Enable detailed debug output

- `--readme`: Display this help documentation

- `--pause`: Pause and wait for user input when finished

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
python veaf-tools.py extract-aircraft-groups mission.miz output.yaml
```

### Extract only F-16 groups with verbose output

```bash
python veaf-tools.py extract-aircraft-groups --verbose --group-name-pattern "^F-16" mission.miz f16-groups.yaml
```

### Extract training groups from a specific folder

```bash
python veaf-tools.py extract-aircraft-groups --group-name-pattern "Training" --mission-folder ./missions mission.miz training-groups.yaml
```

### Extract groups interactively

```bash
python veaf-tools.py extract-aircraft-groups --interactive --group-name-pattern "spawn" mission.miz spawn-groups.yaml
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

## Notes

- The tool preserves the original coalition and country organization from the mission
- When extracting, the complete group data is saved, including units, routes, tasks, and configurations
- This allows later injection of the groups into other missions
- Unit types are extracted directly from the mission data
- The pattern matching is case-sensitive
- If no groups match the pattern, an empty structure is created in the output
"""
