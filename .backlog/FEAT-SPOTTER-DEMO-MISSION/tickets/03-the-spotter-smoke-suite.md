# 03 — An opt-in smoke suite that reads it

Status: ✅ done

`veaf-tools smoke-test --suite spotter`, two checks over the mission bridge.

| Check | Passes on | Means |
|---|---|---|
| `spotter-relay-reached-the-network-battery` | `woken:` ≥ 1 | a report crossed 10 km of radio and named a battery with no eyes of its own |
| `spotter-relay-did-not-reach-the-control-battery` | `woken:0` | the 60 km battery was never named — the half that lets the first one fail |

## Why a suite of its own rather than more entries in `CHECKS`

They assert on a geometry only this rig carries. In the default suite they would be **two permanent
failures** on every other mission, and a harness whose default run is always red is a harness nobody
reads — which is how the CTLD load gate was missed.

The other option was to fold them in with an expectation that accepts `no-such-site`, and it is
worse: a pass meaning *did not measure* is the green-light-earned-by-accident that module already
warns about.

## Traps respected

- **A check's Lua must return a string.** A Lua number, boolean or table all arrive as `''` over this
  transport, so the count is tagged — `woken:3` — and every expectation rejects `''`.
- **The history, not the page bucket.** Reading `spotterStatusWakeUps` from outside races the drain
  and reports a false negative; ticket 01 exists for that.

## Definition of done

- [x] The two checks are outside `CHECKS`, and a test asserts the two sets are disjoint.
- [x] Both run over `Transport.BRIDGE` — routed to the hook they would answer `veaf-absent` for ever.
- [x] No sentinel and no lost value can pass either of them, swept in a test.
- [x] The two halves disagree on the same reading, asserted — a run where both are green would mean
      the rig measured nothing.
- [x] `TestEveryChunkCompiles` walks **both** suites, so the opt-in one cannot go uncompiled until
      somebody runs it in front of a live DCS.
- [x] `--suite` refuses an unknown name instead of falling back to the default.
