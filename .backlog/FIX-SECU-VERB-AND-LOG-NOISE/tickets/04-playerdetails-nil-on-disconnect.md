# 04 — a normal disconnect logs an ERROR from the server hook

Status: ✅ done

private1, 2026-09-29, three times in 90 minutes, once per pilot who left:

```
ERROR VEAFHOOK: veafServerHook.onPlayerChangeSlot([5]) - _playerDetails is nil
```

Each one sits immediately after `onGameEvent(disconnect)` for the same client id — checked on the
three occurrences, three lines of context each. DCS fires `onPlayerChangeSlot` on the way out, and
by then `net.get_player_info(id)` has nothing to return. The guard at
`VEAF-Server-hook.lua:288` is right to return; it is the **level** that is wrong.

**Not private1-specific.** Across the six instances' live `dcs.log` (read over SSH on 2026-09-30,
covering 2026-09-29 18:04 → 2026-09-30 17:45), the line appears on every instance that saw a
disconnect, and only there:

| Instance | `onGameEvent(disconnect)` | `_playerDetails is nil` | preceded by the disconnect |
|---|---|---|---|
| private1 | 19 | 19 | 19 |
| private2 | 1 | 1 | 1 |
| public1 | 1 | 1 | 1 |
| foothold1, foothold2, public2 | 0 | 0 | — |

The hook is loaded on all six (`VEAFHOOK` lines present everywhere), so the three zeros mean no
departure, not no hook. 21 disconnects, 21 errors, none outside a disconnect in that window.

An ERROR is what someone greps for when a server misbehaves. Making every normal departure raise
one costs the signal, and it made this session's reading longer: the line was a suspect for
ticket 01 until its context was measured.

## Done when

- A disconnect no longer produces an ERROR. `debug` fits — nothing is broken and nothing is to be
  done about it.
- If a nil `_playerDetails` can also happen **outside** a disconnect, that case keeps a level worth
  grepping for; say which, rather than lowering both blind.

## Resolution

The hook now implements `onGameEvent` and remembers the ids DCS reported disconnecting. A slot change
with no player info for such an id logs at debug and forgets the id; one for any other id logs a
**warning** — nothing is broken on our side, so no longer an ERROR, but unexplained, so still worth
grepping for. `onPlayerConnect` clears a reused id. Three tests in `test_veafServerHook.lua`; the DCS
behaviour itself, with the six-instance measurement above, is recorded in `known-limitations.yaml`
(`player-leaves-slot-after-dcs-forgot-the-player`).
