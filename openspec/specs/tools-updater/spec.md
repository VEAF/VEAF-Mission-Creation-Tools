# Capability: Tools Updater

## Purpose

Self-update mechanism for mission makers to download and install the latest VEAF tools.

## Requirements

### Requirement: Check for Updates
The system SHALL check GitHub for newer versions of the VEAF tools.

#### Scenario: Check latest version
- **WHEN** user runs `veaf-tools-updater.exe check`
- **THEN** the system queries GitHub API for `published-latest` release
- **AND** compares with locally installed version
- **AND** displays whether an update is available

#### Scenario: No internet connection
- **WHEN** GitHub API is unreachable
- **THEN** the system displays a connection error
- **AND** suggests checking internet connectivity

### Requirement: Download and Install Updates
The system SHALL download and install the latest release package.

#### Scenario: Update to latest version
- **WHEN** user runs `veaf-tools-updater.exe update`
- **THEN** the system downloads `published.zip` from GitHub
- **AND** verifies SHA256 checksum
- **AND** extracts files to the installation directory
- **AND** reports successful update

#### Scenario: Checksum verification failure
- **WHEN** downloaded file checksum doesn't match
- **THEN** the system displays an integrity error
- **AND** deletes the corrupted download
- **AND** suggests retrying the update

### Requirement: Update to Specific Version
The system SHALL support updating to a specific version instead of latest.

#### Scenario: Install specific version
- **WHEN** user runs `veaf-tools-updater.exe update --version 6.0.3`
- **THEN** the system downloads release `published-v6.0.3`
- **AND** installs that specific version

#### Scenario: Version not found
- **WHEN** user specifies a non-existent version
- **THEN** the system displays an error listing available versions
- **AND** no changes are made

### Requirement: Preserve Local Configuration
The system SHALL preserve user configuration files during updates.

#### Scenario: Keep local presets
- **WHEN** user has customized `presets.yaml`
- **AND** an update is performed
- **THEN** the local `presets.yaml` is not overwritten
- **AND** new default files are installed alongside

### Requirement: Self-Update Capability
The system SHALL be able to update itself (the updater executable).

#### Scenario: Updater self-update
- **WHEN** a new version of `veaf-tools-updater.exe` is available
- **THEN** the system downloads the new updater
- **AND** replaces itself using a bootstrap mechanism
- **AND** continues the update process with the new version
