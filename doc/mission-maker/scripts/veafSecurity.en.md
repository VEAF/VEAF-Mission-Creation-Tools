# veafSecurity — Role-Based Permissions


**Module ID:** `SECURITY` | **File:** `veafSecurity.lua`

---

## Purpose

Provides a permission system for VEAF marker commands and radio menu actions. Restricts sensitive commands (spawning, teleporting, destroying) to authorised players, either from the pilot's level as declared on the server or through a SHA-1 hashed password.

---

## Enable

```lua
veafSecurity.initialize()
```

Call before other modules so that security checks are active when they initialise.

---

## Permission Levels

**A bigger number is a tighter tier.** A check passes when the pilot's level is *at least* the
constant, or when they supply that tier's password.

| Tier | Constant | Passes without a password when the pilot's level is |
|------|----------|-----------------------------------------------------|
| `KNOWN_PILOT` | `veafSecurity.LEVEL_KNOWN_PILOT` = 1 | **≥ 1** — any pilot listed in the server's `veaf-pilots.txt` |
| `SENIOR_PILOT` | `veafSecurity.LEVEL_SENIOR_PILOT` = 10 | **≥ 10** — a trusted member |
| `ADMIN` | `veafSecurity.LEVEL_ADMIN` = 90 | **≥ 90** — a server administrator |
| `MM` | (no level) | never — the Mission Master password is the only way in |
| `OPEN` | (no check) | always — the command is deliberately available to everyone |

!!! warning "`L0`, `L1` and `L9` are deprecated aliases, and they read backwards"

    This page announced "0 (public)" for `LEVEL_L0` until 6.13.70. That was wrong: `LEVEL_L0`
    is **90**, the tightest tier. Writing `L0` believing it opened a command to everyone in
    fact restricted it to administrators.

    `L0` → `ADMIN`, `L1` → `SENIOR_PILOT`, `L9` → `KNOWN_PILOT`. The values are unchanged, so
    renaming changes no mission's behaviour.

Passwords are hierarchical: the `ADMIN` one also opens `SENIOR_PILOT` and `KNOWN_PILOT`, and the
`SENIOR_PILOT` one opens `KNOWN_PILOT`. The Mission Master password sits outside that hierarchy — it
opens only the commands declared `MM`.

Every secured command declares its tier as a literal when it is registered (see
"Module-Level Security" below). See also the
[Mission Maker Guide](../GUIDE.en.md#security-tiers).

---

## Setting Passwords

Passwords are stored as SHA-1 hashes for security. Use the built-in `sha1` function:

```lua
-- In mission-script.lua (after veafSecurity is loaded)

-- Clear the shipped defaults and set your own. The tables keep the old names:
-- password_L0 = ADMIN, password_L1 = SENIOR_PILOT, password_L9 = KNOWN_PILOT.
veafSecurity.password_L0 = {}
veafSecurity.password_L1 = {}
veafSecurity.password_L9 = {}

-- Add hashed passwords (several are accepted per tier)
veafSecurity.password_L0[sha1.hex("myAdminPassword")] = true
veafSecurity.password_L1[sha1.hex("myTrustedMemberPassword")] = true
```

> **Clear before adding.** Without the `= {}`, your password is *added* to the one shipped with
> VEAF, which is published in a public repository — the mission would stay open to the default
> password.

> Do not commit plain-text passwords in your mission files. Use hashes only.

---

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `veafSecurity.authDuration` | `10` | Minutes that authentication remains valid |
| `veafSecurity.Keyphrase` | `"_auth"` | Marker command for authentication |
| `veafSecurity.LEVEL_ADMIN` | `90` | Administrator tier (deprecated alias: `LEVEL_L0`) |
| `veafSecurity.LEVEL_SENIOR_PILOT` | `10` | Trusted-member tier (deprecated alias: `LEVEL_L1`) |
| `veafSecurity.LEVEL_KNOWN_PILOT` | `1` | Listed-pilot tier (deprecated alias: `LEVEL_L9`) |

---

## Player Authentication

The `_auth` marker command carries three verbs:

```
_auth [PASSWORD]   -- checks the given password
_auth elevate      -- raises the author's group to their own level for 2 minutes
_auth logout       -- locks the mission again
```

An accepted password opens **no session**: secured commands check the password command by command
(`password` keyword). In chat, the same verbs exist as `/secu login|elevate|logout` (see
[veafServerHook](veafServerHook.en.md)); the hidden `-login` alias is equivalent to `_auth`.

!!! danger "Behaviour change — authentication is no longer global"
    **Before**: one successful `_auth` opened every secured command to **every player on the server**
    for `authDuration` minutes. While anyone was authenticated the pilots' real levels were not even
    consulted: the blunt mechanism disabled the precise one.

    **Now**: every secured command checks who is asking.

    - **A pilot listed in `veaf-pilots.txt` notices almost nothing**: their own level suffices, and
      they never needed the password. Known exception: `_transport` still demands the password from
      everyone, whatever their level — a bug, pending its fix.
    - **A pilot who is not listed** must supply the password **on every command**: there is no
      ten-minute session any more.
    - For the **F10 radio menu**, DCS cannot tell *which* occupant of a group clicked. The group
      therefore acts at the level of its **lowest-graded** occupant. The explicit verb
      `_auth elevate` (marker) or `/secu elevate` (chat) raises the group to the **requester's**
      level for 2 minutes — a plain `_auth [PASSWORD]` elevates nothing. That is what solves the
      instructor-flying-with-a-student case.

    Tell your pilots: this is a change they will notice mid-mission.

---

## Disabling Security (Development / Solo)

For testing or solo missions where security is not needed:

```lua
veaf.SecurityDisabled = true
```

This bypasses all security checks globally.

!!! warning "`veafSecurity.SecurityDisabled`: the old spelling, still honoured"
    Missions written before June 2026 use `veafSecurity.SecurityDisabled` (with the module prefix).
    That name was retired by mistake: it was believed never to be assigned, when it is in fact a
    **mission-facing** setting — so the only places that assign it are mission configs, outside this
    repository.

    The consequence, for three years: a mission asking for security **off** got it **on**. The
    direction is reassuring — nobody was over-privileged — but every secured command then refused
    for everyone, which reads as "the security layer is broken" rather than "your setting was
    retired".

    Both spellings work again. The old one logs a warning, once per mission, and **will be removed
    in v7**: migrate to `veaf.SecurityDisabled`.

---

## Module-Level Security

There is no per-module global setting: every command declares its tier as a literal when it is
registered, and the dispatcher applies the check before running it. Example for spawn:

```lua
-- The second argument is the required tier: "L9", "L1", "MM" or "OPEN"
veafSpawn.registerCommandHandler("smoke", "OPEN", function(eventPos, options, coalition, markId, bypassSecurity)
  -- ...
end)
```

---

## See Also

- [Lua API Reference](../../LUA_API_REFERENCE.en.md) — full `veafSecurity` API
