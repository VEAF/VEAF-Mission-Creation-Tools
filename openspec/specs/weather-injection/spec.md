# Capability: Weather and Time Injection

## Purpose

Create multiple mission variants with different weather conditions and start times from a single base mission.

## Requirements

### Requirement: Create Mission Variants from Configuration
The system SHALL read a YAML configuration file and generate multiple mission files with different weather and time settings.

#### Scenario: Generate weather variants
- **WHEN** user runs `veaf-tools inject-weather MyMission.miz --config-file missions.yaml`
- **AND** config file defines variants: "Dawn Clear", "Noon Overcast", "Night Storm"
- **THEN** the system creates three separate .miz files
- **AND** each file has the specified weather and time settings

#### Scenario: Configuration file not found
- **WHEN** user specifies a non-existent configuration file
- **THEN** the system displays an error message
- **AND** no missions are created

### Requirement: Support Time Expressions
The system SHALL support flexible time expressions including solar-relative times.

#### Scenario: Solar time expressions
- **WHEN** configuration specifies `time: "sunrise + 30m"`
- **AND** mission position is defined (latitude/longitude)
- **THEN** the system calculates sunrise for that location and date
- **AND** sets mission start time to 30 minutes after sunrise

#### Scenario: Absolute time
- **WHEN** configuration specifies `time: "14:30"`
- **THEN** mission start time is set to 14:30 local time

#### Scenario: Relative time offset
- **WHEN** configuration specifies `time: "sunset - 1h"`
- **THEN** mission starts 1 hour before sunset at the mission location

### Requirement: Support Weather Presets
The system SHALL support predefined weather presets and custom weather configurations.

#### Scenario: Use weather preset
- **WHEN** configuration specifies `weather: "overcast"`
- **THEN** the system applies the predefined overcast weather settings
- **AND** cloud layers, visibility, and precipitation are configured accordingly

#### Scenario: Custom weather parameters
- **WHEN** configuration specifies detailed weather:
  ```yaml
  weather:
    clouds:
      base: 2000
      thickness: 500
      density: 8
    wind:
      speed: 15
      direction: 270
    visibility: 8000
  ```
- **THEN** the system applies these exact parameters to the mission

### Requirement: Support Date Configuration
The system SHALL support setting the mission date.

#### Scenario: Specific date
- **WHEN** configuration specifies `date: "2024-06-15"`
- **THEN** the mission date is set to June 15, 2024

#### Scenario: Relative date
- **WHEN** configuration specifies `date: "today + 7d"`
- **THEN** the mission date is set to 7 days from current date

### Requirement: Convert Legacy Lua Configuration
The system SHALL support converting legacy Lua configuration files to YAML format.

#### Scenario: Convert Lua to YAML
- **WHEN** user runs `veaf-tools inject-weather --convert-lua missions.lua`
- **THEN** the system parses the Lua configuration
- **AND** creates an equivalent YAML file
- **AND** offers to create missions from the converted configuration

### Requirement: YAML Configuration Format
The system SHALL accept a structured YAML configuration format.

#### Scenario: Complete configuration example
- **WHEN** the configuration file contains:
  ```yaml
  position:
    latitude: 42.0
    longitude: 43.0
  
  versions:
    - name: "dawn_clear"
      time: "sunrise"
      weather: "clear"
      
    - name: "noon_storm"
      date: "2024-06-15"
      time: "12:00"
      weather:
        preset: "storm"
        wind_speed: 25
  ```
- **THEN** the system creates missions named `MyMission_dawn_clear.miz` and `MyMission_noon_storm.miz`
