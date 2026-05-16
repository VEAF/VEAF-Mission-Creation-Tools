# veafSecurity — Role-Based Permissions

**Module ID:** `SECURITY` | **Version:** 1.3.x | **File:** `veafSecurity.lua`

---

## Purpose

Provides a password-based permission system for VEAF marker commands and radio menu actions. Restricts sensitive commands (spawning, teleporting, destroying) to authorised players. Three permission levels with SHA-1 hashed passwords.

---

## Enable

```lua
veafSecurity.initialize()
```

Call before other modules so that security checks are active when they initialise.

---

## Permission Levels

| Level | Constant | Who can use |
|-------|----------|-------------|
| 0 (public) | `veafSecurity.LEVEL_L0` | All players — no password required |
| 1 (pilots) | `veafSecurity.LEVEL_L1` | Pilots with L1 password |
| 9 (admin) | `veafSecurity.LEVEL_L9` | Administrators with L9 password |

The default security level for spawn commands can be set per-module.

---

## Setting Passwords

Passwords are stored as SHA-1 hashes for security. Use the built-in `sha1` function:

```lua
-- In missionconfig.lua (after veafSecurity is loaded)

-- Clear default passwords and set your own
veafSecurity.password_L1 = {}
veafSecurity.password_L9 = {}

-- Add hashed passwords (multiple passwords supported per level)
veafSecurity.password_L1[sha1.hex("myL1password")] = true
veafSecurity.password_L9[sha1.hex("myAdminPassword")] = true
```

> Do not commit plain-text passwords in your mission files. Use hashes only.

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafSecurity.authDuration` | `10` | Minutes that authentication remains valid |
| `veafSecurity.Keyphrase` | `"_auth"` | Marker command for authentication |
| `veafSecurity.LEVEL_L0` | `90` | Internal weight for public level |
| `veafSecurity.LEVEL_L1` | `10` | Internal weight for pilots level |
| `veafSecurity.LEVEL_L9` | `1` | Internal weight for admin level |

---

## Player Authentication

Players authenticate via a map marker command:

```
_auth [PASSWORD]
```

On success: access is granted for `authDuration` minutes. No message is displayed to other players.

---

## Disabling Security (Development / Solo)

For testing or solo missions where security is not needed:

```lua
veaf.SecurityDisabled = true
```

This bypasses all security checks globally.

---

## Module-Level Security

Each module can set the default security requirement for its commands. Example for spawn:

```lua
-- Require L1 (pilots) for all spawn commands
veafSpawn.defaultSecurity = veafSecurity.LEVEL_L1
```

---

## See Also

- [Lua API Reference](../../LUA_API_REFERENCE.md) — full `veafSecurity` API
