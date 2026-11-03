# 05 — A different draw at every launch

Status: ✅ done

The whole point of the draws is that two launches differ.
`veaf.lua` (initialisation, around line 5589) reseeds `math.random` with `os.time()` only when `os` is reachable, directly or through `SERVER_CONFIG.getModule("os")`.
On a sanitised server neither is, and nothing says whether DCS then starts each launch on the same sequence.
Not measured.

## Done when

- Measured in DCS, on a sanitised `MissionScripting.lua`: the first ten `math.random(1000)` values of two launches of the same mission, logged by a test script; the result, with its date, goes into `known-limitations.yaml` (`kind: dcs`) whichever way it falls.
- If the two sequences are equal: the reseed falls back on a source that varies between launches without `os` — a candidate is `timer.getRealTime()`, to be measured as well — with a Lua test showing the fallback is taken when `os` is absent.
- If they differ: nothing changes in Lua, and the measurement is what closes the ticket.
- The DCS part is an entry in `DCS-SESSION-TODO.md` with the exact steps, since it needs the game.

## Measured — 2026-11-03

On DAVID-BUREAU, a copy of *Marteau du Golan* with a `training:` block, `_TRAINING_ALL.miz` launched three times in one DCS session, with a `veaf.seedRandom` written for the measure that logged its source and the first draw:

| Launch | Seed source | First `math.random(1000000)` | Sa'sa' drew |
|---|---|---|---|
| 1 | `nil` | 256387 | the drawn `-armor`, `Sasa-bmp`, `Sasa-t72` |
| 2 | `nil` | 586566 | `Sasa-t72`, `Sasa-armor-1`, the drawn `-armor` |
| 3 | `nil` | 119054 | — (the simulation never ran) |

`os` was reachable (`MissionScripting.lua` keeps it), so the `nil` can only come from the `math.randomseed` guard: the function does not exist in the mission environment, and the 2021 guard in `veaf.lua` has never seeded anything.
The draws differ anyway: DCS's own sequence changes from one launch to the next.
So **no Lua change**: the measuring function was removed, and the measure went into `known-limitations.yaml` (`math-randomseed-is-not-in-the-mission-environment`).
