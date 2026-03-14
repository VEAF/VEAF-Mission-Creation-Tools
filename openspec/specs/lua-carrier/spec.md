# Capability: Carrier Operations (Runtime)

## Purpose

Manage aircraft carrier flight operations including wind alignment and ATC services during DCS mission runtime.

## Requirements

### Requirement: Start Carrier Operations
The system SHALL enable carrier flight operations via radio menu.

#### Scenario: Begin operations
- **WHEN** player selects "Start operations" for a carrier
- **THEN** carrier turns into the wind for optimal flight operations
- **AND** carrier speed adjusts to achieve desired wind-over-deck

#### Scenario: Specify duration
- **WHEN** player starts operations with duration parameter
- **THEN** operations automatically end after specified minutes
- **AND** carrier returns to original position

### Requirement: Wind Alignment
The system SHALL calculate and achieve proper BRC (Base Recovery Course).

#### Scenario: Calculate heading
- **WHEN** operations start
- **THEN** carrier heading is calculated based on wind direction
- **AND** angled deck offset is accounted for (varies by carrier type)

#### Scenario: Low wind conditions
- **WHEN** wind speed is below minimum threshold
- **THEN** carrier steams at higher speed to generate wind-over-deck
- **AND** final heading accounts for carrier-generated wind

### Requirement: ATC Information
The system SHALL provide carrier ATC information to pilots.

#### Scenario: Get ATC info
- **WHEN** player requests carrier ATC info
- **THEN** BRC, wind speed/direction, and deck conditions are reported
- **AND** TACAN and radio frequencies are provided

### Requirement: End Operations
The system SHALL return carrier to initial position when operations end.

#### Scenario: End operations manually
- **WHEN** player selects "End operations"
- **THEN** carrier turns to return to original position
- **AND** radio menu updates to show "Start operations"

#### Scenario: Operations timeout
- **WHEN** operation duration expires
- **THEN** operations end automatically
- **AND** notification is broadcast

### Requirement: Support Ship Management
The system SHALL manage associated support ships.

#### Scenario: Pedro rescue helicopter
- **WHEN** carrier operations are active
- **THEN** Pedro SAR helicopter is available
- **AND** helicopter can be respawned if lost

#### Scenario: Emergency tanker
- **WHEN** carrier operations are active
- **THEN** S-3B tanker orbit can be established
- **AND** tanker route follows carrier position
