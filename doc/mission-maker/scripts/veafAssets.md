# veafAssets — Tankers, AWACS, and Carriers


**Module ID:** `ASSETS` | **Version:** 1.8.x | **File:** `veafAssets.lua`

---

## Purpose

Manages the persistent assets in a mission — tankers, AWACS, and carriers. Provides F10 radio menu entries for each asset: information (position, TACAN, frequency), respawn after loss, and optional disposal.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafCarrierOperations` — for carrier assets (optional, auto-integrated)

---

## Enable

```lua
veafAssets.initialize()
```

Must be called after defining `veafAssets.Assets`.

---

## Configuration (`mission.yaml`)

```yaml
lua_modules:
  ASSETS:
    enable: true          # default: true
    logLevel: info        # optional log level override
    assets:               # list of persistent assets to manage
      - sort: 1                         # sort order in F10 menu (lower = first)
        name: "Texaco"                  # internal identifier
        description: "Texaco (KC-135)" # label shown in F10 menu
        information: "Tacan 51Y\nU251.00 (21)"  # info text shown to players (\n for newline)
        linked: null                    # linked asset name (optional)
        jtac: false                     # true = asset is a JTAC (optional)
        freq: null                      # override frequency for info display (optional)
        mod: null                       # radio modulation (AM | FM, optional)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enable` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `assets` | object[] | `[]` | No | List of assets to manage |
| `assets[].sort` | integer | `0` | No | Sort order in the F10 menu (ascending) |
| `assets[].name` | string | — | Yes | Internal identifier |
| `assets[].description` | string | — | Yes | Label shown in the F10 menu |
| `assets[].information` | string | — | No | Info text displayed to players (supports `\n` for line breaks) |
| `assets[].linked` | string | `null` | No | Name of a linked asset (e.g. a carrier linked to its escort) |
| `assets[].jtac` | boolean | `false` | No | Marks this asset as a JTAC |
| `assets[].freq` | number | `null` | No | Override frequency for the info display (MHz) |
| `assets[].mod` | string | `null` | No | Radio modulation override (`AM` or `FM`) |

> The DCS group referenced by `name` must exist in the mission editor. Carrier assets also require `CARRIER` module enabled.

### Minimal example

```yaml
lua_modules:
  ASSETS:
    enable: true
    assets:
      - sort: 1
        name: "Texaco"
        description: "Texaco (KC-135)"
        information: "Tacan 51Y\nU251.00 (21)"
      - sort: 2
        name: "Overlord"
        description: "Overlord (E-3A)"
        information: "SRS 251.00"
```

---

## Defining Assets

Populate `veafAssets.Assets` before calling `initialize()`:

```lua
veafAssets.Assets = {
  {
    name        = "Texaco",
    description = "Texaco (KC-135)",
    groupName   = "KC-135 Texaco",
    information = true,    -- show Info button in radio menu
    disposable  = false,   -- allow players to despawn it
  },
  {
    name        = "Arco",
    description = "Arco (KC-130)",
    groupName   = "KC-130 Arco",
    information = true,
    disposable  = false,
  },
  {
    name        = "Overlord",
    description = "Overlord (E-3A)",
    groupName   = "E-3A Overlord",
    information = true,
    disposable  = false,
  },
  {
    name        = "Mother",
    description = "CVN-73 Theodore Roosevelt",
    groupName   = "CVN-73",
    information = true,
    carrier     = true,    -- enables carrier-specific info (BRC, TACAN, ICLS)
    disposable  = false,
  },
}
```

### Asset Table Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Internal identifier |
| `description` | string | Yes | Label shown in F10 menu |
| `groupName` | string | Yes | DCS group name in the mission |
| `information` | boolean | No | Show Info button (position, TACAN, freq) |
| `disposable` | boolean | No | Allow authorised players to despawn the asset |
| `carrier` | boolean | No | Show carrier-specific info (BRC, TACAN, ICLS) |

---

## F10 Radio Menu

For each asset, a submenu is created under **F10 → Assets**:

- **Respawn [name]** — respawns the group at its original position
- **Get info on [name]** — displays position, TACAN channel, radio frequency (if `information = true`)
- **Dispose of [name]** — despawns the asset (if `disposable = true`, secured command)

---

## Notes

- The DCS group must exist in the mission editor with the exact name used in `groupName`
- Tanker information (TACAN, frequency) is read from the DCS group's waypoint/route settings
- Carrier information requires `veafCarrierOperations` to be initialised

---

## See Also

- [veafCarrierOperations](veafCarrierOperations.md) — carrier recovery management
- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafAssets` API
