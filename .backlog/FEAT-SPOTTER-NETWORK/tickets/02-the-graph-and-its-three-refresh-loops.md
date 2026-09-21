# 02 — The graph and its three refresh loops

Status: ⬜ ready

The radio plumbing: who can talk to whom. Ticket 01 gave units eyes; this one gives them a network
to speak into. Still nothing travels along it — that is ticket 03.

## The adjacency is held as sets, and that is measured, not taste

`adjacency[i][j] = true`, **not** an array of indices.

Removing a back-edge from a list means scanning it, so patching costs O(degree²) per node, and on
the dense front layout that is the single most expensive operation in the whole mechanism: **86 ms**
against **13.7 ms** for the same work on sets, a factor of six. Everywhere else the two are within
noise, so there is no case for lists. The sweep pays a little for `pairs` over `ipairs` and it does
not show at this scale.

Reproduce with `lua test/lua/bench_spotter_network.lua` if the choice is ever challenged. The bench
is not collected by the runner, which only takes `test_*.lua`, so it costs nothing in CI.

## Cost, so nobody re-litigates it

Measured on Lua 5.1.5 — the interpreter DCS runs, about 1.6× slower than 5.5 on this workload — at
the settled 20 km range, on the worst layout built: **2 000 units on a dense front, 230 577 edges.**

| Operation | Cost | How often |
|---|---|---|
| Full graph rebuild | 113 ms | once per 30 s loop |
| Movement check over 2 000 units | 0.15 ms | every loop |
| Re-edging 100 units (a combat zone spawning at once) | 13.7 ms with sets, 86 ms with lists | on the next pass |

**Spatial bucketing is off the table** and the PRD text saying otherwise is already struck. The cost
that document called "the whole problem" does not exist.

## Three loops, by speed class

| Class | Period | Contents |
|---|---|---|
| fast | 10 s | `Air` |
| mobile | 20 s | vehicles, `Ships` |
| slow | 30 s | infantry, statics |

Each loop reads the positions of **its own class** and recomputes the edges of the units that have
crossed a **2 km movement threshold**. Recomputing a node's edges is a **replacement**, not a
surgical removal — which is what avoids the individual-edge-removal code the Skynet lot had to
write.

Classification comes from the **unit type**, not from observation: a tank parked for ten minutes is
still capable of moving, so it is already in the right loop when it starts.

The same pass also picks up units that **appeared and disappeared**, so no DCS event has to be
listened to. That is the answer to the question worth asking (David, 2026-09-21): a combat zone
spawning a hundred units at once cannot trigger a burst of rebuilds, because nothing is triggered by
spawning at all. The integration cost is a single spike at the next pass, and 13.7 ms is exactly
that case measured.

**Worth recording honestly:** the movement check costs 0.15 ms for 2 000 units, so the three staged
loops optimise almost nothing measurable. They were chosen for correctness of dimensioning rather
than for cost, and they do no harm. Do not sell them as a performance feature.

**The trade-off, which is real:** a freshly spawned group takes up to 30 s to enter the graph. Its
*detection* works immediately, since that is ticket 01's 5 s loop and it does not depend on the
graph — so its units see, but cannot yet relay. Judged acceptable, and arguably realistic.

**If a later change ever does subscribe to spawn events, it must coalesce**, on the pattern
`veafRadio.refreshRadioMenu` uses (`veafRadio.lua:613`): schedule the real work a second out, guarded
by a flag the scheduled function clears when it runs. Read ticket 06 before copying it — that
pattern has a bug in its current form.

## Connectivity, which is the real finding

The network's reach is decided by the radio range, not by its cost. Same 1 000-unit mission,
averaged over 8 draws, as the share of units inside the largest connected pocket — an alert never
leaves the pocket it starts in:

| layout | 5 km | 10 km | 20 km | 30 km | 40 km |
|---|---|---|---|---|---|
| uniform | 0.8 % | 17.5 % | **100 %** | 100 % | 100 % |
| clusters | 2.5 % | 5.1 % | 8.8 % | 28.2 % | 71.7 % |
| front | 13.0 % | 61.1 % | **100 %** | 100 % | 100 % |

The network percolates sharply between 10 and 20 km, which is why the default is **20 km** and not
the 10 km the PRD first carried. Scattered clusters never fully connect at any range tested — 72 %
at 40 km is the honest limit of the idea on a mission whose contents are spread thin.

## Tests

- A unit that dies leaves the graph at the next pass of **its own** class's loop, not sooner.
- A unit that spawns joins it at the next pass, and not before.
- A unit that moved less than 2 km is **not** re-edged.
- A unit that moved more than 2 km has its edges replaced, and the graph stays symmetric: if `i`
  reaches `j`, `j` reaches `i`.
- The adjacency really is a set: `adjacency[i][j] == true`, and removing a back-edge is a single
  assignment rather than a scan. A test that only checks reachability would pass on lists too.
- **Wiring**: all three loops are actually scheduled, at 10, 20 and 30 s. Assert the schedule, not
  the pass.
- A unit is classified by its type and not by whether it has been observed moving: a stationary
  vehicle is in the mobile loop.

## Definition of done

- The graph, the three loops and the movement threshold written, adjacency held as sets.
- The tests above, including the wiring assertions.
- `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean, Lua coverage floor
  bumped.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section.
