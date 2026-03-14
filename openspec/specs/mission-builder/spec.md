# Capability: Mission Builder

## Purpose

Build DCS World mission files (.miz) from a structured mission folder containing source files.

## Requirements

### Requirement: Build Mission from Folder
The system SHALL create a complete DCS mission file (.miz) from a structured mission folder containing:
- Mission source files (Lua tables: mission, options, warehouses, etc.)
- VEAF scripts (compiled Lua modules)
- Community scripts (MIST, Skynet IADS, etc.)
- Mission-specific data files

#### Scenario: Build standard mission
- **WHEN** user runs `veaf-tools build MyMission ./mission-folder`
- **THEN** the system collects all required files from the mission folder
- **AND** injects VEAF triggers into the mission
- **AND** creates `MyMission_YYYYMMDD.miz` output file

#### Scenario: Build with dynamic mode
- **WHEN** user runs `veaf-tools build --dynamic-mode MyMission ./mission-folder`
- **THEN** the system configures the mission to load scripts dynamically at runtime
- **AND** scripts are loaded from the `published/` folder during DCS mission execution

#### Scenario: Build with scripts variant
- **WHEN** user runs `veaf-tools build --scripts-variant debug MyMission`
- **THEN** the system uses `veaf-scripts-debug.lua` instead of `veaf-scripts.lua`
- **AND** the output filename includes the variant suffix: `MyMission_debug_YYYYMMDD.miz`

### Requirement: Migrate from V5 Format
The system SHALL detect and migrate old V5 trigger patterns from existing missions.

#### Scenario: Remove legacy V5 triggers
- **WHEN** user builds a mission containing V5 VEAF triggers
- **AND** `--migrate-from-v5` is enabled (default)
- **THEN** the system removes obsolete V5 trigger structures
- **AND** replaces them with V6 equivalent triggers

### Requirement: Validate Mission Structure
The system SHALL validate that all required mission components are present.

#### Scenario: Missing mandatory component
- **WHEN** user attempts to build a mission with missing `mission` Lua file
- **THEN** the system displays an error listing the missing component
- **AND** the build process aborts

#### Scenario: Missing optional component
- **WHEN** user builds a mission with missing `options` file
- **THEN** the system displays a warning
- **AND** the build process continues

### Requirement: Inject VEAF Triggers
The system SHALL inject standard VEAF script loading triggers into the mission.

#### Scenario: Standard trigger injection
- **WHEN** user builds a mission without `--no-veaf-triggers`
- **THEN** the system adds triggers that load VEAF scripts at mission start
- **AND** triggers execute in the correct order (veaf.lua first, then modules)

#### Scenario: Skip trigger injection
- **WHEN** user runs `veaf-tools build --no-veaf-triggers MyMission`
- **THEN** no VEAF loading triggers are added to the mission
