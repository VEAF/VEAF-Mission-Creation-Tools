# Capability: CAS Mission Generator (Runtime)

## Purpose

Generate Close Air Support training scenarios dynamically via map markers during DCS mission runtime.

## Requirements

### Requirement: Create CAS Target Groups
The system SHALL create CAS target groups via the `_cas` marker command.

#### Scenario: Basic CAS mission
- **WHEN** player places marker with `_cas`
- **THEN** a ground target group spawns at the location
- **AND** group includes a mix of vehicles and defenses

#### Scenario: CAS with defense level
- **WHEN** player places marker with `_cas, defense 4`
- **THEN** target group includes SAM/AAA based on defense level
- **AND** higher levels include more capable air defense

#### Scenario: CAS with size parameter
- **WHEN** player places marker with `_cas, size 12`
- **THEN** target group contains approximately 12 units

### Requirement: Era-Appropriate Units
The system SHALL spawn units appropriate to the configured era.

#### Scenario: Modern era CAS
- **WHEN** `veaf.config.era` is `MODERN`
- **THEN** targets include modern vehicles (T-90, BMP-3, etc.)
- **AND** defenses include modern SAMs

#### Scenario: Cold War era CAS
- **WHEN** `veaf.config.era` is `COLD_WAR`
- **THEN** targets include period-appropriate vehicles (T-55, BMP-1, etc.)

### Requirement: Target Marking
The system SHALL provide smoke and flare marking for CAS targets.

#### Scenario: Request smoke
- **WHEN** player requests smoke on CAS target via radio menu
- **THEN** red smoke is deployed on target position
- **AND** smoke persists for configurable duration

#### Scenario: Request illumination
- **WHEN** player requests illumination on CAS target
- **THEN** flares are deployed above the target area

### Requirement: Mission Watchdog
The system SHALL monitor CAS missions and report completion.

#### Scenario: CAS mission complete
- **WHEN** all CAS target units are destroyed
- **THEN** a completion message is broadcast
- **AND** the mission can be reset for replay

### Requirement: AFAC Support
The system SHALL optionally spawn AFAC aircraft for CAS coordination.

#### Scenario: CAS with AFAC
- **WHEN** player creates CAS mission with AFAC option
- **THEN** an AFAC aircraft spawns and orbits the target area
- **AND** AFAC frequency is announced
