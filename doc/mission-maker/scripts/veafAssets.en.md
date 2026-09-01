# veafAssets — Tankers, AWACS, and Carriers


**Module ID:** `ASSETS` | **File:** `veafAssets.lua`

---

## Purpose

Manages the persistent assets in a mission — tankers, AWACS, JTACs. Provides F10 radio menu entries for each asset: information (position, TACAN, frequency), respawn after loss, and optional disposal.

---

## Dependencies

- `veafRadio` — F10 menu
- `veafDcsSpawner` / `veafMissionDb` — respawn (`veafAssets.respawn`) rebuilds the group with `VeafGroupSpawn`, from the mission record VEAF indexes at start-up. MiST is **not** required (it used to be, through `mist.respawnGroup`).

> ⚠️ **Assets must be groups placed in the Mission Editor.** Each asset `name` (and each `linked` entry) must exactly match a group present in the `.miz`. A dynamically-spawned or mis-named asset is not in the mission database VEAF builds at start-up (`veaf.getGroupRecord`) → respawn fails silently in-game. The build now emits a **warning** when a declared group (ASSETS, QRA, …) is absent from the mission.

---

## Enable

```lua
veafAssets.initialize()
```

Must be called after defining `veafAssets.Assets`.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  ASSETS:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    assets:               # list of persistent assets to manage
      - sort: 1                         # sort order in F10 menu (lower = first)
        name: "Texaco"                  # internal identifier
        description: "Texaco (KC-135)" # label shown in F10 menu
        information: 'Tacan 51Y\nU251.00 (21)'  # single-quoted: \n is preserved as-is → valid Lua escape
        linked: null                    # linked asset name (optional)
        jtac: 1688                      # laser code — the asset is a JTAC lasing with this code (optional)
        freq: null                      # override frequency for info display (optional)
        mod: null                       # radio modulation (AM | FM, optional)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enabled` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `assets` | object[] | `[]` | No | List of assets to manage |
| `assets[].sort` | integer | `0` | No | Sort order in the F10 menu (ascending) |
| `assets[].name` | string | — | Yes | Internal identifier |
| `assets[].description` | string | — | Yes | Label shown in the F10 menu |
| `assets[].information` | string | — | No | Info text displayed to players — use single-quoted YAML `'line1\nline2'` or `"line1\\nline2"` (double-quoted) to get a `\n` Lua escape |
| `assets[].linked` | string | `null` | No | Name of a group to respawn along with the asset. ⚠️ This is **not** what declares an escort — see [Escorting an asset](#escorting-an-asset) |
| `assets[].jtac` | number | `null` | No | Laser code: the asset is a JTAC that automatically lases with this code (requires CTLD) |
| `assets[].freq` | number | `null` | No | Override frequency for the info display (MHz) |
| `assets[].mod` | string | `null` | No | Radio modulation override (`AM` or `FM`) |

> The DCS group referenced by `name` must exist in the mission editor.

### Minimal example

```yaml
modules:
  ASSETS:
    enabled: true
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
    name        = "KC-135 Texaco",       -- DCS group name in the mission
    description = "Texaco (KC-135)",
    information = "Tacan 51Y\nU251.00 (21)",  -- info text (truthy → adds the Info button)
    disposable  = false,   -- allow players to despawn it
  },
  {
    name        = "KC-130 Arco",
    description = "Arco (KC-130)",
    information = "Tacan 50Y\nU251.50 (22)",
    disposable  = false,
  },
  {
    name        = "E-3A Overlord",
    description = "Overlord (E-3A)",
    information = "SRS 251.00",
    disposable  = false,
  },
}
```

### Asset Table Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | DCS group name in the mission (also used as the internal identifier) |
| `description` | string | Yes | Label shown in F10 menu |
| `information` | string | No | Info text shown to players; non-empty → adds the Info button |
| `disposable` | boolean | No | Allow authorised players to despawn the asset |

> Carriers are handled by the separate [veafCarrierOperations](veafCarrierOperations.en.md) module, not by `veafAssets`.

---

## Escorting an asset {#escorting-an-asset}

An asset's escort is the group named **`<asset name> escort`**. That name is not decorative: it is
what lets the framework find the escort in order to **repair its `Escort` task**, which DCS
invalidates every time the escorted group is recreated — by a respawn as much as by a teleport
(`_move tanker … teleport`).

In practice: set the `Escort` task on **any waypoint** of the escort's route, in the Mission
Editor, as you normally would. The rest is automatic.

### What a respawn does to an escort {#respawn-and-escorts}

Respawning an asset (**F10 → ASSETS → Respawn**) **respawns its escort too**, and then repairs the
`Escort` task. Both halves are needed, and neither replaces the other:

- **The escort comes back with its charge**, because the asset reappears where the Mission Editor
  drew it while its escort has kept flying. Measured in game on 2026-08-28 on the demo mission's
  tanker, minutes after a respawn: **78 km and 82 km** between the two, one escort already landed —
  against an `engagementDistMax` of **60 km** declared by the `Escort` task itself. Repairing the
  task alone therefore achieved nothing: it handed the escort a charge outside its own engagement
  distance.
- **The task is repaired all the same**, because what breaks it is the **escorted** group's id
  changing, not the escort's.

Worth knowing: the escort that comes back is a **fresh** one. An escort that was engaged, damaged or
low on fuel is replaced, exactly like the asset itself — and an escort that was shot down comes back
too.

> ⚠️ **`linked` is not what makes a group an escort.** The two mechanisms are still declared
> separately: `linked` lists arbitrary groups to respawn along with the asset, while the naming
> convention is what identifies the escort. So an escort need not be listed in `linked`: it comes
> back with its charge anyway, and its task is repaired. The two end up having the same effect on the
> escort at respawn time, but it is the naming convention — and only that — which allows the `Escort`
> task to be repaired.

**The symptom when the name does not follow the convention**: the escort takes off with its charge,
holds for a while, then **leaves to land after about ten minutes**. That is not the AI giving up: it
is an escort whose task points at a group that no longer exists, so it flies out its route and goes
home.

---

## F10 Radio Menu

Assets appear under **F10 → ASSETS**. An asset with neither `information` nor `disposable` is a plain **Respawn [description]** command; otherwise a submenu is created with:

- **Respawn [description]** — respawns the group at its original position
- **Get info on [description]** — displays the information text (if `information` is set)
- **Dispose of [description]** — despawns the asset (if `disposable = true`, secured command)

---

## Notes

- The DCS group must exist in the mission editor with the exact name used in `name`
- Tanker information (TACAN, frequency) is read from the DCS group's waypoint/route settings

---

## See Also

- [veafCarrierOperations](veafCarrierOperations.en.md) — carrier recovery management
- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafAssets` API
