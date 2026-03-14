# Capability: Radio Menu System (Runtime)

## Purpose

Dynamic F10 radio menu management for VEAF commands and features during DCS mission runtime.

## Requirements

### Requirement: Build Radio Menus
The system SHALL create hierarchical F10 radio menus for all VEAF features.

#### Scenario: Initialize radio menus
- **WHEN** the mission starts and VEAF initializes
- **THEN** radio menus are created under F10 → Other
- **AND** menus are organized by module (SPAWN, ASSETS, CAS, etc.)

#### Scenario: Rebuild on player spawn
- **WHEN** a new human player spawns into the mission
- **THEN** radio menus are refreshed to include the new player
- **AND** group-specific menus are available

### Requirement: Menu Scoping
The system SHALL support different menu visibility scopes.

#### Scenario: Menu for all players
- **WHEN** a menu item uses `USAGE_ForAll`
- **THEN** all players see and can use the menu item

#### Scenario: Menu for group only
- **WHEN** a menu item uses `USAGE_ForGroup`
- **THEN** only players in the same group can use it

#### Scenario: Menu for unit only
- **WHEN** a menu item uses `USAGE_ForUnit`
- **THEN** only the specific unit's player can use it

### Requirement: Secured Commands
The system SHALL support commands requiring authentication.

#### Scenario: Secured menu item
- **WHEN** a secured command is invoked
- **AND** the player is not authenticated
- **THEN** the command is blocked with a security message

### Requirement: Paginated Menus
The system SHALL support pagination for large menu lists.

#### Scenario: Paginate long menu
- **WHEN** a menu has more items than the DCS limit
- **THEN** items are split across multiple pages
- **AND** navigation commands allow browsing pages

### Requirement: Marker Commands
The system SHALL execute commands from map marker text via `_radio` keyword.

#### Scenario: Radio command via marker
- **WHEN** player places marker with `_radio transmit message=Hello freq=251`
- **THEN** the system processes the radio command
- **AND** the marker is removed after processing

### Requirement: SRS Integration
The system SHALL support transmitting messages via SRS (SimpleRadioStandalone).

#### Scenario: Transmit radio message
- **WHEN** a radio transmission is triggered
- **THEN** the message is sent via SRS on specified frequencies
- **AND** modulation (AM/FM) is applied correctly
