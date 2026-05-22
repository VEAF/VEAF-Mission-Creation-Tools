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

This automatically registers the default alias list. Mission makers can add custom aliases in `missionConfig.lua`.

---

## Custom Aliases

Add mission-specific aliases in your `missionConfig.lua`:

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
