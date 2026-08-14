# veafCombatMission — The MISSIONS menu

**Module ID:** `COMBATMISSION` | **File:** `veafCombatMission.lua`

---

## Purpose

Offers players, from the F10 **MISSIONS** radio menu, scenarios the mission maker prepared in the DCS
editor and declared in YAML. Two families:

- **CAP missions** (`cap_missions:`) — on-demand combat air patrols;
- **combat missions** (`combat_missions:`) — scenarios with a briefing, elements, and remaining-enemy
  tracking.

The module is **enabled by default** (`veaf.registerModule(..., { enable = true }, 100)`). It builds
**no menu at all** when no mission is declared.

---

## Dependencies

- `veafRadio` — the F10 `MISSIONS` menu
- `veafSpawn` — spawns a mission's groups
- `veafSecurity` — for missions declared `secured: true`
- `veafRemote` — the `/air` remote module (optional)

---

## The F10 menu {#radio-menu}

> **The menu follows the mission's language** (`mission.language`). The labels below are the ones an
> English mission shows.

At the root of `MISSIONS`:

| Entry | Effect |
|-------|--------|
| `HELP` | Recalls how the menu works *(absent when help menus are disabled)* |
| `List available` | Lists the declared missions |
| `List active` | Lists running missions, with their remaining enemy count |

Then one submenu per mission, and inside it:

| Entry | Effect |
|-------|--------|
| `Get info` | The mission's briefing and state |
| `Activate mission` | Starts the mission *(shown while it is inactive)* |
| `Deactivate mission` | Stops it *(shown while it is active)* |

A mission declared `secured: true` has its activation entries routed through the security check: on
the F10 menu, the group acts at the level of its **lowest-graded** occupant (see
[veafSecurity](veafSecurity.en.md)).

A combat mission also offers **skill** and **scale** submenus, which set the difficulty and the
number of groups engaged.

---

## The aliases {#aliases}

`veafShortcuts` ships two shortcuts, and they **do not bypass security**
(`setBypassSecurity(false)`):

| Alias | What it does |
|-------|--------------|
| `-airstart` | Starts a combat mission — the name goes right after |
| `-airstop` | Stops a combat mission |

```
-airstart Frappe-Nord
-airstop Frappe-Nord
```

---

## The `/air` remote module {#remote}

Registered with `veafRemote` under the name `air`, it answers in chat:

| Command | Effect |
|---------|--------|
| `/air list` | Lists the available missions |
| `/air start <mission>` | Starts the named mission |
| `/air start <mission> silent` | Starts it with no on-screen message |
| `/air stop <mission>` | Stops it |
| `/air stop <mission> silent` | Stops it with no message |

---

## `mission.yaml` configuration {#configuration-missionyaml}

```yaml
modules:
  COMBATMISSION:
    enabled: true          # required for cap_missions: and combat_missions:

# ── CAP missions ──────────────────────────────────────────────────────────────
cap_missions:
  - group_name: "CAP Group"       # REQUIRED — logical name; the DCS group must be called "OnDemand-CAP Group"
    menu_name: "North CAP"         # F10 menu label
    briefing: "Patrol the northern sector and engage threats."
    default: false                # true = active by default
    activated: true               # true = activated immediately at start

# ── Combat missions ──────────────────────────────────────────────────────
combat_missions:
  - name: "Strike-Alpha"          # REQUIRED — internal identifier
    friendly_name: "Strike Alpha" # F10 menu label
    secured: false                # true = activation reserved to authorised pilots
    radio_menu_enabled: true      # show in the F10 menu
    briefing: |
      Destroy the armoured column in grid square BQ-123.
      Expect AAA and MANPADS.
    elements:
      - name: "Element Alpha 1"   # element's internal name
        groups:                   # DCS group names in this element
          - "STRIKE-GROUP-1"
          - "STRIKE-GROUP-2"
        scalable: true            # true = the group count follows the skill setting
```

### `cap_missions[]` fields {#cap-missions}

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `group_name` | string | — | Yes | Logical name of the CAP flight. **The DCS group placed in the editor must be named `OnDemand-<group_name>`**: the runtime prefixes `OnDemand-` (since v5). E.g. `group_name: CAP-Alpha` → DCS group `OnDemand-CAP-Alpha` |
| `menu_name` | string | — | No | F10 menu label |
| `briefing` | string | — | No | Briefing text shown to players |
| `default` | boolean | `false` | No | Start as an active mission by default |
| `activated` | boolean | `true` | No | Activate immediately at mission start |

### `combat_missions[]` fields {#combat-missions}

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `name` | string | — | Yes | Internal identifier |
| `friendly_name` | string | — | No | F10 menu label |
| `secured` | boolean | `false` | No | Activation reserved to authorised pilots — on the F10 menu the group acts at its lowest-graded occupant's level (see [veafSecurity](veafSecurity.en.md)) |
| `radio_menu_enabled` | boolean | `true` | No | Show in the F10 menu |
| `briefing` | string | — | No | Multi-line briefing text |
| `elements` | object[] | `[]` | No | Mission element definitions |
| `elements[].name` | string | — | No | Element's internal name |
| `elements[].groups` | string[] | — | No | DCS group names in this element |
| `elements[].scalable` | boolean | `true` | No | Scale the group count with difficulty |

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
    briefing: "Destroy the northern targets."
    elements:
      - groups: ["Strike-Group-1"]
```

---

## Module constants {#constants}

| Constant | Value | Role |
|----------|-------|------|
| `SecondsBetweenWatchdogChecks` | `30` | Interval between two mission-state checks |
| `MinimumSpacingBetweenClones` | `300` | Minimum distance, in metres, between two clones of the same group |
| `RadioMenuName` | `menu.combatmission.root` | i18n **key** for the F10 menu's name, resolved when the menu is built |

---

## See also

- [veafCasMission](veafCasMission.en.md) — on-demand CAS missions, a separate module
- [veafSecurity](veafSecurity.en.md) — what `secured: true` means for a pilot
- [mission.yaml reference](../../MISSION_YAML_REFERENCE.en.md) — every top-level section
