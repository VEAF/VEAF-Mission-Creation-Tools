# Lot FIX-SERVERHOOK-CHAT-SIM-LOGGER — logger `Sim` crash + dead server-hook chat callback

Status: ✅ done
Branch: fix/server-hook-chat-and-sim-logger → PR → develop

## Problem Statement

Two runtime defects surfaced on the VEAF "privé 2" dedicated server (DCSServerBot
active), reported by David from a live session and confirmed against the server
`dcs.log`.

### 1. Logger crashes on `Sim` in the mission environment

`veaf.Logger:print` calls `Sim.getMissionName()` when forwarding a log line to the
DCS-Server-Bot channel (`src/scripts/veaf/veaf.lua`). `Sim` is a **GameGUI/hook**
global — it does **not** exist in the mission scripting environment (Main), so the
call raises `attempt to index global 'Sim' (a nil value)`.

This path runs whenever `logWithDcsServerBot and dcsbot and
veaf.config.DCS_SERVER_BOT_CHANNEL` — i.e. on every server that wires DCSServerBot.
`veaf.Logger:error` always passes `logWithDcsServerBot = true`, so **every
`:error()` call crashes** there. Observed consequences in the server log:

- carrier-ops radio command (unauthenticated) logs `:error()` in
  `veafRadio._proxyMethod` **before** the player-facing `trigger.action.outText`,
  so the crash swallows the message → "no display to the player";
- collateral crashes in unrelated error paths (`VEAF-MARKERS onEvent`,
  `Mission script error`).

Regression introduced 2025-07 (commit `9683a76f`, "Add server bot channel support").

### 2. Server hook listens on a non-existent chat callback

`VEAF-Server-hook.lua` registers `veafServerHook.onChatMessage(message, from)`.
DCS has **no `onChatMessage` GameGUI callback**; the chat-interception callback is
`onPlayerTrySendChat(playerID, msg, all)`
([Hoggit](https://wiki.hoggitworld.com/view/DCS_hook_onPlayerTrySendChat)). The
hook therefore never receives chat, so no server chat command (`/secu login`,
`/send`, `/restart`, …) has ever run — confirmed by the server log: DCS only emits
`onPlayerTrySendChat`, and `VEAFHOOK` shows **zero** "ran command" over weeks.

Two sub-issues beyond the name:
- **parameter order is different**: `onPlayerTrySendChat(playerID, msg, all)` vs the
  old `onChatMessage(message, from)` — must be remapped, not just renamed;
- the trailing `return false` would **drop all chat** on the real callback — it must
  return `nil` to let normal chat through (and `""` only to consume a recognised
  VEAF command).

## Solution

- **Fix 1** (`veaf.lua`): replace `Sim.getMissionName()` with
  `veaf.config.MISSION_NAME or "unknown"` (the mission-name source already used by
  every other module), keeping the DCSServerBot forwarding intact. Add a unit test
  driving `:print`/`:error` with `dcsbot` + channel set, asserting no crash and the
  expected forwarded payload.
- **Fix 2** (`VEAF-Server-hook.lua`): rename to `onPlayerTrySendChat(playerID,
  message, all)`, remap params, return `nil` for pass-through / `""` when a command
  is consumed. Bump the hook version.

## Out of scope / notes

- The hook installed on "privé 2" is a hand-edited variant (BufferingSocket
  removed). After merge, the fix must be re-applied there without reintroducing the
  removed parts.
- The mission `.miz` must be rebuilt with the corrected `veaf.lua` for Fix 1 to take
  effect in game.

## Tickets

1. `01-sim-logger-crash.md` — drop the `Sim` dependency in `veaf.Logger:print`.
2. `02-server-hook-chat-callback.md` — use the real `onPlayerTrySendChat` callback.

---

## 01 — Drop the `Sim` dependency in `veaf.Logger:print`

Status: ✅ done

### Context

`veaf.Logger:print` (`src/scripts/veaf/veaf.lua`) forwards log lines to the
DCSServerBot channel using `Sim.getMissionName()`. `Sim` does not exist in the
mission scripting environment, so the call raises `attempt to index global 'Sim'`,
crashing every `:error()` on servers wired to DCSServerBot.

### Change

- Replace `Sim.getMissionName()` with `veaf.config.MISSION_NAME or "unknown"`.
- Keep the DCSServerBot forwarding behaviour otherwise unchanged.

### Tests (TDD)

In `test/lua/test_veaf.lua` (or the logger's test file):

- with `dcsbot` mocked and `veaf.config.DCS_SERVER_BOT_CHANNEL` set, calling
  `:error("x")` must **not** raise, and must forward a message containing
  `veaf.config.MISSION_NAME`;
- with `veaf.config.MISSION_NAME` nil, the forwarded message uses `"unknown"` and
  still does not raise.

### Done when

- `Sim` no longer referenced in `veaf.lua`.
- New tests green; `poetry run test-lua` passes.
- luacheck + stylua clean.

---

## 02 — Use the real `onPlayerTrySendChat` callback in the server hook

Status: ✅ done

### Context

`VEAF-Server-hook.lua` registers `veafServerHook.onChatMessage(message, from)`.
DCS has no `onChatMessage` GameGUI callback; chat is delivered via
`onPlayerTrySendChat(playerID, msg, all)`. The hook never sees chat, so no server
command has ever run (confirmed by the "privé 2" `dcs.log`: zero "ran command").

### Change

- Rename `veafServerHook.onChatMessage(message, from)` →
  `veafServerHook.onPlayerTrySendChat(playerID, message, all)`.
- Remap: the old `from` (player id) is now `playerID`; `message` stays the typed
  string.
- Return contract:
  - a message that is not a VEAF command → return `nil` (let DCS broadcast it);
  - a recognised VEAF command (`CommandStarter` prefix) that the hook consumes →
    return `""` so the command text is not broadcast to other players.
- Bump `veafServerHook.Version`.

### Tests (TDD)

Lua hooks are not covered by the mission test harness (they run in the GameGUI env
with `net`/`Sim` globals). Cover the parsing/return contract by extracting or
testing `veafServerHook.parse` return values where feasible with existing mocks; at
minimum, exercise the command-prefix branch and the pass-through branch. If the hook
cannot be loaded under the current mocks, document the manual verification (a
`/send <text>` on a live server now displays the text) and keep the change minimal
and reviewable.

### Done when

- Callback renamed + params remapped + return contract correct.
- Version bumped.
- luacheck + stylua clean on the hook.
- CHANGELOG updated.
