# FEAT-SPOTTER-NETWORK — ground units see aircraft, and pass the word along

Status: 🔄 in-progress — **design done, costed and fully settled**, see [`design.md`](design.md). The
four points it left open were answered on 2026-09-21; nothing is awaiting a decision. The six
tickets were cut on 2026-09-21; implementation is under way.

Origin: David's idea, settled in principle with Flogas on 2026-09-19 alongside the last line of
defense, then designed decision by decision with David on 2026-09-20. Deliberately **VEAF code,
outside Skynet** — in `veafSkynetIadsHelper.lua`, where David placed it.

## The idea

Every DCS ground unit can notice a hostile aircraft nearby, at a distance that depends on what the
unit is and slightly randomised. Having seen it, the unit **passes the word** to whoever is within
radio range. Those in turn pass it on, and the alert spreads across the units close enough to relay
it.

Where it lands: a SAM site in a Skynet network **holds the contact and waits**, going live only
when the aircraft enters its firing envelope — exactly as it would for an early-warning radar. The
network is a **distributed EWR**, not a wake-up trigger.

It is a different animal from the last line of defense: that one is a single site hearing an
aircraft go over its own head, this one is a network of eyes and radios that carries information
across the map.

**The fallback for missions not using Skynet was dropped** on 2026-09-20. The feature lives inside
the Skynet helper and does nothing when Skynet is off; there is no alarm-state path.

## What the design settled

The full record, with the reasoning and the trade-offs accepted, is in [`design.md`](design.md).
In brief: detection from a table keyed on DCS attributes with two separate roles per unit, seeing
and relaying; a SAM site relays but never spots, which is what produces the domino; a spotter is a
latch that reports once per acquisition; line of sight gates both acquisition and loss; three kinds
of message — alert, cancellation, and a heartbeat as the safety net; the hand-over checks the firing
envelope itself and then calls `reportContact`.

## What the measurement changed

The bench is [`test/lua/bench_spotter_network.lua`](../../test/lua/bench_spotter_network.lua) and
it overturned this PRD's own premise.

**The quadratic cost this document called "the whole problem" is not one.** Measured on Lua 5.1.5,
the interpreter DCS runs, at the settled 20 km range and on the worst layout built — 2 000 units on
a dense front, 230 577 edges: a full graph rebuild is 113 ms, run once per 30 s loop; one alert
crossing that whole network is 10.6 ms; a movement check over 2 000 units is 0.15 ms.
**Spatial bucketing is not needed** and is struck from this lot.

One implementation choice does come out of the bench rather than out of taste: **the adjacency is
held as sets, not lists**. Re-edging a hundred units — a combat zone spawning at once — costs 86 ms
with lists and **13.7 ms** with sets, because removing a back-edge from a list means scanning it.

**The real problem is connectivity.** At the 10 km radio range this document assumed, the largest
connected pocket covers 5.1 % of a scattered mission — an alert would never leave the group that
raised it — and it only does real work on a dense front, at 61 %. The network percolates between
10 and 20 km. Hence the first open point: the default should be 20 km.

## Dependency — no longer blocking

`FEAT-LAST-LINE-OF-DEFENSE` is **done and merged** in
[`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS), and `reportContact` is written, tested
and documented there. No Skynet release has been cut and the artifact carried here is still
`3.4.0RP-VEAF build 05.09.2026`, so the door is not yet in this repository's shipped script.

**That no longer blocks this lot.** The design routes the hand-over through code that already
exists, so the work can be written and unit-tested against a stubbed `SkynetIADS` — which is what
the helper's own tests already do. Only the in-game verification waits on
[the vendoring ticket](../FIX-SKYNET-HELPER-AND-VENDORING/tickets/03-vendor-the-new-skynet-version.md).

A cleaner door in Skynet — a contact entering the network's own list so it ages, refreshes and logs
with the others — is worth proposing **after** this has run, designed on a measured need.

## Breakdown

Cut on 2026-09-21, once the design was closed. Ticket 06 is separate on purpose, so it can slip
without holding the mechanism.

1. [Detection: the unit table, the latch, and line of sight](tickets/01-detection-the-unit-table-and-the-latch.md)
2. [The graph and its three refresh loops](tickets/02-the-graph-and-its-three-refresh-loops.md)
3. [Propagation: alert, cancellation, heartbeat](tickets/03-propagation-alert-cancellation-heartbeat.md)
4. [Hand-over to Skynet, and the three `mission.yaml` settings](tickets/04-hand-over-to-skynet-and-the-three-settings.md)
5. [The status page](tickets/05-the-status-page.md)
6. [The game master map view](tickets/06-the-game-master-map-view.md) — separate, so it can slip

## Definition of done

- The feature behind its setting, **off by default**.
- Tests covering the latch, propagation, cancellation, the heartbeat net, message ordering, and the
  hand-over — asserting the **wiring** (loops actually scheduled, helper actually subscribed), not
  only the handlers.
- Documentation in `doc/mission-maker/`, both languages, per the repo's docs rules.
- Because it ships off by default: a release-note entry that says it exists, and a demonstration
  mission with it switched on. Without that it is the `ewr` option again — present, undocumented,
  and dead for four years.
- In-game verification, which is the only part that waits on the Skynet vendoring.
