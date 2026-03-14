# Capability: Combat Zones (Runtime)

## Purpose

Define and manage combat zones with dynamic unit spawning, briefings, and completion tracking during DCS mission runtime.

## Requirements

### Requirement: Define Combat Zones
The system SHALL support definition of combat zones from mission editor trigger zones.

#### Scenario: Create zone from trigger
- **WHEN** a trigger zone named "ZONE-CombatArea" exists
- **THEN** a combat zone is registered with that name
- **AND** zone boundaries match the trigger zone

#### Scenario: Zone with elements
- **WHEN** a combat zone defines units, statics, and VEAF commands
- **THEN** these elements are spawned when the zone activates

### Requirement: Activate/Deactivate Zones
The system SHALL support activation and deactivation of combat zones.

#### Scenario: Activate zone
- **WHEN** player activates a combat zone via radio menu
- **THEN** all zone elements spawn (enemies, objectives)
- **AND** watchdog monitoring begins

#### Scenario: Deactivate zone
- **WHEN** player deactivates a combat zone
- **THEN** all spawned zone elements are removed
- **AND** zone can be reactivated later

### Requirement: Zone Briefing
The system SHALL provide briefings for combat zones.

#### Scenario: Read briefing
- **WHEN** player requests zone briefing
- **THEN** zone description, objectives, and threats are displayed

### Requirement: Zone Status
The system SHALL track and report combat zone status.

#### Scenario: Get zone info
- **WHEN** player requests zone status
- **THEN** enemy presence, completion percentage, and coordinates are shown

#### Scenario: Zone completion
- **WHEN** all enemy units in a zone are destroyed
- **THEN** completion message is broadcast
- **AND** zone automatically deactivates

### Requirement: Target Marking
The system SHALL support smoke and flare marking in zones.

#### Scenario: Pop smoke
- **WHEN** player requests smoke on a combat zone
- **THEN** smoke is deployed at the zone center

### Requirement: Spawn Randomization
The system SHALL support randomized spawning with chance percentages.

#### Scenario: Spawn with chance
- **WHEN** a zone element has `spawnChance = 50`
- **THEN** the element has 50% chance of spawning on activation
- **AND** each activation may produce different compositions
