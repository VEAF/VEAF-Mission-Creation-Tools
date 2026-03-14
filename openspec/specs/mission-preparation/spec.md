# Capability: Mission Folder Preparation

## Purpose

Initialize and prepare mission folders with default files and build scripts for new VEAF missions.

## Requirements

### Requirement: Initialize Mission Folder
The system SHALL create a properly structured mission folder with all required default files.

#### Scenario: Prepare new folder
- **WHEN** user runs `veaf-tools prepare ./my-new-mission`
- **THEN** the system creates the folder structure:
  ```
  my-new-mission/
  ├── src/
  │   ├── mission          # Lua mission table template
  │   ├── options          # Default options
  │   └── scripts/         # Mission-specific scripts
  ├── published/           # Placeholder for VEAF scripts
  └── build.cmd            # Build script
  ```
- **AND** copies default configuration files

#### Scenario: Folder already exists
- **WHEN** target folder already contains files
- **AND** `--force` is not specified
- **THEN** the system prompts before overwriting each existing file
- **AND** user can choose to skip or replace

#### Scenario: Force overwrite
- **WHEN** user runs `veaf-tools prepare --force ./existing-folder`
- **THEN** existing files are replaced without prompting

### Requirement: Copy Build Scripts
The system SHALL install build automation scripts.

#### Scenario: Install build scripts
- **WHEN** mission folder is prepared
- **THEN** build scripts are copied:
  - `build.cmd` (Windows batch)
  - `build.sh` (Unix shell, if available)
- **AND** scripts are configured for the local folder structure

### Requirement: Copy Default Source Files
The system SHALL install template source files for a minimal working mission.

#### Scenario: Install default sources
- **WHEN** mission folder is prepared
- **THEN** default Lua templates are installed in `src/`:
  - `mission` - Minimal mission structure
  - `options` - Default game options
  - `warehouses` - Empty warehouse configuration
- **AND** templates are ready for customization
