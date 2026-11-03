# 05 — A different draw at every launch

Status: ⬜ ready

The whole point of the draws is that two launches differ.
`veaf.lua` (initialisation, around line 5589) reseeds `math.random` with `os.time()` only when `os` is reachable, directly or through `SERVER_CONFIG.getModule("os")`.
On a sanitised server neither is, and nothing says whether DCS then starts each launch on the same sequence.
Not measured.

## Done when

- Measured in DCS, on a sanitised `MissionScripting.lua`: the first ten `math.random(1000)` values of two launches of the same mission, logged by a test script; the result, with its date, goes into `known-limitations.yaml` (`kind: dcs`) whichever way it falls.
- If the two sequences are equal: the reseed falls back on a source that varies between launches without `os` — a candidate is `timer.getRealTime()`, to be measured as well — with a Lua test showing the fallback is taken when `os` is absent.
- If they differ: nothing changes in Lua, and the measurement is what closes the ticket.
- The DCS part is an entry in `DCS-SESSION-TODO.md` with the exact steps, since it needs the game.
