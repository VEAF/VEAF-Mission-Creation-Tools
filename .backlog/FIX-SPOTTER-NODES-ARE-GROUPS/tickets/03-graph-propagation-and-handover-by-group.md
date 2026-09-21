# 03 — The graph, the propagation and the hand-over keyed by group

Status: ⬜ ready

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

## Definition of done

- [ ] Nodes, adjacency, contacts, hand-over and reporting all keyed by group.
- [ ] The node and link counts above pinned by a test.
- [ ] `poetry run test-lua` green, `stylua` clean.
