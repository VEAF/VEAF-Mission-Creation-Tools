# Capability: VEAF Core Framework (Runtime)

## Purpose

Core Lua framework providing constants, utilities, logging, and event handling that all other VEAF modules depend on. Executes within DCS World mission runtime.

## Requirements

### Requirement: Module Initialization
The system SHALL provide a central initialization point for all VEAF modules.

#### Scenario: Initialize VEAF framework
- **WHEN** the mission starts
- **THEN** `veaf.lua` loads first and initializes core utilities
- **AND** exposes the `veaf` global table to all subsequent modules
- **AND** sets up the logging system

### Requirement: Logging System
The system SHALL provide a centralized logging facility for all VEAF modules.

#### Scenario: Create module logger
- **WHEN** a module calls `veaf.loggers.new("SPAWN", logLevel)`
- **THEN** a logger instance is created for that module
- **AND** log output is prefixed with the module identifier

#### Scenario: Log levels
- **WHEN** `veaf.LogLevel` is set to "trace", "debug", "info", "warning", or "error"
- **THEN** only messages at that level or above are output
- **AND** output appears in DCS.log file

### Requirement: Theatre Constants
The system SHALL provide constants for all supported DCS maps/theatres.

#### Scenario: Theatre identification
- **WHEN** a module needs to determine the current map
- **THEN** it can use `veaf.theatreName` constants (Caucasus, Nevada, Syria, etc.)
- **AND** map-specific logic can be applied

### Requirement: Era Configuration
The system SHALL support configuration for different combat eras.

#### Scenario: Set mission era
- **WHEN** `veaf.config.era` is set to `veaf.ERA.WW2`, `veaf.ERA.COLD_WAR`, or `veaf.ERA.MODERN`
- **THEN** spawned units are filtered to match the configured era
- **AND** era-appropriate equipment is used

### Requirement: Event Handling
The system SHALL provide event handling utilities for DCS world events.

#### Scenario: Process DCS events
- **WHEN** a DCS event occurs (shot, hit, takeoff, land, crash, etc.)
- **THEN** the event metadata is available via `veaf.EVENTMETA`
- **AND** modules can register handlers for specific events

### Requirement: Utility Functions
The system SHALL provide common utility functions for coordinate conversion, distance calculation, and string manipulation.

#### Scenario: Coordinate conversion
- **WHEN** a module needs to convert between coordinate formats
- **THEN** utilities are available for LL to vec3, MGRS conversion, etc.

#### Scenario: Distance calculation
- **WHEN** a module needs to calculate distance between two points
- **THEN** `veaf.distance()` provides accurate results in meters
