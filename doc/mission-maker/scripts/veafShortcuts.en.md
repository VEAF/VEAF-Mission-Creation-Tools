# veafShortcuts — Marker Aliases

**Module ID:** `SHORTCUTS` | **File:** `veafShortcuts.lua`

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

> **Enabled by default.** The built-in aliases (`-shilka`, `-sa2`, …) work out of the box — you only need the `shortcuts:` list below to add your *own* custom aliases.

---

## Configuration (`mission.yaml`) {#configuration-missionyaml}

```yaml
modules:
  SHORTCUTS:
    enabled: true          # default: true
    logLevel: info        # optional log level override
    shortcuts:            # custom alias definitions
      - name: "smoke"                 # alias name (used as -smoke in markers)
        description: "Smoke shortcut" # shown in radio help
        command: "/_smoke"            # VEAF command to execute
        bypass_security: false        # true = skips the command's level check (always available)
```

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `enabled` | boolean | `true` | No | Enable or disable the module |
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

## Default Aliases Reference {#default-aliases-reference}

The most common built-in aliases are grouped below. See the **[Aliases Reference](../../ALIASES.en.md)** for the complete list of all built-in aliases.

### Air Missions

| Alias | Description |
|-------|-------------|
| `-cap` | Dynamic CAP (needs aircraft name) |
| `-awacs` | AWACS on a race-track from the marker, in Skynet with its datalink on; `escort <template>` adds an escort |
| `-escort` | Fighter escort for the friendly or neutral airplane nearest the marker (template optional) |
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

Most aliases respect the security system (`veafSecurity`). **Nine** utility aliases bypass it and stay
available to every player: `-smoke`, `-longsmoke`, `-signal`, `-light`, `-point`, `-tacan`, `-jtac`,
`-afac`, `-beacon`.

### What may follow a security-bypassing alias {#bypass-options}

After such an alias, a player's marker admits only the options that **tune** its effect, each in a strict form:

| Alias | Admitted options |
|---|---|
| `-smoke`, `-longsmoke`, `-signal` | `color` (red, green, orange, blue, white) |
| `-light` | `alt`, `radius` (integers) |
| `-jtac` | `laser` (4 digits), `freq` (MHz), `mod` (am, fm) |
| `-afac` | `laser`, `freq`, `mod`, `alt`, `speed`, `hdg` / `heading` (integers), `immortal` |
| `-tacan` | `channel` (1 to 3 digits), `band` (x, y), `code` (1 to 4 letters or digits), `radius` (0 to 999 m) |
| `-point` | a name, without a comma |
| `-beacon` | none |

Anything else refuses the marker **whole**: nothing runs, and only the marker's author gets a message saying what the alias accepts.
A VEAF command keyword (`_spawn`, `_cas`…) is refused anywhere after these aliases.
The refused text is never written to the log: it may carry a password.

Unchanged: the bare alias, `#…` coordinates and the `!N` delay, aliases run by a script (alias batches, combat zones), and a mission with security disabled.

A security-bypassing alias of your own admits nothing after it, unless it declares its options in `mission-script.lua`:

```lua
veafShortcuts.AddAlias(
  VeafAlias:new()
    :setName("-mysmoke")
    :setVeafCommand("_spawn smoke")
    :setBypassSecurity(true)
    :setAllowedOptions({ color = "color", shells = "^[1-3]$" })
)
```

A form is the name of a `veafShortcuts.OptionForms` form (`color`, `laser`, `frequency`, `modulation`, `integer`, `tacanChannel`, `tacanBand`, `morseCode`, `radius999`, `flag`), or an anchored Lua pattern.
An alias declared in `mission.yaml` with `bypass_security: true` admits nothing after it.

**Skipping the password does not mean keeping quiet.** Those two ideas were the same setting in the code
for a long time, and it showed: a pilot who dropped a `-tacan` marker got *no* confirmation at all — no
channel, no band. Silence now depends on one thing only: **who asked**.

| Who places the object | Message to the player |
|---|---|
| a pilot, through a marker on the F10 map | **always**, even when the alias skips the password |
| a script — combat zone, AirWaves wave, pre-placed unit | **none**, or a thirty-group zone would print thirty messages |

Two deliberate exceptions, because their message is not a notification but **the data a pilot needs to
use the thing**:

- a **JTAC** announces its laser code and frequency even when a script placed it;
- a **TACAN** announces its channel, band and ident — but only from a marker. Placed by a script it stays
  quiet, which is the previous behaviour, left alone for want of a mission that needs otherwise.

---

## See Also

- [Pilot Guide — Marker Commands](../../pilot/GUIDE.en.md#marker-commands) — player-facing usage instructions
- [Aliases Reference](../../ALIASES.en.md) — complete list of all built-in aliases
- [veafSpawn](veafSpawn.en.md) — the underlying spawn engine
- [veafSecurity](veafSecurity.en.md) — permission system
