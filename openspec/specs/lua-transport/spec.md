# Capability: Transport Missions (Runtime)

## Purpose

Generate helicopter cargo transport training missions dynamically during DCS mission runtime.

## Requirements

### Requirement: Create Transport Mission
The system SHALL create transport missions via the `_transport` marker command.

#### Scenario: Basic transport mission
- **WHEN** player places marker with `_transport`
- **THEN** cargo spawns at the marker location
- **AND** a destination with friendly troops is generated

#### Scenario: Transport with enemy defense
- **WHEN** player creates transport mission with defense option
- **THEN** enemy units spawn along the route to destination
- **AND** difficulty scales with defense parameter

### Requirement: Cargo Management
The system SHALL spawn cargo objects for helicopter pickup.

#### Scenario: Spawn cargo
- **WHEN** transport mission is created
- **THEN** cargo crates spawn at the pickup location
- **AND** cargo is compatible with helicopter sling loading

### Requirement: Friendly Troops
The system SHALL create a destination with friendly troops awaiting supplies.

#### Scenario: Create drop zone
- **WHEN** transport mission is created
- **THEN** friendly infantry group spawns at the drop zone
- **AND** group has ADF beacon for navigation

### Requirement: Route Defenses
The system SHALL generate enemy groups along the transport route.

#### Scenario: Generate threats
- **WHEN** transport mission has defense level > 0
- **THEN** AAA and MANPAD units spawn along the route
- **AND** safe zone near pickup and drop zones is maintained

### Requirement: Mission Monitoring
The system SHALL track transport mission status.

#### Scenario: Monitor friendly troops
- **WHEN** friendly troops at drop zone are destroyed
- **THEN** mission is marked as failed
- **AND** message is broadcast

#### Scenario: Request smoke
- **WHEN** player requests smoke on drop zone
- **THEN** smoke is deployed at friendly position

### Requirement: ADF Navigation
The system SHALL provide radio navigation to the drop zone.

#### Scenario: ADF beacon
- **WHEN** transport mission is active
- **THEN** an ADF beacon transmits from the drop zone
- **AND** players can home in on the signal
