# veafCarrierOperations — Carrier Recovery Management


**Module ID:** `CARRIER` | **Version:** 1.12.x | **File:** `veafCarrierOperations.lua`

---

## Purpose

Manages aircraft carrier recovery operations. When players start a recovery, the carrier automatically turns into the wind to achieve the desired wind-over-deck speed, holds that heading for the recovery period, then returns to its original route. Displays BRC, TACAN, ICLS, and radio information.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafAssets` — registers carrier assets (optional integration)

---

## Enable

```lua
veafCarrierOperations.initialize()
```

Then register each carrier:

```lua
veafCarrierOperations.addCarrier({
  name        = "Mother",
  description = "CVN-73 Theodore Roosevelt",
  groupName   = "CVN-73",
})
```

Or let `veafAssets` handle registration automatically when a carrier asset has `carrier = true`.

---

## Configuration (`mission.yaml`)

Carrier operations are enabled via the `CARRIER` module ID. Carrier definitions are typically declared through the `ASSETS` module (see [veafAssets — Configuration](veafAssets.md#configuration-missionyaml)).

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

## F10 Radio Menu (per carrier)

- **Info** — BRC, relative wind, TACAN channel, ICLS channel, ATC frequency
- **Start Recovery** — turn into wind and begin 45-minute recovery window
- **Stop Recovery** — end recovery, resume original route

---

## Example Configuration

```lua
-- In mission-script.lua
veafCarrierOperations.initialize()

-- Carriers are registered via veafAssets:
veafAssets.Assets = {
  {
    name        = "Mother",
    description = "CVN-73 Theodore Roosevelt",
    groupName   = "CVN-73",
    information = true,
    carrier     = true,
  },
}
veafAssets.initialize()
```

---

## See Also

- [veafAssets](veafAssets.md) — asset management and radio menu integration
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafCarrierOperations` API
