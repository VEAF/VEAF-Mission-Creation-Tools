MissionConverterREADME="""
# VEAF Tools - Mission Converter User Guide

The Mission Converter combines extraction, building, and optional preset injection into a single streamlined workflow for converting DCS missions to the VEAF format.

## Overview

The converter takes an existing .miz file and transforms it into a complete VEAF mission folder, optionally injects radio presets, and rebuilds it as a new mission. This is the most comprehensive tool for migrating missions to the VEAF ecosystem.

## Prerequisites

- A DCS World mission file (.miz)
- Empty target folder for the mission
- Optional: Presets configuration file (presets.yaml)
- Python environment with veaf-tools installed

## Usage

### Command Line

```bash
python veaf-tools.py convert-mission [OPTIONS] MISSION_NAME MISSION_FOLDER
```

#### Parameters

- `MISSION_NAME`: Name of the mission (used for finding .miz files and naming output)
- `MISSION_FOLDER`: Target folder for the converted mission

#### Options

- `--dynamic-mode`: Load scripts dynamically from specified path
- `--scripts-path PATH`: Path to VEAF and community scripts
- `--inject-presets`: Inject radio presets from presets.yaml
- `--presets-file PATH`: Path to presets configuration file
- `--verbose`: Enable detailed logging output
- `--readme`: Display the README documentation

#### Examples

```bash
# Basic conversion
python veaf-tools.py convert-mission my_mission ./converted_mission

# Convert with presets injection
python veaf-tools.py convert-mission --inject-presets my_mission ./converted_mission

# Full conversion with custom paths
python veaf-tools.py convert-mission --dynamic-mode --scripts-path ../veaf-scripts --inject-presets --presets-file custom.yaml my_mission ./converted_mission
```

## Processing Workflow

The converter performs these steps in sequence:

1. **Extraction**: Converts .miz to VEAF folder structure
2. **Building**: Compiles folder to temporary .miz with VEAF integration
3. **Preset Injection** (optional): Adds radio presets to the mission
4. **Re-extraction**: Converts back to folder for editing
5. **Configuration**: Updates mission name in config files
6. **Final Build**: Creates the final .miz file

## Output

- A complete VEAF mission folder with all components
- A rebuilt .miz file with VEAF integration
- Optional kneeboard images if presets were injected
- Console progress updates throughout the process

## Folder Structure Created

```
mission_folder/
├── src/
│   ├── mission/
│   │   ├── mission
│   │   ├── options
│   │   └── warehouses
│   ├── scripts/
│   │   ├── missionConfig.lua (updated with mission name)
│   │   └── [other scripts]
│   └── presets.yaml (if presets were injected)
├── published/ (automatically fetched with veaf-tools-updater)
└── [output .miz file]
```

## Preset Integration

When `--inject-presets` is used:

- Presets are injected into aircraft groups with human pilots
- Kneeboard images are generated for pilot reference
- Mission folder includes the presets configuration

## Loading Modes

### Static Mode (Default)
- All scripts embedded in the .miz file
- Self-contained, no external dependencies
- Best for distribution

### Dynamic Mode
- Scripts loaded from external paths
- Smaller files, faster development iteration
- Requires scripts available at runtime

## Use Cases

- **Migration**: Convert existing missions to VEAF format
- **Development**: Set up missions for collaborative editing
- **Deployment**: Create production-ready missions with presets
- **Backup**: Extract missions for version control

## Troubleshooting

- **File conflicts**: Ensure target folder is empty
- **Missing presets**: Verify presets.yaml exists and is valid
- **Script paths**: Confirm VEAF scripts are accessible
- **Permissions**: Ensure write access to target folder

## Related Tools

- **Mission Extractor**: Extract only (no rebuilding)
- **Mission Builder**: Build folders to .miz (no extraction)
- **Presets Injector**: Add presets to existing .miz files

## Performance Notes

The converter is resource-intensive as it performs multiple extraction and building cycles. For large missions, ensure adequate disk space and processing time.
"""