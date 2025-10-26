PresetsInjectorREADME="""
# VEAF Tools - Radio Presets Injector User Guide

The Radio Presets Injector is a tool that automatically injects radio frequency presets into DCS World mission files (.miz) for aircraft groups with human pilots. This simplifies mission setup by pre-configuring radio channels with realistic frequencies for airports, tactical communications, and flight callsigns.

## Overview

The injector works by:
1. Reading a YAML configuration file that defines radio presets, channels, and assignments
2. Scanning the mission file for aircraft groups containing human pilots
3. Injecting the appropriate radio presets based on coalition, aircraft type, and unit type
4. Optionally generating kneeboard images showing the preset configurations

## Prerequisites

- A DCS World mission file (.miz)
- A presets configuration file (typically `presets.yaml`)
- Python environment with veaf-tools installed

## Usage

### Command Line

```bash
python veaf-tools.py inject-presets [OPTIONS] INPUT_MISSION [OUTPUT_MISSION]
```

#### Parameters

- `INPUT_MISSION`: Path to the input .miz mission file, or mission name (will find the most recent matching .miz file)
- `OUTPUT_MISSION`: (Optional) Path for the output mission file. Defaults to overwriting the input file.

#### Options

- `--presets-file PATH`: Path to the presets YAML configuration file (default: `./src/presets.yaml`)
- `--verbose`: Enable detailed logging output
- `--readme`: Display the README documentation

#### Examples

```bash
# Inject presets using default configuration
python veaf-tools.py inject-presets my_mission.miz

# Inject presets with custom configuration and output file
python veaf-tools.py inject-presets --presets-file custom_presets.yaml input.miz output.miz

# Verbose mode for debugging
python veaf-tools.py inject-presets --verbose my_mission.miz
```

## Configuration File Format

The presets are defined in a YAML file with the following structure:

### Channels Collection

Defines available radio channels with frequencies for different radio types (UHF, VHF, FM):

```yaml
channels_collection:
  airports-caucasus:
    Batumi:
      title: Batumi / 16X
      freqs:
        uhf: 260
        vhf: 131
        fm: 40.4
```

### Radios Collection

Defines radio configurations that reference channels:

```yaml
radios_collection:
  blue_radios:
    radio_uhf_30:
      title: UHF
      type: uhf
      channels:
        01: Guard
        02: Archer
        10: Stennis
```

### Presets Collection

Groups radios into named presets:

```yaml
presets_collection:
  blue_presets:
    modern_blue_uhf_vhf_fm:
      title: Blue coalition - classic UHF/VHF/FM
      radios:
        radio_1: radio_uhf_30
        radio_2: radio_vhf_30
        radio_3: radio_fm_30
```

### Presets Assignments

Assigns presets to specific aircraft types and coalitions:

```yaml
presets_assignments:
  blue:
    plane:
      all: modern_blue_uhf_vhf_fm
      A-10C_2: modern_blue_vhf_uhf_fm
    helicopter:
      all: modern_blue_uhf_vhf_fm
      CH-47Fbl1: modern_blue_fm_uhf
```

## How It Works

1. **Mission Scanning**: The tool unzips and parses the .miz file to find all aircraft groups
2. **Pilot Detection**: Identifies groups with human pilots (Client/Player skill levels)
3. **Preset Matching**: Matches each group to the appropriate preset based on coalition, aircraft type, and unit type
4. **Injection**: Updates the mission's radio configuration for each matching group
5. **Kneeboard Generation**: Creates PNG images of the preset tables for pilots' reference

## Output

- Modified .miz file with injected radio presets
- Kneeboard images (if presets are used) saved as `KNEEBOARD/IMAGES/presets-{preset_name}.png` within the mission file
- Console output showing processing progress and number of units updated

## Troubleshooting

- **No presets injected**: Check that aircraft groups have human pilots and match the assignment criteria
- **Configuration errors**: Validate YAML syntax and ensure all referenced channels/radios exist
- **File not found**: Verify paths to mission and presets files are correct

## Integration

The presets injector can be used standalone or as part of the mission conversion workflow via the `convert-mission` command with the `--inject-presets` flag.
"""