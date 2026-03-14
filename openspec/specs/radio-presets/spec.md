# Capability: Radio Presets Injection

## Purpose

Inject standardized radio frequency presets into human-piloted aircraft groups from a YAML configuration file.

## Requirements

### Requirement: Inject Radio Presets from YAML
The system SHALL read radio preset definitions from a YAML file and apply them to matching aircraft groups in a DCS mission.

#### Scenario: Inject presets into human aircraft
- **WHEN** user runs `veaf-tools inject-presets MyMission.miz --presets-file presets.yaml`
- **THEN** the system identifies all human-piloted aircraft groups (skill = "Client" or "Player")
- **AND** applies matching radio presets based on aircraft type
- **AND** saves the modified mission

#### Scenario: Preset file not found
- **WHEN** user specifies a non-existent presets file
- **THEN** the system displays an error message
- **AND** the operation aborts without modifying the mission

### Requirement: Match Presets by Aircraft Type
The system SHALL match preset definitions to aircraft groups based on aircraft type (e.g., "F-16C_50", "FA-18C_hornet").

#### Scenario: Aircraft type matching
- **WHEN** a presets file defines frequencies for "F-16C_50"
- **AND** the mission contains F-16C groups with human pilots
- **THEN** those groups receive the defined radio presets
- **AND** AI-only groups are not modified

#### Scenario: No matching presets
- **WHEN** an aircraft type has no preset definition
- **THEN** the system logs a warning
- **AND** leaves the aircraft's radio presets unchanged

### Requirement: Support Multiple Radio Channels
The system SHALL support injecting presets for multiple radio channels per aircraft type.

#### Scenario: Multi-channel presets
- **WHEN** presets define frequencies for channels 1-20
- **THEN** each channel receives its configured frequency
- **AND** modulation (AM/FM) is set correctly per channel

### Requirement: YAML Configuration Format
The system SHALL accept presets in a structured YAML format.

#### Scenario: Valid YAML format
- **WHEN** the presets file contains:
  ```yaml
  aircraft_types:
    F-16C_50:
      radio1:
        - { channel: 1, frequency: 251.0, modulation: AM }
        - { channel: 2, frequency: 264.0, modulation: AM }
  ```
- **THEN** the system parses and applies these presets correctly
