# 03 — The graph, the propagation and the hand-over keyed by group

Status: ✅ done

The part that removes the O(units²), which is the measured defect.

## What to change

- **Graph nodes are groups**: `getSpotterGraph`, `removeSpotterNode`, `reEdgeSpotterNode`,
  `listSpotterRelays`, `spotterGraphPass`. A node's position is the group's median.
- **`SpotterMoveThreshold` is measured on the median**, not on a unit. A convoy shuffling in place
  therefore re-edges nothing, which is the point of the threshold.
- **Contacts are keyed by group**: `getSpotterContacts`, `deliverSpotterMessage`,
  `emitSpotterMessage`, `spotterPropagationTick`, `forgetStaleSpotterContacts`, `spotterHeartbeat`,
  `getHeldSpotterAircraft`. `contact.via` becomes a group name, which is what the map draws.
- **The hand-over simplifies**: `spotterHandoverPass` and `handOverSpotterAlerts` match a Skynet SAM
  site against a node. A site *is* a group, so the matching stops going through units.
- **Reporting follows**: `spotterStatusPage`, `describeSpotterGraph`, `recordSpotterAcquisition`,
  `recordSpotterWakeUp` name groups — which is also what a human reading the status page wants.

## The numbers this ticket exists to move

Measured in game on 2026-09-21, on `spotter-network-walkthrough`, with two 11-vehicle transport groups
spawned to link the isolated SA-6 into the network:

| | before | after |
|---|---|---|
| graph nodes | **37** (for 10 DCS groups) | 10 |
| links drawn | **538** | at most 45 |
| draw budget | 400 shapes | 400 shapes |

So the view was truncated by construction: the links alone exceeded the budget.

## Tests

- A graph of 10 groups holding 37 units has **10** nodes.
- Two 11-vehicle groups produce **one** edge between them, not 121.
- A group moving less than the threshold re-edges nothing, even when its units shuffle.
- A relayed contact's `via` names the group that passed it on.
- The hand-over still names the right battery, with the existing wake-up assertions.

## What the code lost, which is the good part

- `listSpotters` and `listSpotterRelays` were two copies of the same group-then-unit walk; both are
  now filters over one `listSpotterNodes`.
- `handOverSpotterAlerts` walked the site's units and unioned what each of them held, into a set so
  an aircraft two launchers held was not reported twice. A Skynet SAM site *is* a group, so that is
  **one lookup** now, and the test whose premise was "two of the site's units hold it" is
  re-expressed as "alerted twice, reported once" — the property is structural rather than defended
  by a union.
- `spotterHeartbeat` recovered a spotter's coalition by asking every coalition's graph which one held
  it as a node; the partition gives it straight off the key. **The graph membership test stayed**,
  and dropping it was a mistake caught by an existing test: `emitSpotterMessage` appends a wave
  unconditionally, so a spotter that is not a node would emit a wave with an empty frontier, once per
  heartbeat, for ever.

## Definition of done

- [x] Nodes, adjacency, contacts, hand-over and reporting all keyed by group.
- [x] The counts pinned: two 11-vehicle convoys are **2** nodes and **1** link, not 22 and 121.
- [x] A convoy shuffling in place is **not** re-edged — asserted as the node position being exactly
      unchanged, because "moved less than the threshold" would pass on a node nothing ever updates.
- [x] `poetry run test-lua` green, `stylua` clean.
