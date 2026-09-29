# 02 — a mistyped chat command raises a Lua error instead of answering the pilot

Status: ⬜ ready

Three pilots, four wrong spellings, 90 minutes, private1, 2026-09-29 — all of them looking for the
command that unlocks a mission (see ticket 01):

```
19:20:54  /sec          → VEAF-REMOTE|E|executeCommandFromRemote: Module not found : [sec]
19:21:41  /se cu login  → Module not found : [se]            (Oulsky)
19:32:21  /veaf login   → Module not found : [veaf]          (VEAF_TiRco)
19:33:17  /veaflogin    → Module not found : [veaflogin]     (VEAF_TiRco)
```

Each one comes with a stack traceback in the server log:

```
stack traceback:
  [string "l10n/DEFAULT/veaf-scripts.lua"]:4449: in function 'error'
  [string "l10n/DEFAULT/veaf-scripts.lua"]:27719: in function 'executeCommandFromRemote'
  [string " if veafRemote and veafRemote.executeCommandFromRemote then ... end "]:1: in main chunk
```

Two things are wrong at once:

- **The pilot is told nothing.** He typed a command, it vanished. Nothing on screen, nothing in
  chat — so he tries another spelling, which is exactly what the log shows.
- **The server log takes a traceback for a typing mistake.** `executeCommandFromRemote` calls
  `error()` on an unknown module. A wrong module name is user input arriving over a chat channel,
  not a programming fault: it deserves a reply, not a raise.

## Done when

- An unknown module answers the pilot — the list of what exists is the obvious content — and logs
  at most a `warn` line without a traceback.
- A test drives `executeCommandFromRemote` with an unknown module and asserts both: the caller is
  answered, and nothing raises.
- While in there: `/sec` and `/veaf` were both tried as prefixes of `/secu`. Worth deciding whether
  an unambiguous prefix should be accepted, or explicitly refused with the full name — either is
  better than silence.
