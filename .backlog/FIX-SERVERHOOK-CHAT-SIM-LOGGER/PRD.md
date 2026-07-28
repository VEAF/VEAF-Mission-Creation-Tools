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
