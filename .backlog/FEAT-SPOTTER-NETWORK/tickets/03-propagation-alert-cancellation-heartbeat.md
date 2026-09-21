# 03 — Propagation: alert, cancellation, heartbeat

Status: ⬜ ready

Ticket 01 gave units eyes, ticket 02 gave them radios. This one makes the word travel.

## Three kinds of message

| Message | When | What it does |
|---|---|---|
| **Alert** | a spotter acquires an aircraft | propagates hop by hop; recipients **hold** the contact |
| **Cancellation** | a spotter loses an aircraft | propagates the same way; recipients drop the contact |
| **Heartbeat** | every 2 minutes while a contact is held | proves the link is alive |

A unit that has received no heartbeat for several periods **forgets** the alert. That net covers
every way things go wrong without having to tell them apart: a cancellation lost because a relay
died, a path broken by a reconfigured graph, a spotter killed before it could cancel.

The information therefore **has a life of its own**, and that is the point. The cancellation model
was chosen over a recomputed-state model that would have been simpler and cheaper, because in that
one killing the spotter instantly extinguishes the defence it had just alerted — which rewards
hunting the rifleman instead of the battery.

## The hop period is derived, never set

**range ÷ speed**, so 20 s at the defaults of 20 km and 3 600 km/h.

Range and period are coupled: a hop covers the radio range, so doubling the range at a fixed period
doubles the alert's speed. Exposing both separately means a mission maker who widens the range
silently doubles the propagation speed. Exposing **km/h** instead and deriving the period removes
the trap — widening the range slows the hops instead. The setting itself lands in ticket 04; here,
take the two values from constants and compute the period from them, never from a stored period.

At 3 600 km/h — four times a penetrating fighter — the alert crosses a fully connected 200 km front
in **247 s**, against roughly thirteen minutes for a fighter to fly it. That lead is the whole
purpose.

| layout | range | hops across the largest pocket | end to end |
|---|---|---|---|
| front | 20 km | 12.4 | **247 s** |
| uniform | 20 km | 22.9 | 457 s |
| clusters | 40 km | 12.8 | 510 s |

## The two rules that make it terminate and behave

**Ordering.** A message older than the last one processed for that aircraft is **ignored**. Without
it, a cancellation overtaking its own alert — possible, since the graph is reconfigured between the
two — would leave a site holding a contact forever.

**Relaying.** A unit relays a message if what it receives is *fresher* than what it already relayed
for that aircraft. This terminates on its own, since a given message carries a fixed timestamp and
each unit therefore passes it at most once. It also makes concurrent fronts **merge**: two spotters
in the same pocket send two waves that meet in the middle, and every unit is served by whichever
reached it first — that is, by the nearest witness.

Two spotters in **separate** pockets still produce two independent fronts, because neither front
ever marks the other's units. That falls out of the marking being per unit; nothing has to be
written for it, but it has to be tested, because nothing protects it either.

## Cost

One multi-source sweep — an alert crossing the whole worst-case network, 2 000 units and 230 577
edges on a dense front — is **10.6 ms** on Lua 5.1.5. Reproduce with
`lua test/lua/bench_spotter_network.lua`.

## Tests

- **Propagation**: reaches units k hops away after k periods, **and no sooner**. The "no sooner" is
  the half that catches an accidental flood.
- **Merging fronts**: two spotters in one pocket, both waves recorded, every unit served by the
  nearer one; two spotters in separate pockets stay independent.
- **Cancellation**: extinguishes along the path the alert took.
- **The heartbeat net**: drop a cancellation on the floor — kill the relay that would have carried
  it — and assert the contact is forgotten after the forget delay and not before.
- **Ordering**: a cancellation arriving before its own alert does not leave a site holding a
  contact.
- **Termination**: a cycle in the graph does not make a message circulate forever; count the relays
  and assert each unit passed a given message at most once.
- **The derived period**: change the range, assert the period changes and the speed does not. This
  is the trap the design exists to close, so it gets an assertion rather than a comment.
- **Wiring**: the propagation loop is actually scheduled, and the heartbeat with it.

## Definition of done

- Alert, cancellation and heartbeat written, with the ordering and relaying rules.
- The hop period computed from range and speed at every use, never stored as a period.
- The tests above.
- `poetry run test-lua` green, `stylua --check src/scripts/veaf/ test/lua/` clean, Lua coverage floor
  bumped.
- `CHANGELOG.md` updated under `[Unreleased]`, appended at the end of the section.
