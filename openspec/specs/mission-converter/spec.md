# Capability: Mission Converter

## Purpose

Convert existing DCS missions to VEAF-enabled missions in a single operation (extract + build).

## Requirements

### Requirement: Convert Legacy Mission
The system SHALL convert a non-VEAF mission into a VEAF-enabled mission by extracting and rebuilding with VEAF scripts.

#### Scenario: Convert standard DCS mission
- **WHEN** user runs `veaf-tools convert MyMission ./mission-folder`
- **THEN** the system extracts the mission to `./mission-folder/src/`
- **AND** rebuilds it with VEAF scripts and triggers
- **AND** creates `MyMission_YYYYMMDD.miz` output file

#### Scenario: Convert with scripts variant
- **WHEN** user runs `veaf-tools convert --scripts-variant trace MyMission`
- **THEN** the converted mission uses the trace variant
- **AND** output filename is `MyMission_trace_YYYYMMDD.miz`

### Requirement: Support Dynamic Mode Conversion
The system SHALL support converting missions to dynamic script loading mode.

#### Scenario: Convert to dynamic mode
- **WHEN** user runs `veaf-tools convert --dynamic-mode MyMission ./mission-folder`
- **THEN** the converted mission loads scripts dynamically at runtime
- **AND** requires `published/` folder alongside the mission file
