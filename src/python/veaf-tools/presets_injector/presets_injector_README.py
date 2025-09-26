PresetsInjectorREADME="""
# VEAF Radio Presets Injector

The VEAF Radio Presets Injector is a tool that allows you to inject radio presets into DCS mission files programmatically. This tool reads radio preset configurations from a YAML file and applies them to aircraft groups in your mission.

## Command Line Usage

```bash
python veaf-tools.py inject-presets [OPTIONS] [INPUT_MISSION] [OUTPUT_MISSION]
```

### Arguments

- `INPUT_MISSION`: The DCS mission file (.miz) to edit. Defaults to "mission.miz" if not specified.
- `OUTPUT_MISSION`: The DCS mission file (.miz) to save. Defaults to the same as INPUT_MISSION if not specified.

### Options

- `--verbose`: If set, the script will output detailed debug information.
- `--presets-file TEXT`: Configuration file containing the presets. Defaults to "presets.yaml" if not specified.

### Examples

```bash
# Basic usage with default files
python veaf-tools.py inject-presets

# Specify input and output mission files
python veaf-tools.py inject-presets my_mission.miz output_mission.miz

# Use a custom presets file
python veaf-tools.py inject-presets --presets-file custom_presets.yaml

# Enable verbose output
python veaf-tools.py inject-presets --verbose

# Combine options
python veaf-tools.py inject-presets --verbose --presets-file my_presets.yaml input.miz output.miz
```

## Presets Configuration File

The presets configuration file is a YAML file that defines radio presets and their assignments. It has two main sections:

### presets_definition

This section defines collections of radio presets that can be assigned to aircraft.

```yaml
presets_definition:
  modern_blue:  # Name of the preset collection
    title: Blue coalition planes and helicopters  # Display name for kneeboard
    radios:
      radio_1:  # First radio (will be [1] in DCS mission file)
        title: UHF/Primary  # Display name for kneeboard
        channels:  # Channel definitions
          channel_01:  # First channel (will be [1] in DCS mission file)
            freq: 243.000  # Frequency in MHz (mandatory)
            name: Guard    # Channel name (optional)
            mod: 0         # Modulation (0=AM, 1=FM, 2=VHF AM, 3=UHF) (optional, defaults to 0)
          channel_02:
            freq: 260.000
            name: Batumi / 16X
          # ... more channels
      radio_2:  # Second radio (will be [2] in DCS mission file)
        title: VHF/Secondary
        channels:
          # ... channel definitions
      # ... more radios
  modern_red:  # Another preset collection
    # ... similar structure
```

### presets_assignments

This section defines which preset collections are assigned to which coalitions and aircraft types.

```yaml
presets_assignments:
  coalitions:
    blue:  # Blue coalition
      plane:  # For fixed-wing aircraft
        all: modern_blue    # All planes use modern_blue presets
      helicopter:  # For rotary-wing aircraft
        Mi-8MT: none        # Mi-8MT helicopters use no presets
        all: modern_blue    # All other helicopters use modern_blue presets
    red:  # Red coalition
      plane:
        all: modern_red     # All planes use modern_red presets
      helicopter:
        all: none           # All helicopters use no presets
```

## How It Works

1. The tool reads the specified DCS mission file (.miz), which is essentially a ZIP archive containing mission data.
2. It parses the mission data to identify all aircraft groups in the mission.
3. For each aircraft group, it determines the coalition (blue/red), aircraft type (plane/helicopter), and specific unit type.
4. Based on the presets assignments in the configuration file, it selects the appropriate preset collection for each group.
5. It injects the radio presets into the aircraft group data in the mission file.
6. It generates kneeboard images showing the radio presets for each used collection.
7. It saves the modified mission file, including the new kneeboard images.

## Kneeboard Generation

When presets are injected into a mission, the tool automatically generates kneeboard images showing the radio presets for each preset collection that was used. These images are added to the mission file and can be accessed in-game by pilots.

The kneeboard images display:
- The preset collection title
- Each radio with its title
- Channel numbers, names, and frequencies in a tabular format

## Supported Radio Types

The tool supports up to 3 radios per aircraft:
- `radio_1`: Primary radio (typically UHF)
- `radio_2`: Secondary radio (typically VHF)
- `radio_3`: Ground communication radio (typically FM)

## Supported Modulations

- `0`: AM (Amplitude Modulation)
- `1`: FM (Frequency Modulation)
- `2`: VHF AM
- `3`: UHF

## Error Handling

The tool performs validation on:
- Input mission file existence
- Presets configuration file existence and validity
- Frequency ranges (0-100000 MHz)
- Modulation values (0-3)
- Proper structure of the presets configuration file

If any validation fails, the tool will display an error message and abort the operation.
"""