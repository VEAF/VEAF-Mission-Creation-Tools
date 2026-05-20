# veafAssets — Tankers, AWACS, and Carriers

> 🇫🇷 [Version française](veafAssets.md)

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
