# Capability: Unit Spawning (Runtime)

## Purpose

Dynamic spawning of units, groups, convoys, and objects via F10 map markers or radio commands during DCS mission runtime.

## Requirements

### Requirement: Spawn Units via Map Markers
The system SHALL spawn units when a player places a map marker with the `_spawn` keyword.

#### Scenario: Spawn ground unit
- **WHEN** player places marker with text `_spawn infantry`
- **THEN** an infantry group spawns at the marker location
- **AND** the marker is removed after processing

#### Scenario: Spawn with parameters
- **WHEN** player places marker with `_spawn armor, defense 3, size 8`
- **THEN** an armor group spawns with specified defense level and size
- **AND** group composition matches the parameters

### Requirement: Spawn Aircraft Templates
The system SHALL spawn predefined aircraft group templates.

#### Scenario: Spawn from template
- **WHEN** player triggers spawn of template "veafSpawn-F16-CAP"
- **THEN** the predefined F-16 CAP flight spawns
- **AND** aircraft follow their configured route and behavior

#### Scenario: Spawn AFAC
- **WHEN** player requests AFAC spawn via radio menu
- **THEN** an AFAC aircraft spawns with unique callsign and frequency
- **AND** frequency is reported to the player

### Requirement: Spawn Convoys
The system SHALL create moving convoys of ground units.

#### Scenario: Create convoy
- **WHEN** player spawns a convoy with destination
- **THEN** a ground group spawns and moves toward the destination
- **AND** convoy progress can be tracked

### Requirement: Destroy Units
The system SHALL destroy spawned groups via the `_destroy` command.

#### Scenario: Destroy group
- **WHEN** player places marker with `_destroy groupname`
- **THEN** the named group is removed from the mission
- **AND** confirmation message is displayed

### Requirement: Teleport Units
The system SHALL teleport existing groups to new locations via `_teleport` command.

#### Scenario: Teleport group
- **WHEN** player places marker with `_teleport groupname`
- **THEN** the named group moves instantly to the marker location

### Requirement: Artillery and Illumination
The system SHALL provide shelling and illumination capabilities.

#### Scenario: Request artillery
- **WHEN** player requests shelling at a location
- **THEN** artillery shells impact the target area at intervals
- **AND** shelling continues for the specified duration

#### Scenario: Request illumination
- **WHEN** player requests illumination flares
- **THEN** flares are deployed at altitude above the target
- **AND** flares illuminate the area for a configurable duration

### Requirement: Cargo Spawning
The system SHALL spawn cargo objects for helicopter transport missions.

#### Scenario: Spawn cargo
- **WHEN** player spawns cargo at a location
- **THEN** a cargo crate object appears
- **AND** cargo can be picked up by helicopters

### Requirement: Logistic Units
The system SHALL spawn logistic support objects (ammo, fuel).

#### Scenario: Spawn logistics
- **WHEN** player spawns logistic unit
- **THEN** FARP-style supply point appears
- **AND** nearby units can rearm/refuel
