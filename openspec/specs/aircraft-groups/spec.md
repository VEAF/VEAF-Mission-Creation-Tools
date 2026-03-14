# Capability: Aircraft Groups Management

## Purpose

Extract aircraft groups from missions and inject predefined aircraft group templates into DCS missions.

## Requirements

### Requirement: Extract Aircraft Groups to YAML
The system SHALL extract aircraft group definitions from a DCS mission and save them to a YAML file.

#### Scenario: Extract all aircraft groups
- **WHEN** user runs `veaf-tools extract-aircraft-groups MyMission.miz --output-yaml templates.yaml`
- **THEN** the system extracts all aircraft groups (planes and helicopters)
- **AND** saves them in a structured YAML format
- **AND** preserves unit positions, loadouts, and configurations

#### Scenario: Extract with name pattern filter
- **WHEN** user runs `veaf-tools extract-aircraft-groups MyMission.miz --group-name-pattern "^Template.*"`
- **THEN** only groups matching the regex pattern are extracted

#### Scenario: Extract only airplanes
- **WHEN** user runs `veaf-tools extract-aircraft-groups MyMission.miz --only-airplanes`
- **THEN** only fixed-wing aircraft groups are extracted
- **AND** helicopter groups are excluded

#### Scenario: Interactive selection mode
- **WHEN** user runs `veaf-tools extract-aircraft-groups --interactive MyMission.miz`
- **THEN** the system displays a list of available groups
- **AND** user can select which groups to include in the output

### Requirement: Extract from Lua Settings File
The system SHALL support extracting aircraft groups from legacy Lua settings files.

#### Scenario: Extract from Lua file
- **WHEN** user runs `veaf-tools extract-aircraft-groups --lua-input settings-templates.lua`
- **THEN** the system parses the Lua file
- **AND** extracts group definitions to YAML format

### Requirement: Validate Aircraft Groups YAML
The system SHALL validate YAML files before injection to ensure correctness.

#### Scenario: Valid YAML structure
- **WHEN** user provides a correctly structured YAML file
- **THEN** validation passes with no errors
- **AND** injection can proceed

#### Scenario: Invalid YAML structure
- **WHEN** YAML file has missing required fields (e.g., unit type)
- **THEN** validation fails with detailed error messages
- **AND** injection is blocked until errors are fixed

### Requirement: Inject Aircraft Groups from YAML
The system SHALL inject aircraft group definitions from a YAML file into a DCS mission.

#### Scenario: Add new groups
- **WHEN** user runs `veaf-tools inject-aircraft-groups --mode add --template-file templates.yaml MyMission.miz`
- **THEN** the system adds all groups from the YAML file to the mission
- **AND** groups are assigned to the correct coalition and country
- **AND** unique group IDs are generated

#### Scenario: Replace existing groups
- **WHEN** user runs `veaf-tools inject-aircraft-groups --mode replace --template-file templates.yaml MyMission.miz`
- **THEN** existing groups with matching names are replaced
- **AND** new groups are added if they don't exist

### Requirement: YAML Format Structure
The system SHALL use a hierarchical YAML structure organized by aircraft category, coalition, and country.

#### Scenario: YAML structure
- **WHEN** extracting aircraft groups
- **THEN** the output follows this structure:
  ```yaml
  airplanes:
    blue:
      USA:
        - name: "Template F-16"
          type: "F-16C_50"
          units:
            - type: "F-16C_50"
              skill: "Client"
              payload: {...}
  helicopters:
    red:
      Russia:
        - name: "Template Ka-50"
          ...
  ```
