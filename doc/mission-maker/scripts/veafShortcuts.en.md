# veafShortcuts — Marker Aliases

**Module ID:** `SHCUT` | **File:** `veafShortcuts.lua`

---

## Purpose

Provides short, easy-to-remember marker commands (aliases) that map to full `_spawn` or other VEAF commands. Players type `-aliasName` in a map marker instead of memorizing complex command syntax.

---

## How It Works

1. Player places an F10 map marker with text starting with `-`
2. `veafShortcuts` resolves the alias to the underlying VEAF command
3. The resolved command is executed as if the player had typed it directly

Aliases can include **randomized parameters** (e.g. `-sam` picks a random defense level each time).

---

## Enable

```lua
veafShortcuts.initialize()
```

This automatically registers the default alias list.

---

## Configuration (`mission.yaml`)

```yaml
modules:
  SHORTCUTS:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    shortcuts:            # custom alias definitions
      - name: "smoke"                 # alias name (used as -smoke in markers)
        description: "Smoke shortcut" # shown in radio help
        command: "/_smoke"            # VEAF command to execute
        bypass_security: false        # true = always available, no /secu needed
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enable` | boolean | `true` | No | Enable or disable the module |
| `logLevel` | string | *(global)* | No | Per-module log level override |
| `shortcuts` | object[] | `[]` | No | Additional custom aliases |
| `shortcuts[].name` | string | — | Yes | Alias name — players type `-name` in a map marker |
| `shortcuts[].description` | string | — | No | Description shown in radio help |
| `shortcuts[].command` | string | — | Yes | Full VEAF command to execute (e.g. `/_smoke`) |
| `shortcuts[].bypass_security` | boolean | `false` | No | If true, this alias ignores the security system |

### Minimal example

```yaml
modules:
  SHORTCUTS:
    enabled: true
    shortcuts:
      - name: "cas"
        description: "Request CAS"
        command: "/_spawn group, name CAS-Template"
```

---

Mission makers can also add custom aliases in `mission-script.lua`:

---

## Custom Aliases

Add mission-specific aliases in your `mission-script.lua`:

```lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-myalias")
    :setDescription("My custom spawn")
    :setVeafCommand("_spawn group, name my-custom-group")
)
```

---

## Default Aliases Reference

See the **[Aliases Reference](../../ALIASES.md)** for the complete list of all built-in aliases.

---

## See also

- [Aliases Reference](../../ALIASES.md) — full list of all built-in aliases
- [veafSpawn](veafSpawn.md) — the underlying spawn engine
- [veafSecurity](veafSecurity.md) — permission system


### Air Missions

| Alias | Description |
|-------|-------------|
| `-cap` | Dynamic CAP (needs aircraft name) |
| `-airstart` | Start a combat mission (needs name) |
| `-airstop` | Stop a combat mission (needs name) |
| `-zonestart` | Activate a combat zone (needs name) |
| `-zonestop` | Deactivate a combat zone (needs name) |

### Radio

| Alias | Description |
|-------|-------------|
| `-send` | Send radio message (needs `"MESSAGE"`) |
| `-play` | Play sound file (needs `"FILENAME"`) |

### Mission Master

| Alias | Description |
|-------|-------------|
| `-flag` | Get flag value (needs name) |
| `-flagon` | Set flag to ON (needs name) |
| `-flagoff` | Set flag to OFF (needs name) |
| `-run` | Run a runnable (needs name) |

### Utility Commands

| Alias | Description |
|-------|-------------|
| `-destroy` | Destroy any unit within 100m of marker |
| `-ai_set` | Set AI handler for a ground group |

---

## Security

Most aliases respect the security system (`veafSecurity`). Some utility aliases (like `-smoke`, `-signal`, `-light`, `-tacan`, `-jtac`, `-afac`) bypass security and are always available to all players.

---

## See Also

- [Pilot Guide — Marker Commands](../../pilot/GUIDE.md#marker-commands) — player-facing usage instructions
- [veafSpawn](veafSpawn.md) — the underlying spawn engine
- [veafSecurity](veafSecurity.md) — permission system
