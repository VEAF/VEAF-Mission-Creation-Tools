# Capability: Waypoints Management

## Purpose

Extract and inject waypoints for human-piloted aircraft groups in DCS missions.

## Requirements

### Requirement: Extract Waypoints to YAML
The system SHALL extract flight plan waypoints from human-piloted aircraft groups and save them to a YAML file.

#### Scenario: Extract waypoints from mission
- **WHEN** user runs `veaf-tools extract-waypoints MyMission.miz --output-yaml waypoints.yaml`
- **THEN** the system identifies all human-piloted aircraft groups
- **AND** extracts their waypoint definitions
- **AND** saves them in a structured YAML format

#### Scenario: Extract with name pattern filter
- **WHEN** user runs `veaf-tools extract-waypoints --group-name-pattern "^Fighter.*" MyMission.miz`
- **THEN** only waypoints from groups matching the pattern are extracted

#### Scenario: Interactive extraction
- **WHEN** user runs `veaf-tools extract-waypoints --interactive MyMission.miz`
- **THEN** the system displays available groups
- **AND** user selects which groups' waypoints to extract

### Requirement: Extract from Lua Settings File
The system SHALL support extracting waypoints from legacy Lua settings files.

#### Scenario: Extract from Lua file
- **WHEN** user runs `veaf-tools extract-waypoints --lua-input settings-waypoints.lua`
- **THEN** the system parses the Lua file
- **AND** extracts waypoint definitions to YAML format

### Requirement: Inject Waypoints from YAML
The system SHALL inject waypoint definitions from a YAML file into matching aircraft groups.

#### Scenario: Inject waypoints into human aircraft
- **WHEN** user runs `veaf-tools inject-waypoints --waypoints-file waypoints.yaml MyMission.miz`
- **THEN** the system matches groups by name pattern or explicit mapping
- **AND** replaces or appends waypoints to the flight plan
- **AND** only human-piloted groups are modified

#### Scenario: Waypoint file not found
- **WHEN** user specifies a non-existent waypoints file
- **THEN** the system displays an error message
- **AND** the operation aborts without modifying the mission

### Requirement: Waypoint YAML Format
The system SHALL use a structured YAML format for waypoint definitions.

#### Scenario: YAML format structure
- **WHEN** extracting or defining waypoints
- **THEN** the format includes:
  ```yaml
  waypoints:
    - name: "BULLSEYE"
      type: "Turning Point"
      position:
        x: 12345.67
        y: 89012.34
      altitude: 7620  # meters
      speed: 250      # m/s
      action: "Turning Point"
  
  flight_plans:
    - group_pattern: "^Fighter.*"
      waypoints:
        - ref: "BULLSEYE"
        - name: "IP"
          position: {...}
  ```

### Requirement: Support Named Waypoint References
The system SHALL support referencing shared waypoint definitions across multiple flight plans.

#### Scenario: Shared waypoint reference
- **WHEN** multiple flight plans reference "BULLSEYE" waypoint
- **THEN** all groups receive the same coordinates
- **AND** updating the waypoint definition updates all references
