"""
README documentation for the Aircraft Groups Injector feature.
This module documents validation and injection functionality.
"""

AircraftGroupsInjectorREADME = r"""
# Aircraft Groups Injector

## Overview

The Aircraft Groups Injector injects validated aircraft groups from YAML files into DCS missions. 
It automatically validates YAML before injection and stops if validation fails.

## Features

- **Automatic Validation**: Validates YAML before injection (stops if validation fails)
- **YAML Loading**: Loads aircraft groups from YAML files
- **Mission Modification**: Injects groups into existing missions
- **Injection Modes**:
  - `add`: Adds new groups to existing ones (default)
  - `replace`: Replaces groups with the same name
- **Mission Structure Creation**: Automatically creates missing coalition/country structures
- **Deep Copy Protection**: Doesn't modify original YAML data
- **Injection Logging**: Tracks all injection operations
- **Detailed Reporting**: Shows results with optional verbose logging

## Usage

```bash
python veaf-tools.py inject-aircraft-groups [MISSION_NAME_OR_FILE] [OUTPUT_MISSION] [MISSION_FOLDER] [OPTIONS]
```

## Arguments

- `MISSION_NAME_OR_FILE`: (Optional, positional) Mission name or file path
  - Can be a mission name (will find the most recent .miz file matching the pattern)
  - Can be a full path to a .miz file
  - Defaults to `mission.miz`

- `OUTPUT_MISSION`: (Optional, positional) Path where to save the modified mission
  - Defaults to the same as input mission

- `MISSION_FOLDER`: (Optional, positional) Folder containing mission files
  - Defaults to current directory (`.`)

## Options

- `--template-file FILE`: Path to the YAML file containing aircraft groups
  - Default: `aircraft-templates.yaml`

- `--mode MODE`: Injection mode
  - `add`: Add new groups to existing ones (default)
  - `replace`: Replace groups with the same name

- `--verbose`: Enable detailed debug output

- `--readme`: Display this help documentation

- `--pause`: Pause and wait for user input when finished

## How It Works

### Validation Phase

The injector validates the YAML file BEFORE injection:

1. **YAML Parsing**: Checks if YAML is properly formatted
2. **Structure Validation**: Validates hierarchical structure
   - Top-level categories: `airplanes`, `helicopters`
   - Coalition levels: `blue`, `red`
   - Country levels with groups
   - Group contents with units
3. **Type Checking**: Ensures proper data types at each level
4. **Required Fields**: Checks for mandatory fields (`name`, `type`, `units`)

**If validation FAILS:**
- Displays validation report with detailed error messages
- Stops execution immediately
- Does NOT inject any groups

**If validation SUCCEEDS:**
- Proceeds to injection phase

### Injection Phase

1. **Load YAML**: Reads validated aircraft groups from YAML file
2. **Load Mission**: Reads the target DCS mission
3. **Process Groups**: Iterates through categories → coalitions → countries → groups
4. **Create Structure**: Creates missing coalition/country structures as needed
5. **Inject Groups**: Adds or replaces groups in the mission
6. **Write Mission**: Saves the modified mission to the output path

## Injection Modes

### Add Mode (default)

```bash
python veaf-tools.py inject-aircraft-groups mission.miz
```

- Adds all groups from YAML to the mission
- Existing groups are preserved
- If a group with the same name exists, it will be added again (creates duplicate)
- Use this when you want to ADD new groups to a mission

### Replace Mode

```bash
python veaf-tools.py inject-aircraft-groups --mode replace mission.miz
```

- Replaces groups with the same name in the mission
- Preserves groups that don't have a matching name in YAML
- Useful for updating specific group definitions
- Use this when you want to UPDATE existing groups in a mission

## YAML File Format

The YAML file should follow this structure:

```yaml
airplanes:
  coalitions:
    blue:
      France:
        Mirage-2000-5:
          name: "Mirage-2000-5"
          type: "M-2000C"
          units:
            - type: "M-2000C"
              name: "Pilot-1"
            - type: "M-2000C"
              name: "Pilot-2"
        Rafale-Flight:
          name: "Rafale-Flight"
          type: "Rafale C"
          units:
            - type: "Rafale C"
              name: "Rafale-1"
            - type: "Rafale C"
              name: "Rafale-2"

helicopters:
  coalitions:
    red:
      Russia:
        Hind-Group:
          name: "Hind-Group"
          type: "Mi-8MT"
          units:
            - type: "Mi-8MT"
              name: "Heli-1"
            - type: "Mi-8MT"
              name: "Heli-2"
```

### Structure Requirements

- **airplanes / helicopters**: Aircraft categories (optional but recommended)
  - **coalitions**: Coalition container (REQUIRED)
    - **blue / red**: Coalition names (only these two are valid)
      - **[Country Name]**: Country container (any string)
        - **[Group Name]**: Group container (key should match the name field)
          - **name**: Group name (string, REQUIRED)
          - **type**: Group type/primary aircraft type (string, REQUIRED)
          - **units**: List of unit dictionaries (REQUIRED, must have at least 1)
            - **type**: Unit type (string, REQUIRED)
            - **name**: Unit name (string, optional)

## Validation Errors

### Common Errors

**Error: "Missing required field 'name'"**
- Solution: Ensure each group has a `name` field with a string value

**Error: "Group must have at least one unit"**
- Solution: Ensure the `units` field contains at least one unit object

**Error: "Unknown coalition"**
- Solution: Only use `blue` and `red` as coalition names

### Error Levels

The validator reports three levels of issues:

- **ERROR**: Critical issues that prevent injection
- **WARNING**: Potential issues with non-critical impact
- **INFO**: Informational messages about unusual structures

All errors must be fixed before injection can proceed.

## Examples

### Basic Injection (Add Mode)

```bash
python veaf-tools.py inject-aircraft-groups mission.miz mission-modified.miz \
  --template-file aircraft-templates.yaml
```

Result: All groups from YAML are added to the mission

### Replace Mode (Update Existing Groups)

```bash
python veaf-tools.py inject-aircraft-groups mission.miz mission-modified.miz \
  --template-file aircraft-templates.yaml \
  --mode replace
```

Result: Groups with matching names are replaced; others are preserved

### With Verbose Output

```bash
python veaf-tools.py inject-aircraft-groups mission.miz \
  --template-file aircraft-templates.yaml \
  --verbose
```

Result: Shows detailed injection log for each group

## Complete Workflow Example

### Extract → Validate → Inject

```python
from pathlib import Path
from aircrafts_injector import (
    AircraftGroupsExtractorWorker,
    AircraftGroupsYAMLValidator,
    AircraftGroupsInjectorWorker
)

# Step 1: Extract groups from a mission
extractor = AircraftGroupsExtractorWorker(
    input_mission=Path("mission-with-templates.miz"),
    output_yaml=Path("templates.yaml"),
    group_name_pattern="veafSpawn-.*"
)
extractor.extract(interactive=True)

# Step 2: Validate the extracted file (if you edited it)
validator = AircraftGroupsYAMLValidator(Path("templates.yaml"))
is_valid, errors = validator.validate()

if not is_valid:
    print("Validation failed:")
    print(validator.get_report())
    exit(1)

# Step 3: Inject into a target mission
# (Note: The CLI command does validation automatically)
injector = AircraftGroupsInjectorWorker(
    input_yaml=Path("templates.yaml"),
    target_mission=Path("target-mission.miz"),
    output_mission=Path("target-mission-modified.miz")
)

result = injector.inject(mode='add')
if result.success:
    print(f"✓ Successfully injected {result.groups_injected} groups")
```

## Best Practices

1. **Always Check Validation Warnings**
   - Fix all warnings before injecting
   - Warnings often indicate issues that may cause problems

2. **Test on Mission Copies**
   - Always test injections on copies first
   - Keep backups of original missions

3. **Use Appropriate Mode**
   - Use `add` mode when injecting new groups
   - Use `replace` mode when updating existing definitions

4. **Review Extraction Before Injection**
   - If you manually edited the YAML, verify it's still valid
   - Check that group names and types are correct

5. **Document Your Groups**
   - Use clear, descriptive group names
   - Follow naming conventions (e.g., "veafSpawn-*" for spawnable groups)

## Troubleshooting

### YAML Validation Fails

**Problem**: Validation errors before injection

**Solution**:
1. Check the validation report for specific errors
2. Fix the YAML file according to error messages
3. Re-run the injection command

### Groups Don't Appear in Mission

**Problem**: Groups were validated but don't appear in the result

**Solution**:
1. Verify the YAML file was correctly extracted
2. Check the injection was successful (no errors)
3. Verify the output mission was saved correctly

### Duplicate Groups Appear

**Problem**: Using `add` mode created duplicate groups

**Solution**:
1. Use `replace` mode if you want to update instead of add
2. Or manually remove duplicates from the YAML before injecting

## Integration with Extraction

The Aircraft Groups Injector works seamlessly with the Extractor:

1. Use `extract-aircraft-groups` to extract groups from one mission
2. Use `inject-aircraft-groups` to inject them into other missions
3. Both commands use the same YAML format for compatibility

## Notes

- The injector creates missing coalition/country structures automatically
- Groups are deep-copied to prevent modification of original data
- Injection preserves all other mission data untouched
- The injector works with the mission structure format used by DCS
- Validation happens automatically - you cannot bypass it
- If validation fails, detailed error messages guide you to the issue
"""
