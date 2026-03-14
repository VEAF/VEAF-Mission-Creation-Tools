# Capability: QRA Manager (Runtime)

## Purpose

Manage Quick Reaction Alert (QRA) interceptor flights that defend zones against enemy intrusion during DCS mission runtime.

## Requirements

### Requirement: Define QRA Zones
The system SHALL support definition of QRA-defended zones.

#### Scenario: Create QRA zone
- **WHEN** a VeafQRA is configured with zone and defender groups
- **THEN** the zone monitors for enemy aircraft entry
- **AND** QRA is ready to scramble

#### Scenario: Multiple defender groups
- **WHEN** QRA defines multiple aircraft groups
- **THEN** groups can be configured to scramble based on threat quantity

### Requirement: Detect Zone Intrusion
The system SHALL detect when enemy aircraft enter a QRA zone.

#### Scenario: Enemy enters zone
- **WHEN** an enemy aircraft enters the QRA zone
- **THEN** the system detects the intrusion
- **AND** begins QRA response sequence

#### Scenario: Helicopter filtering
- **WHEN** `reactOnHelicopters = false`
- **THEN** helicopters entering the zone do not trigger QRA

### Requirement: Scramble QRA
The system SHALL spawn and direct QRA interceptors.

#### Scenario: Scramble defenders
- **WHEN** intrusion is detected
- **AND** QRA status is READY
- **THEN** defender aircraft spawn and engage
- **AND** status changes to ACTIVE

#### Scenario: Delayed activation
- **WHEN** `delayBeforeActivating` is set
- **THEN** QRA waits specified seconds before spawning

### Requirement: Track QRA Status
The system SHALL track QRA lifecycle status.

#### Scenario: QRA destroyed
- **WHEN** all QRA defenders are destroyed
- **THEN** status changes to DEAD
- **AND** notification is broadcast

#### Scenario: QRA rearming
- **WHEN** enemies leave the zone
- **AND** `delayBeforeRearming` is configured
- **THEN** QRA rearms after the delay
- **AND** status returns to READY

### Requirement: Airbase Dependencies
The system SHALL track airbase status for QRA operations.

#### Scenario: Airbase destroyed
- **WHEN** the QRA's home airbase is damaged below threshold
- **THEN** QRA operations cease
- **AND** "airbase down" message is broadcast

#### Scenario: Airbase recovered
- **WHEN** airbase is repaired
- **THEN** QRA operations can resume

### Requirement: Messages and Events
The system SHALL support customizable messages and event callbacks.

#### Scenario: Custom messages
- **WHEN** QRA events occur (start, deploy, destroyed, ready)
- **THEN** configured messages are broadcast (unless silent mode)

#### Scenario: Event callbacks
- **WHEN** an event callback (onDeploy, onDestroyed, etc.) is configured
- **THEN** the callback function is invoked on that event
