# Capability: Asset Management (Runtime)

## Purpose

Manage important mission assets (tankers, AWACS, carriers) with respawn capabilities and status tracking during DCS mission runtime.

## Requirements

### Requirement: Register Assets
The system SHALL maintain a registry of important mission assets.

#### Scenario: Define tanker asset
- **WHEN** mission configuration defines a tanker with name, description, and information
- **THEN** the asset appears in the ASSETS radio menu
- **AND** players can interact with it

### Requirement: Respawn Assets
The system SHALL respawn destroyed or disposed assets on demand.

#### Scenario: Respawn tanker
- **WHEN** player selects "Respawn Texaco" from radio menu
- **THEN** the tanker group respawns at its initial position
- **AND** resumes its original flight plan

#### Scenario: Respawn linked groups
- **WHEN** an asset has linked escort groups
- **AND** the asset is respawned
- **THEN** the linked groups also respawn

### Requirement: Asset Information
The system SHALL provide status information about assets.

#### Scenario: Get asset info
- **WHEN** player requests info on an asset
- **THEN** status is displayed (alive units, frequencies, etc.)
- **AND** TACAN, radio, and other operational info is shown

### Requirement: Dispose Assets
The system SHALL allow disposal of unneeded assets.

#### Scenario: Dispose asset
- **WHEN** authorized player disposes of an asset
- **THEN** all units in the asset group are destroyed
- **AND** confirmation message is displayed

### Requirement: Disposable Flag
The system SHALL distinguish between disposable and permanent assets.

#### Scenario: Non-disposable asset
- **WHEN** an asset is marked as non-disposable
- **THEN** the "Dispose" option is not available in the menu
