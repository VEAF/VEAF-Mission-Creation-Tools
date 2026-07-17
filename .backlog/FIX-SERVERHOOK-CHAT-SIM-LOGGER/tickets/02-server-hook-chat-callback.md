# 02 — Use the real `onPlayerTrySendChat` callback in the server hook

Status: 🔄 in-progress

## Context

`VEAF-Server-hook.lua` registers `veafServerHook.onChatMessage(message, from)`.
DCS has no `onChatMessage` GameGUI callback; chat is delivered via
`onPlayerTrySendChat(playerID, msg, all)`. The hook never sees chat, so no server
command has ever run (confirmed by the "privé 2" `dcs.log`: zero "ran command").

## Change

- Rename `veafServerHook.onChatMessage(message, from)` →
  `veafServerHook.onPlayerTrySendChat(playerID, message, all)`.
- Remap: the old `from` (player id) is now `playerID`; `message` stays the typed
  string.
- Return contract:
  - a message that is not a VEAF command → return `nil` (let DCS broadcast it);
  - a recognised VEAF command (`CommandStarter` prefix) that the hook consumes →
    return `""` so the command text is not broadcast to other players.
- Bump `veafServerHook.Version`.

## Tests (TDD)

Lua hooks are not covered by the mission test harness (they run in the GameGUI env
with `net`/`Sim` globals). Cover the parsing/return contract by extracting or
testing `veafServerHook.parse` return values where feasible with existing mocks; at
minimum, exercise the command-prefix branch and the pass-through branch. If the hook
cannot be loaded under the current mocks, document the manual verification (a
`/send <text>` on a live server now displays the text) and keep the change minimal
and reviewable.

## Done when

- Callback renamed + params remapped + return contract correct.
- Version bumped.
- luacheck + stylua clean on the hook.
- CHANGELOG updated.
