# Capability: Unit Movement (Runtime)

## Purpose

Move and redirect units including ground convoys and tanker aircraft during DCS mission runtime.

## Requirements

### Requirement: Move Ground Units
The system SHALL move ground groups to marker locations via `_move` command.

#### Scenario: Move convoy
- **WHEN** player places marker with `_move groupname`
- **THEN** the named ground group begins moving to the marker location
- **AND** movement uses road/off-road routing as appropriate

#### Scenario: Move with speed
- **WHEN** player specifies `_move groupname, speed 50`
- **THEN** the group moves at approximately 50 km/h

### Requirement: Redirect Tankers
The system SHALL create new flight plans for tanker aircraft.

#### Scenario: Move tanker
- **WHEN** player places marker with `_move tanker Texaco`
- **THEN** Texaco tanker establishes new orbit pattern at marker location
- **AND** altitude and speed are set based on requesting aircraft type

#### Scenario: Tanker for aircraft type
- **WHEN** player in F-16 requests tanker relocation
- **THEN** tanker orbit parameters match F-16 refueling requirements
- **AND** altitude is set to 22000ft, speed to 400kts

### Requirement: Track Moving Tankers
The system SHALL track tankers with modified orbits.

#### Scenario: Tanker registry
- **WHEN** a tanker is relocated
- **THEN** its new orbit is registered
- **AND** subsequent move requests update the orbit

### Requirement: Marker Cleanup
The system SHALL remove processed movement markers.

#### Scenario: Remove marker
- **WHEN** a move command is successfully processed
- **THEN** the map marker is deleted
