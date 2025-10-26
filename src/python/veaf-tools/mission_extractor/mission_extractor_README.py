MissionExtractorREADME="""
# VEAF Tools - Mission Extractor User Guide

The Mission Extractor converts a DCS World mission file (.miz) into a VEAF mission folder structure, making it easier to edit and manage mission components.

## Overview

The extractor takes a compiled .miz file and decomposes it into a structured folder containing all mission assets, scripts, and configuration files. This allows for version control, collaborative editing, and integration with the VEAF mission creation tools.

## Prerequisites

- A DCS World mission file (.miz)
- Target folder for extraction
- Python environment with veaf-tools installed

## Usage

### Command Line

```bash
python veaf-tools.py extract-mission [OPTIONS] INPUT_MISSION [MISSION_FOLDER]
```

#### Parameters

- `INPUT_MISSION`: Path to the .miz mission file, or mission name (will find the most recent matching .miz file)
- `MISSION_FOLDER`: (Optional) Target folder for extracted files. Defaults to current directory.

#### Options

- `--verbose`: Enable detailed logging output
- `--readme`: Display the README documentation

#### Examples

```bash
# Extract mission to current directory
python veaf-tools.py extract-mission my_mission.miz

# Extract to specific folder
python veaf-tools.py extract-mission input.miz ./my_mission_folder

# Verbose extraction
python veaf-tools.py extract-mission --verbose my_mission.miz
```

## What Gets Extracted

The extractor creates a structured folder with:

- **src/mission/**: Core mission files (mission, options, warehouses, etc.)
- **src/scripts/**: Mission-specific Lua scripts
- **src/l10n/DEFAULT/**: Localized content and additional scripts

## Processing Steps

1. **Normalization**: The mission is temporarily normalized to ensure consistency
2. **Decompression**: The .miz file is unzipped to a temporary location
3. **Cleanup**: VEAF, community, and legacy scripts are removed from the extracted content
4. **File Management**: Mission files are moved or copied to appropriate locations
5. **Organization**: Files are organized into the standard VEAF folder structure

## Output Structure

After extraction, you'll have a folder structure like:

```
mission_folder/
├── src/
│   ├── mission/
│   │   ├── mission
│   │   ├── options
│   │   └── warehouses
│   └── scripts/
│       ├── missionConfig.lua
│       └── [other mission scripts]
└── [other extracted files]
```

## Integration

The mission extractor is typically used as the first step in the mission development workflow:

1. Extract an existing mission
2. Edit scripts and configuration
3. Use the mission builder to compile back to .miz

## Troubleshooting

- **Permission errors**: Ensure write access to the target folder
- **Corrupted mission**: Verify the .miz file is valid
- **Missing files**: Some missions may have missing components (logged as warnings)

## Related Tools

- **Mission Builder**: Compile extracted folders back to .miz files
- **Mission Converter**: Extract and convert missions in one step
"""