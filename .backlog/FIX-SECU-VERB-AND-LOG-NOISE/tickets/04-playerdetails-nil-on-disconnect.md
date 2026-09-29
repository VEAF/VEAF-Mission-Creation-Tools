# 04 — a normal disconnect logs an ERROR from the server hook

Status: ⬜ ready

private1, 2026-09-29, three times in 90 minutes, once per pilot who left:

```
ERROR VEAFHOOK: veafServerHook.onPlayerChangeSlot([5]) - _playerDetails is nil
```

Each one sits immediately after `onGameEvent(disconnect)` for the same client id — checked on the
three occurrences, three lines of context each. DCS fires `onPlayerChangeSlot` on the way out, and
by then `net.get_player_info(id)` has nothing to return. The guard at
`VEAF-Server-hook.lua:288` is right to return; it is the **level** that is wrong.

An ERROR is what someone greps for when a server misbehaves. Making every normal departure raise
one costs the signal, and it made this session's reading longer: the line was a suspect for
ticket 01 until its context was measured.

## Done when

- A disconnect no longer produces an ERROR. `debug` fits — nothing is broken and nothing is to be
  done about it.
- If a nil `_playerDetails` can also happen **outside** a disconnect, that case keeps a level worth
  grepping for; say which, rather than lowering both blind.
