MissionBuilderREADME="""
# VEAF Tools - Mission Builder User Guide

The Mission Builder compiles a VEAF mission folder into a DCS World mission file (.miz), integrating scripts, configuration, and assets into a deployable package.

## Overview

The builder takes a structured mission folder and creates a complete .miz file with all necessary VEAF scripts, triggers, and configurations. It supports both static and dynamic loading modes for development and production use.

## Prerequisites

- A properly structured VEAF mission folder
- Access to VEAF and community scripts (local or via node_modules)
- Python environment with veaf-tools installed

## Usage

### Command Line

```bash
python veaf-tools.py build-mission [OPTIONS] MISSION_FOLDER [MISSION_NAME_OR_FILE]
```

#### Parameters

- `MISSION_FOLDER`: Folder containing the mission files
- `MISSION_NAME_OR_FILE`: (Optional) Output mission name or .miz file path. Defaults to "mission.miz" with current date.

#### Options

- `--dynamic-mode`: Load scripts dynamically from specified path instead of embedding
- `--scripts-path PATH`: Path to VEAF and community scripts
- `--migrate-from-v5`: Remove legacy VEAF v5 triggers (default: true)
- `--verbose`: Enable detailed logging output
- `--readme`: Display the README documentation

#### Examples

```bash
# Build mission with default settings
python veaf-tools.py build-mission ./my_mission

# Build with dynamic loading
python veaf-tools.py build-mission --dynamic-mode --scripts-path ../veaf-scripts ./my_mission

# Build to specific output file
python veaf-tools.py build-mission ./my_mission final_mission.miz
```

## Folder Structure

The mission folder should contain:

```
mission_folder/
├── src/
│   ├── mission/
│   │   ├── mission
│   │   ├── options
│   │   └── warehouses
│   ├── scripts/
│   │   ├── missionConfig.lua
│   │   └── [custom scripts]
│   └── [other files]
└── node_modules/veaf-mission-creation-tools/ (optional)
```

## Processing Steps

1. **File Collection**: Gathers VEAF scripts, community scripts, and mission files
2. **Default Completion**: Adds missing default files from templates
3. **Mission Creation**: Builds initial .miz file from collected files
4. **Trigger Management**: Clears old VEAF triggers and inserts new ones
5. **Finalization**: Writes the complete mission file

## Loading Modes

### Static Mode (Default)
- Embeds all scripts directly into the .miz file
- Self-contained mission, no external dependencies
- Larger file size but more portable

### Dynamic Mode
- Scripts loaded from external paths at runtime
- Smaller .miz files, easier development iteration
- Requires scripts to be available at specified paths

## Trigger System

The builder automatically manages VEAF triggers for:

- Script loading (static vs dynamic)
- Mission configuration loading
- Proper initialization order

## Output

- A complete .miz file ready for DCS World
- Console output showing processing progress
- Warnings for missing components

## Integration

The mission builder is part of the complete VEAF workflow:

1. Extract existing missions (if needed)
2. Edit mission files
3. Build to create deployable .miz
4. Optionally inject presets

## Troubleshooting

- **Missing scripts**: Ensure VEAF scripts are available at specified path
- **Trigger conflicts**: Use --migrate-from-v5 to clean legacy triggers
- **File permissions**: Ensure write access to output location

## Related Tools

- **Mission Extractor**: Convert .miz files to editable folders
- **Mission Converter**: Extract, modify, and rebuild in one step
- **Presets Injector**: Add radio presets to completed missions
"""