# Presets.yaml Configuration File

## Overview

The `presets.yaml` file is a YAML configuration file used in VEAF (Virtual European Air Force) mission creation tools for Digital Combat Simulator (DCS). It defines radio presets, channel frequencies, and assignments for different coalitions and aircraft types. This file enables automated configuration of radio communications in DCS missions, ensuring consistent and realistic radio setups for pilots.

The file is structured hierarchically with four main sections:
- `channels_collection`: Defines available radio channels with their frequencies across different radio types.
- `radios_collection`: Defines radio configurations (UHF, VHF, FM) with their channel mappings.
- `presets_collection`: Groups radios into preset collections for different scenarios.
- `presets_assignments`: Assigns presets to specific coalitions, aircraft unit types, and aircraft models.

## File Structure

```yaml
radios_collection:
  # Radio definitions

presets_collection:
  # Preset groupings

presets_assignments:
  # Assignments by coalition and unit type

channels_collection:
  # Channel frequency definitions
```

## Radios Collection

This section defines individual radio configurations. Each radio specifies its type, display title, and channel mappings.

### Structure

```yaml
radios_collection:
  <collection_name>:
    <radio_name>:
      title: "<display_title>"
      type: <radio_type>  # uhf | vhf | fm
      channels:
        <channel_number>: <channel_alias> | <channel_definition>
```

### Parameters

- **collection_name**: A descriptive name for the radio collection (e.g., `blue_radios`, `red_radios`).
- **radio_name**: Unique identifier for the radio configuration (e.g., `radio_uhf_30`).
- **title**: Human-readable name displayed in exported kneeboard PNGs.
- **type**: Radio type that determines which frequencies are used from the channels collection:
  - `uhf`: Ultra High Frequency (military aviation)
  - `vhf`: Very High Frequency (civil/military aviation)
  - `fm`: Frequency Modulation (ground communications)
- **channels**: Mapping of channel numbers (01-30) to channel aliases or definitions.

### Channel Definition Formats

Channels can be defined in two ways:

1. **Simple alias** (string):
   ```yaml
   01: Guard
   ```

2. **Detailed definition** (dictionary):

   In this case, the 'channel' key should point to a channe in one of the channel collections, and the rest of the key can overwrite the values defined in the channel from the collection

   ```yaml
   01:
     title: "Guard/UHF"
     channel: Guard
   ```

3. **Complete definition** (dictionary)

  In this case, all of the attributes of a channel are set here; no alias is ever used.

   ```yaml
   03:
     title: "AFAC/VHF"
     freq: 125.0
   ```

  The only mandatory attribute is 'freq'; if only this attribute is set, it can be simplified by using the frequency value directly

   ```yaml
   04: 132.00
   ```

### Example

```yaml
radios_collection:
  blue_radios:
    radio_uhf_30:
      title: UHF/Primary
      type: uhf
      channels:
        01:
          title: Guard/UHF
          channel: Guard
        02: Archer
        03:
          title: "AFAC/VHF"
          freq: 125.0
        04: 132.0
        # ... channels 04-30
```

## Presets Collection

This section groups radios into preset collections that can be assigned to different aircraft configurations.

### Structure

```yaml
presets_collection:
  <collection_name>:
    <preset_name>:
      title: "<display_title>"
      radios:
        radio_1: <radio_name>
        radio_2: <radio_name>
        radio_3: <radio_name>
```

### Parameters

- **collection_name**: Descriptive name for the presets collection (e.g., `blue_presets`).
- **preset_name**: Unique identifier for the preset (e.g., `modern_blue_uhf_vhf_fm`).
- **title**: Human-readable name displayed in exported kneeboard PNGs.
- **radios**: Mapping of radio slots (radio_1, radio_2, radio_3) to radio names from the radios_collection.

### Example

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

## Presets Assignments

This section assigns preset collections to specific coalitions, unit types, and aircraft models.

### Structure

```yaml
presets_assignments:
  <coalition>:
    <unit_type>:
      <specific_unit>: <preset_name> | "none"
      all: <preset_name> | "none"
```

### Parameters

- **coalition**: Coalition identifier (`blue`, `red`, etc.).
- **unit_type**: Unit category (`plane`, `helicopter`).
- **specific_unit**: Specific aircraft model identifier (e.g., `A-10C_2`).
- **preset_name**: Name of the preset from presets_collection, or `"none"` to disable presets.

### Assignment Hierarchy

Assignments are processed in order of specificity:
1. Specific unit assignments override general assignments
2. `all` assignments apply to all units in the category unless overridden

### Example

```yaml
presets_assignments:
  blue:
    plane:
      all: modern_blue_uhf_vhf_fm
      A-10C_2: modern_blue_vhf_uhf_fm
    helicopter:
      Mi-8MT: none
      all: modern_blue_uhf_vhf_fm
      CH-47Fbl1: modern_blue_fm_uhf
```

## Channels Collection

This section defines all available radio channels with their frequencies. Channels are organized into collections by type or region.

### Structure

```yaml
channels_collection:
  <collection_name>:
    <channel_alias>:
      title: "<display_title>"  # optional
      data: <misc. data> # optional
      freqs:
        uhf: <frequency>  # optional
        vhf: <frequency>  # optional
        fm: <frequency>   # optional
```

### Parameters

- **collection_name**: Descriptive name for the channel collection (e.g., `airports-caucasus`, `tactical`).
- **channel_alias**: Unique identifier used as reference in radio channel mappings.
- **title**: Optional human-readable name for the channel (defaults to empty if not specified).
- **data**: Optional human-readable misc. data for the channel (defaults to empty if not specified).
- **freqs**: Frequency definitions for different radio types:
  - **uhf**: Ultra High Frequency in MHz (e.g., `243.000`)
  - **vhf**: Very High Frequency in MHz (e.g., `121.500`)
  - **fm**: Frequency Modulation in MHz (e.g., `40.400`)

### Frequency Requirements

- At least one frequency type must be defined per channel
- Frequencies should be valid for the respective radio type
- Values are in MHz with three decimal places
- When a channel is used in a radio, the radio type determines which frequency is used.

### Example

```yaml
channels_collection:
  tactical:
    Guard:
      title: Guard
      freqs:
        uhf: 243.000
        vhf: 121.500
    Stennis:
      title: Stennis / 10X
      freqs:
        uhf: 225.000
  airports-caucasus:
      Kutaisi:
      title: Batumi
      data: TACAN 16X, ARR/RW12 DEP/RW30
      freqs: 
        uhf: 260.000
        vhf: 131.000
        fm:  40.400
```

## Syntax Notes

### YAML Formatting
- Use consistent indentation (2 spaces recommended)
- Strings can be quoted or unquoted
- Numeric values should include decimal places for frequencies
- Comments start with `#`

### Required vs Optional Fields
- **Required**: `type`, `channels` (in radios), `radios` (in presets), `freqs` (in channels)
- **Optional**: `title` (everywhere), individual frequencies in `freqs`

### Channel References
- Channel aliases in radio definitions must match channel names in channels_collection
- The radio `type` determines which frequency is selected from the channel's `freqs`

### Best Practices
- Use descriptive names for collections and presets
- Maintain consistent channel numbering (01-30) in radio definitions
- Include titles for important channels for better documentation
- Use "none" in assignments to disable presets for specific units

This configuration enables flexible radio setup management across different mission scenarios, ensuring pilots have appropriate communication channels based on their aircraft type and coalition.

## Default values

The `src\defaults\mission-folder\src\presets.yaml` file contains sensible defaults with examples; it will be updated regularily with the data about all the airfields in all the DCS maps.