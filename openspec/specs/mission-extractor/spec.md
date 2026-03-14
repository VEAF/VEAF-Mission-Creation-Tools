# Capability: Mission Extractor

## Purpose

Extract DCS World mission files (.miz) to a structured VEAF mission folder for editing and version control.

## Requirements

### Requirement: Extract Mission to Folder
The system SHALL unpack a .miz file into a structured folder containing human-readable Lua source files.

#### Scenario: Extract mission to default folder
- **WHEN** user runs `veaf-tools extract MyMission.miz ./mission-folder`
- **THEN** the system extracts all mission components to `./mission-folder/src/`
- **AND** Lua tables are formatted for readability
- **AND** binary resources (images, sounds) are preserved

#### Scenario: Extract most recent mission by name
- **WHEN** user runs `veaf-tools extract MyMission ./mission-folder`
- **AND** multiple files match `MyMission*.miz`
- **THEN** the system selects the most recently modified .miz file
- **AND** extracts it to the specified folder

### Requirement: Normalize Lua Output
The system SHALL format extracted Lua tables consistently for version control diffing.

#### Scenario: Consistent key ordering
- **WHEN** a mission is extracted
- **THEN** Lua table keys are sorted alphabetically
- **AND** indentation uses consistent spacing
- **AND** numeric arrays maintain their original order

### Requirement: Preserve Mission Integrity
The system SHALL preserve all mission data during extraction without loss.

#### Scenario: Round-trip integrity
- **WHEN** a mission is extracted and then rebuilt
- **THEN** the rebuilt mission is functionally identical to the original
- **AND** DCS World loads the mission without errors
