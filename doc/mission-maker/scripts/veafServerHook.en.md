# veafServerHook — VEAF server hook

**File:** `VEAF-Server-hook.lua` | **Version:** 2.7.x | **Location:** `Saved Games/<server>/Scripts/Hooks/`

---

## Purpose

A DCS hook (GameGUI environment) running on a dedicated server. It:

- listens to chat and runs VEAF server commands (`/secu login`, `/send`, `/pause`…), relayed to
  the mission through `veafRemote` / `veafSecurity`;
- loads the pilots list (permission level per UCID);
- optionally restarts the server when idle (opt-in);
- optionally pushes telemetry to an API server (opt-in).

> This is **not** a mission module: it is not injected into the `.miz`. It is dropped into the
> server's `Scripts/Hooks/` folder and loaded at DCS startup.

---

## Installation

1. Drop `VEAF-Server-hook.lua` into `Saved Games/<server>/Scripts/Hooks/`.
2. Drop `veaf-pilots.txt` into the `Saved Games/` root (one shared file serves every server by
   default) and edit it. To use a per-server file instead, set `pilotsDir` (see below).
3. Add a `VEAF-specific-server-hook.lua` in the same folder for per-server configuration
   (see below).
4. **Restart the server**: the hook is loaded at DCS startup; reloading the mission is not
   enough.

DCS load order: files in `Scripts/Hooks/` are loaded alphabetically. `VEAF-Server-hook.lua`
loads **before** `VEAF-specific-server-hook.lua`, which can therefore override the settings
below before the first event fires.

---

## Configuration (via the specific hook)

`VEAF-Server-hook.lua` is generic; its defaults suit a plain server. Anything server-specific
goes into `VEAF-specific-server-hook.lua`:

```lua
veafServerHook.enableAutoRestart     = false  -- restart watchdog + /restart /restartnow /halt commands
veafServerHook.enableBufferingSocket = false  -- telemetry to an API server (native BufferingSocket module)
veafServerHook.pilotsDir             = nil     -- pilots file folder; default = shared Saved Games/ root
```

- **`enableAutoRestart`** (default `false`): enables the idle-server restart and the
  `restart` / `restartnow` / `halt` chat commands. Leave off when restarts are handled by an
  external tool (e.g. DCSServerBot).
- **`enableBufferingSocket`** (default `false`): enables telemetry. The native `BufferingSocket`
  module is loaded defensively: if absent, telemetry is disabled automatically and the hook keeps
  working (no crash).
- **`pilotsDir`** (default `nil` → the shared `Saved Games/` root, one level above the server
  folder): every VEAF server reads the same `veaf-pilots.txt` there with no per-server config.
  Point it elsewhere (e.g. the hook's own folder) for a standalone server with its own list.

The specific hook also carries `serverName` and `serverBotChannel` (injected into the mission).

---

## Pilots file (`veaf-pilots.txt`)

A Lua table indexed by UCID, with one permission level per pilot:

```lua
pilots =
{
  ["<ucid>"] = { name = "Name", level = 99 },
  ...
}
```

Permission levels (ascending):

| Level | May… |
|------:|------|
| 0 | send messages (`/send`) |
| 1 | unlock commands (`/secu login`), spawn, missions/zones |
| 10 | `/restart`, `/halt` (if `enableAutoRestart`) |
| 30 | `/restartnow` |
| 50 | `/haltnow` |
| 90 | `/code` (arbitrary code execution) |
| 99 | administrator |

---

## Update

Replace `VEAF-Server-hook.lua` with the new version, keep the existing
`VEAF-specific-server-hook.lua` and `veaf-pilots.txt`, then **restart the server**.
