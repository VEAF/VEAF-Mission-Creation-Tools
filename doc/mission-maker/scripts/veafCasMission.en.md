# veafCasMission — CAS Training Generator


**Module ID:** `CASMISSION` | **Version:** 1.15.x | **File:** `veafCasMission.lua`

---

## Purpose

Generates on-demand Close Air Support training zones with configurable size, armour, and air defence threat packages. Players can create, mark, skip, and clean up CAS targets from the F10 menu or via map marker commands.

---

## Dependencies

- `veafMarkers` — marker command handling
- `veafRadio` — F10 menu
- `veafSpawn` — unit spawning backend

---

## Enable

```lua
veafCasMission.initialize()
veafCasMission.start()
```

`start()` activates the watchdog that monitors the CAS group.

> **Enabled by default** in the shipped `mission.yaml`. It is marker-driven (`_cas`) and needs no configuration — just place a `_cas` marker. The block below is only needed to tune it.

---

## Configuration (`mission.yaml`)

`veafCasMission` itself has no YAML-configurable fields. However, **CAP missions** and **Combat missions** (managed by the `COMBATMISSION` module) are declared in top-level `mission.yaml` sections.

```yaml
modules:
  CASMISSION:
    enabled: true          # default: true
    logLevel: info        # optional log level override
  COMBATMISSION:
    enabled: true          # required for cap_missions: and combat_missions:

# ── CAP missions ──────────────────────────────────────────────────────────
cap_missions:
  - group_name: "CAP Group"       # REQUIRED — DCS group name to use for the CAP
    menu_name: "CAP North"        # label in the F10 menu
    briefing: "Patrol the northern sector and engage threats."
    default: false                # true = starts active by default
    activated: true               # true = immediately activated at mission start

# ── Combat missions ───────────────────────────────────────────────────────
combat_missions:
  - name: "Strike-Alpha"          # REQUIRED — internal identifier
    friendly_name: "Strike Alpha" # label in the F10 menu
    secured: false                # true = requires /secu to activate
    radio_menu_enabled: true      # show in F10 menu
    briefing: |
      Destroy the armoured column in grid BQ-123.
      Expect AAA and MANPADS.
    elements:
      - name: "Element Alpha 1"   # internal element name
        groups:                   # DCS group names included in this element
          - "STRIKE-GROUP-1"
          - "STRIKE-GROUP-2"
        scalable: true            # true = group count scales with skill setting
```

### `cap_missions[]` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `group_name` | string | — | Yes | DCS group name for the CAP flight |
| `menu_name` | string | — | No | F10 menu label |
| `briefing` | string | — | No | Briefing text shown to players |
| `default` | boolean | `false` | No | Start as the default active mission |
| `activated` | boolean | `true` | No | Immediately activate at mission start |

### `combat_missions[]` fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier |
| `friendly_name` | string | — | No | F10 menu label |
| `secured` | boolean | `false` | No | Requires `/secu` security token to activate |
| `radio_menu_enabled` | boolean | `true` | No | Show this mission in the F10 menu |
| `briefing` | string | — | No | Multi-line briefing text |
| `elements` | object[] | `[]` | No | Mission element definitions |
| `elements[].name` | string | — | No | Element internal name |
| `elements[].groups` | string[] | — | No | DCS group names in this element |
| `elements[].scalable` | boolean | `true` | No | Scale group count with difficulty |

### Minimal example

```yaml
modules:
  COMBATMISSION:
    enabled: true

cap_missions:
  - group_name: "CAP-Alpha"
    menu_name: "CAP"

combat_missions:
  - name: "Strike-North"
    briefing: "Destroy northern targets."
    elements:
      - groups: ["Strike-Group-1"]
```

---

## Key Configuration Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafCasMission.Keyphrase` | `"_cas"` | Marker trigger text |
| `veafCasMission.SecondsBetweenWatchdogChecks` | `15` | Watchdog interval (s) |
| `veafCasMission.SecondsBetweenSmokeRequests` | `180` | Smoke cooldown (s) |
| `veafCasMission.SecondsBetweenFlareRequests` | `120` | Flare cooldown (s) |
| `veafCasMission.RedCasGroupName` | `"Red CAS Group"` | DCS group name for red CAS units |
| `veafCasMission.BlueCasGroupName` | `"Blue CAS Group"` | DCS group name for blue CAS units |
| `veafCasMission.RadioMenuName` | `"CAS MISSION"` | F10 submenu label |

---

## Marker Commands (Player-Facing)

```
_cas
_cas, size 3, defense 2, armor 3
_cas, side blue
```

Options:

| Option | Range | Description |
|--------|-------|-------------|
| `size` | 0–5 | Number of target units |
| `defense` | 0–5 | AA defence level (0=none, 5=heavy SAM) |
| `armor` | 0–5 | Armour level (0=infantry, 5=heavy MBT) |
| `side` | blue/red | Coalition of targets |

---

## F10 Radio Menu

- **Generate** — create a new CAS zone at a random or specified location
- **Smoke** — mark zone with coloured smoke (3-minute cooldown)
- **Flare** — mark zone with illumination flares (2-minute cooldown)
- **Info** — display zone position, composition, and status
- **Skip** — abandon current zone and generate a new one
- **Cleanup** — destroy all CAS units and reset

---

## Difficulty Reference

| Level | Typical units | AA defence |
|-------|--------------|------------|
| 0 | Infantry, jeeps | None |
| 1 | APCs, trucks | MANPADS |
| 2 | BMPs, BTRs | ZU-23 |
| 3 | IFVs, light tanks | ZSU-23-4 + SA-9 |
| 4 | MBTs | SA-13 + SA-15 |
| 5 | Heavy MBT mix | SA-6 / SA-11 |

---

## See Also

- [veafCombatZone](veafCombatZone.md) — for persistent, replayable zones
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCasMission` API
