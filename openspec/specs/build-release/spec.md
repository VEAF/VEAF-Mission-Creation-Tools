# Capability: Build and Release Pipeline

## Purpose

Automated build, packaging, and release of VEAF Mission Creation Tools to GitHub.

## Requirements

### Requirement: Compile Lua Scripts
The system SHALL compile all Lua modules into distribution-ready script bundles.

#### Scenario: Compile standard scripts
- **WHEN** user runs `python build-and-release.py build --version 6.0.5`
- **THEN** the system compiles `src/scripts/veaf/*.lua` modules
- **AND** creates `veaf-scripts.lua` (standard variant)
- **AND** creates `veaf-scripts-debug.lua` (with debug logging)
- **AND** creates `veaf-scripts-trace.lua` (with trace logging)

### Requirement: Compile Python Executables
The system SHALL compile Python tools into standalone executables using PyInstaller.

#### Scenario: Build executables
- **WHEN** user runs `python build-and-release.py build --version 6.0.5`
- **THEN** the system compiles `veaf-tools.py` → `veaf-tools.exe`
- **AND** compiles `veaf-tools-updater.py` → `veaf-tools-updater.exe`
- **AND** executables run without Python installation

### Requirement: Create Release Package
The system SHALL create a distributable ZIP package containing all release artifacts.

#### Scenario: Create package
- **WHEN** build completes successfully
- **THEN** the system creates `published.zip` containing:
  - Compiled Lua scripts
  - Python executables
  - Default configuration files
  - Documentation (README, LICENSE)
- **AND** calculates SHA256 checksum for integrity verification

### Requirement: Publish to GitHub
The system SHALL automate GitHub release creation and asset upload.

#### Scenario: Publish new release
- **WHEN** user runs `python build-and-release.py publish --version 6.0.5`
- **AND** `GITHUB_TOKEN` environment variable is set
- **THEN** the system creates git tag `published-v6.0.5`
- **AND** creates GitHub Release with release notes from `RELEASE_NOTES.md`
- **AND** uploads `published.zip` as release asset
- **AND** updates `published-latest` tag to point to this release

#### Scenario: Missing GitHub token
- **WHEN** user attempts to publish without `GITHUB_TOKEN`
- **THEN** the system displays an error message
- **AND** publish operation aborts

### Requirement: Version Management
The system SHALL validate and manage version numbers consistently.

#### Scenario: Version validation
- **WHEN** user specifies `--version 6.0.5`
- **THEN** the system validates the version follows semantic versioning
- **AND** updates `package.json` with the new version
- **AND** tags reflect the specified version

#### Scenario: Version mismatch
- **WHEN** specified version differs from `package.json`
- **THEN** the system warns about the mismatch
- **AND** uses the command-line specified version

### Requirement: Build Validation
The system SHALL validate prerequisites before starting the build.

#### Scenario: Validate prerequisites
- **WHEN** build starts
- **THEN** the system checks for Git, Python 3.9+, PyInstaller
- **AND** reports any missing prerequisites
- **AND** aborts if critical tools are missing
