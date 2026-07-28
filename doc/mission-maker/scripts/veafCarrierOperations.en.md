# veafCarrierOperations — Carrier Recovery Management


**Module ID:** `CARRIER` | **Version:** 1.12.x | **File:** `veafCarrierOperations.lua`

---

## Purpose

Manages aircraft carrier recovery operations. When players start a recovery, the carrier automatically turns into the wind to achieve the desired wind-over-deck speed, holds that heading for the recovery period, then returns to its original route. Displays BRC, TACAN, ICLS, and radio information.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafRemote` — exposes a `carrier` remote command

---

## Enable

```lua
veafCarrierOperations.initialize()
```

There is no per-carrier registration API. On `initialize()`, the module scans every group in the mission and automatically registers any group containing a known carrier unit type (see [Supported Carrier Types](#supported-carrier-types)). Its initial route, side and ATC data (TACAN/ICLS/LINK4/ACLS/tower, read from the carrier's programmed tasks) are captured at that point. Simply place a carrier group in the mission editor — no script call is needed.

> The module also manages two optional support groups (a rescue helicopter and a recovery tanker), likewise detected by name — see [Pedro and S3B recovery tanker](#pedro-and-s3b-recovery-tanker).

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

Carrier operations are enabled via the `CARRIER` module ID. Carriers themselves are not declared in `mission.yaml`: they are auto-discovered from the carrier groups present in the mission (see [Enable](#enable)).

```yaml
modules:
  CARRIER:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    init:
      include_carrier_operations_radio: true  # add carrier menu to F10 (default: true)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enable` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `init.include_carrier_operations_radio` | boolean | `true` | No | Add the carrier operations menu to the F10 radio tree |

### Minimal example

```yaml
modules:
  CARRIER:
    enabled: true
```

---

## Key Configuration Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafCarrierOperations.MAX_OPERATIONS_DURATION` | `45` | Auto-stop after N minutes |
| `veafCarrierOperations.ALIGNMENT_MANOEUVER_SPEED` | 20 kts | Carrier speed while turning into wind |
| `veafCarrierOperations.MIN_WINDSPEED_FOR_CHANGING_HEADING` | 4 kts | Minimum wind speed to warrant a turn |
| `veafCarrierOperations.MIN_CARRIER_SPEED` | 4 kts | Minimum carrier steaming speed |
| `veafCarrierOperations.DisableSecurity` | `false` | If true, anyone can start/stop recovery |

---

## Supported Carrier Types

The module knows the angled-deck offset for all stock DCS carriers:

| DCS Type | Angled deck offset | Wind over deck |
|----------|-------------------|----------------|
| `Stennis`, `CVN_71/72/73/75`, `Forrestal` | 9.05° | 25 kts |
| `KUZNECOW`, `CV_1143_5` | 9° | 25 kts |
| `LHA_Tarawa` | −1° (straight deck) | 20 kts |

---

## Pedro and S3B recovery tanker

Beyond the carrier itself, the module automatically manages two support groups, detected **by name** — no script call, no `mission.yaml` entry. Just place them in the mission editor following the naming convention.

| Group | Expected name | Role | Automatic positioning |
|-------|---------------|------|-----------------------|
| Pedro | `<carrier unit name> Pedro` | Rescue helicopter (SH-60B) | 250 ft, 1 nm to starboard, riding along with the carrier at the same speed and heading |
| S3B tanker | `<carrier unit name> S3B-Tanker` | Emergency recovery tanker (S-3B Tanker) | 8000 ft, 10 nm aft and 4 nm to starboard, refueling on the BRC |

`<carrier unit name>` is the name of the carrier **unit** (identical to the group name for a carrier alone in its group, the common case). Example: for a carrier unit named `CVN-73`, place the groups `CVN-73 Pedro` and `CVN-73 S3B-Tanker`.

Once named correctly, both groups are, on every operations cycle:

- **auto-detected**;
- **respawned** when destroyed;
- **routed** automatically, their path (re)computed to stay in formation with the carrier.

If a group is missing, the module ignores it and logs a warning — `No Pedro group named <name>` or `No Tanker group named <name>` — without blocking operations.

---

## F10 Radio Menu

The top-level **CARRIER OPS** menu holds a **CARRIER OPS - BLUE** and a **CARRIER OPS - RED** submenu, each containing one submenu per carrier (named after the carrier group). When operations are stopped, each carrier submenu offers:

- **Start carrier air operations for 45 minutes** — turn into the wind and open a 45-minute recovery window
- **Start carrier air operations for 90 minutes** — same, for 90 minutes (`MAX_OPERATIONS_DURATION` × 2)
- **ATC - Request informations** — TACAN, ICLS, LINK 4 / ACLS, tower, BRC and remaining time, plus current navigation and weather

While operations are running, the two *Start* items are replaced by:

- **End air operations** — stop recovery and send the carrier back to its initial route

> By default the *Start*/*End* items are secured (require a password). Set `veafCarrierOperations.DisableSecurity = true` to make them open to everyone.

---

## See Also

- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCarrierOperations` API
