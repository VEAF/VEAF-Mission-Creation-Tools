# Capability: Security System (Runtime)

## Purpose

Provide authentication and authorization for sensitive VEAF commands during DCS mission runtime.

## Requirements

### Requirement: Password Authentication
The system SHALL support password-based authentication via map markers.

#### Scenario: Authenticate with password
- **WHEN** player places marker with `_auth <password>`
- **THEN** if password is valid, player is authenticated
- **AND** authentication lasts for configurable duration

#### Scenario: Invalid password
- **WHEN** player provides invalid password
- **THEN** authentication fails
- **AND** no elevated access is granted

### Requirement: Security Levels
The system SHALL support multiple security levels.

#### Scenario: Level 0 (highest)
- **WHEN** player authenticates with L0 password
- **THEN** all secured commands are available
- **AND** `veafSecurity.LEVEL_L0 = 90` priority applies

#### Scenario: Level 1 (standard)
- **WHEN** player authenticates with L1 password
- **THEN** standard secured commands are available
- **AND** most sensitive commands remain restricted

#### Scenario: Level 9 (minimal)
- **WHEN** player authenticates with L9 password
- **THEN** only basic secured commands are available

### Requirement: Secured Commands
The system SHALL restrict command execution based on authentication.

#### Scenario: Execute secured command
- **WHEN** an authenticated player invokes a secured command
- **THEN** the command executes normally

#### Scenario: Block unauthenticated
- **WHEN** an unauthenticated player invokes a secured command
- **THEN** the command is blocked
- **AND** a security warning is displayed

### Requirement: SHA-1 Password Hashing
The system SHALL store passwords as SHA-1 hashes.

#### Scenario: Password verification
- **WHEN** a password is submitted
- **THEN** it is hashed with SHA-1
- **AND** compared against stored hashes

### Requirement: Development Mode
The system SHALL support disabling security for development.

#### Scenario: Security disabled
- **WHEN** `veaf.SecurityDisabled = true`
- **THEN** all commands execute without authentication
- **AND** this is intended only for development missions
