# Capability: Named Points (Runtime)

## Purpose

Manage named reference points with ATC services and coordinate lookups during DCS mission runtime.

## Requirements

### Requirement: Create Named Points
The system SHALL allow creation of named reference points via map markers.

#### Scenario: Name a point
- **WHEN** player places marker with `_name point MyWaypoint`
- **THEN** a named point "MyWaypoint" is registered at that location
- **AND** the marker is removed after processing

### Requirement: List Named Points
The system SHALL provide a radio menu listing all named points.

#### Scenario: Browse named points
- **WHEN** player opens NAMED POINTS radio menu
- **THEN** all registered points are listed
- **AND** player can select a point for more options

### Requirement: Get Point Coordinates
The system SHALL provide coordinates for named points in multiple formats.

#### Scenario: Get coordinates
- **WHEN** player requests coordinates for a named point
- **THEN** position is displayed in LL, MGRS, and other formats
- **AND** bearing and distance from current position are shown

### Requirement: ATC Weather Services
The system SHALL provide weather information at named points.

#### Scenario: Get ATIS
- **WHEN** player requests weather at a named point
- **THEN** wind, temperature, pressure, and cloud information are displayed
- **AND** QFE/QNH altimeter settings are provided

### Requirement: Mark Named Points
The system SHALL support marking named points with smoke and flares.

#### Scenario: Pop smoke
- **WHEN** player requests smoke on a named point
- **THEN** colored smoke is deployed at the point location

### Requirement: Predefined Named Points
The system SHALL support loading predefined named points from mission configuration.

#### Scenario: Load mission points
- **WHEN** mission defines `veafNamedPoints.addCity()` or similar
- **THEN** those points are available in the radio menu
- **AND** points include cities, airports, and strategic locations
