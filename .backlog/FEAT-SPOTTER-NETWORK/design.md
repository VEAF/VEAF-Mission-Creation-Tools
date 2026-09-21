# FEAT-SPOTTER-NETWORK — design

Settled with David on 2026-09-20, decision by decision. This document is the phase the PRD
demanded before any code: the mechanism, the costs **measured** rather than assumed, and what the
measurement changed.

The bench behind the figures below is
[`test/lua/bench_spotter_network.lua`](../../test/lua/bench_spotter_network.lua), which measures a
*model* of the mechanism. Once the code existed, its own cost was measured separately with
[`test/lua/bench_spotter_shipped.lua`](../../test/lua/bench_spotter_shipped.lua) — see *What the
shipped code actually costs* below, because the two are not the same number.

**This document has been amended twice during implementation**, both times marked in place: the
line-of-sight cost claim contradicted its own requirement, and the graph figures were a model's
rather than the code's.

## What it does, in five lines

A ground unit that sees a hostile aircraft reports it. The report travels from unit to unit along
radio links, one hop at a time. A SAM site that receives it does **not** light up: it holds the
contact and waits, exactly as it would for an early-warning radar, and goes live only when the
aircraft enters its firing envelope. When the spotter loses sight of the aircraft it sends a
cancellation along the same network, and the defence goes quiet again.

The network is therefore **a distributed EWR**, not a wake-up trigger. That framing is David's, and
it is what makes the feature fit Skynet instead of fighting it.

## The mechanism

### Two roles, read from the unit's DCS attributes

Every unit carries two independent properties: a **detection range** (zero meaning it never sees
anything) and whether it can **relay**. They are separate because they genuinely are — a command
vehicle sees little and relays perfectly, an ammunition dump does neither.

A SAM site is **a relay and never a spotter**. Its own detection is already the last line of
defence's job, with a radius drawn once between 10 and 15 km. Giving it a second, competing radius
would mean the larger one always wins and the other setting is dead weight — the exact failure mode
of the `ewr` spawn option, inert for four years because nothing ever applied it.

This is also what produces the domino: a battery that is warned lights up *and passes the word*, so
a line of batteries wakes in the direction of the penetration.

### The spotter is a latch, not a siren

Per aircraft, each spotter is **armed**, or **triggered**.

- Armed, and the aircraft comes into range **with line of sight** → it reports once, and becomes
  triggered. It says nothing more while it keeps seeing that aircraft.
- Triggered, and it loses the aircraft → after **3 consecutive beats** without contact, it returns
  to armed and will report the aircraft again on reacquisition.

Two guards keep the latch from chattering, and they cover different causes:

- **A 10 % distance margin.** Contact is acquired at the unit's range but only lost beyond range
  × 1.1. An aircraft orbiting exactly on the limit stays held instead of flickering. One extra
  comparison on a distance already computed.
- **The 3-beat tolerance**, which covers terrain masking — an aircraft dropping behind a ridge for
  a few seconds is not lost.

Both are needed. The tolerance alone lets an aircraft orbiting on the limit re-trigger every time
it stays out for four beats; the margin alone does nothing about ridges.

### Line of sight counts both ways

`land.isVisible` gates **both** acquisition and loss, from 2 m above the spotter — the offset CTLD
uses, so a spotter looks from its eyes rather than from the mud. An aircraft following a valley is
not seen by the spotter behind the crest, which is precisely the profile that started this whole
investigation.

**Corrected during implementation, 2026-09-21.** This section first said the ray was traced "only on
transitions, never per beat per pair", which is what makes it affordable. That is not implementable
alongside the requirement two lines above — masking has to lose a *held* contact, so a held contact
has to be re-checked every beat, or an aircraft that slips behind a ridge stays seen forever.

The affordable property is about **pairs, not beats**: a pair the distance test already settles
costs no ray at all. The overwhelming majority of spotter/aircraft pairs on a mission are tens of
kilometres apart and never reach the terrain query, and only those within the unit's own range (or
within range × the margin, while held) pay for one — at most one per pair per beat, memoised because
the latch asks twice on a transition. Both halves are asserted in
`test_veafSkynetIadsHelper_spotter.lua`.

### Three kinds of message

| Message | When | What it does |
|---|---|---|
| **Alert** | a spotter acquires an aircraft | propagates hop by hop; recipients hold the contact |
| **Cancellation** | a spotter loses an aircraft | propagates the same way; recipients drop the contact |
| **Heartbeat** | every 2 minutes while a contact is held | proves the link is alive |

A unit that has received no heartbeat for several periods forgets the alert. That net covers every
way things go wrong without having to tell them apart: a cancellation lost because a relay died, a
path broken by a reconfigured graph, a spotter killed before it could cancel.

The information therefore **has a life of its own**. That is the point of the cancellation model,
and it is why it was chosen over a recomputed-state model that would have been simpler and cheaper:
in that one, killing the spotter instantly extinguishes the defence it had just alerted, which
rewards hunting the rifleman instead of the battery.

**Ordering rule:** a message older than the last one processed for that aircraft is ignored. Without
it, a cancellation overtaking its own alert — possible, since the graph is reconfigured between the
two — would leave a site holding a contact forever.

**Relaying rule:** a unit relays a message if what it receives is *fresher* than what it already
relayed for that aircraft. This terminates on its own — a given message carries a fixed timestamp,
so each unit passes it at most once — and it makes concurrent fronts merge: two spotters in the same
pocket send two waves that meet in the middle, and every unit is served by whichever reached it
first, i.e. by the nearest witness.

Two spotters in **separate** pockets still produce two independent fronts, since neither front ever
marks the other's units. That falls out of the marking being per unit; nothing had to be written for
it.

### Handing over to Skynet

The helper keeps the alert alive per site, and each cycle checks `samSite:isTargetInRange(contact)`
itself. When the aircraft finally enters the firing envelope, it calls
`SkynetIADS:reportContact(dcsUnit, samSite)`.

`reportContact` deliberately bypasses the kill-zone test — that is its documented contract, written
for the last line of defence. Here that bypass is harmless and in fact convenient: we have already
checked the envelope ourselves, so Skynet simply lets us decide. Every other guard still applies:
HARM silence, ammunition, power, destruction.

**This needs nothing new in Skynet**, which is why the lot can proceed while no Skynet release is
cut. The cleaner door — something like `reportDistantContact`, putting the contact in the network's
own list so it ages and refreshes with the others and shows up in Skynet's log — is worth proposing
**after** this has run, designed on a measured need rather than a guess.

`isTargetInRange` is annotated as an expensive call in Skynet's own source, so it is only invoked
for sites actually holding an alert.

### Two clocks, three graph loops

| | Period | Why |
|---|---|---|
| Detection | 5 s | aligned on Skynet's cycle; an aircraft at 900 km/h covers 1.2 km between passes |
| Propagation | **range ÷ speed**, so 20 s at the defaults | the alert must outrun the aircraft, and does so by four |
| Graph, fast (`Air`) | 10 s | |
| Graph, mobile (vehicles, `Ships`) | 20 s | |
| Graph, slow (infantry, statics) | 30 s | |

Each graph loop reads the positions of its class and recomputes the edges of the units that have
crossed a **2 km movement threshold**. Recomputing a node's edges is a replacement, not a surgical
removal — which avoids the individual-edge-removal code the Skynet lot had to write.

Classification comes from the unit type, not from observation: a tank parked for ten minutes is
still *capable* of moving, so it is already in the right loop when it starts. The same pass also
picks up units that appeared and disappeared, so no DCS event has to be listened to.

**That is the answer to a question worth asking** (David, 2026-09-21): a combat zone spawning a
hundred units at once cannot trigger a burst of rebuilds, because nothing is triggered by spawning
at all. The integration cost is a single spike at the next pass, and the bench measures exactly
that case — 100 units re-edged against 2 000 — at **13.7 ms** with the set representation, on the
densest layout. With lists it is 86 ms, which is the reason the representation is part of the
design rather than an implementation detail.

The trade-off, which is real: a freshly spawned group takes up to 30 s to enter the graph. Its
**detection** works immediately, since that is the 5 s loop and it does not depend on the graph —
so its units see, but cannot yet relay. Judged acceptable, and arguably realistic.

**If a later change ever does subscribe to spawn events, it must coalesce**, on the pattern
`veafRadio.refreshRadioMenu` already uses (`veafRadio.lua:613`): schedule the real work a second
out, guarded by a flag that the scheduled function clears when it runs, so a hundred calls in a row
produce one execution.

## The unit table

One table, three columns, keyed on DCS attributes — tested most specific first, the way AIEN does
it. Attribute names verified against `AIEN.lua`, which runs in game.

| Attribute | Detection | Relays | Speed class |
|---|---|---|---|
| `AWACS`, `EWR` | — | yes | fast / mobile |
| `SAM elements` | — | yes | mobile |
| `Air` minus the above (aeroplanes) | 30 km | yes | fast |
| `Helicopters` | 15 km | yes | fast |
| `Ships` | 12 km | yes | mobile |
| `MANPADS` | 10 km | yes | slow |
| `AAA` | 8 km | yes | mobile |
| `Air Defence vehicles` | 8 km | yes | mobile |
| `Infantry` | 4 km | yes | slow |
| `Artillery`, `MLRS` | 3 km | yes | mobile |
| `Tanks`, `IFV`, `APC`, `Armored vehicles` | 3 km | yes | mobile |
| `Unarmed vehicles`, `Trucks` | 3 km | yes | mobile |
| anything else, statics, buildings | — | no | slow |

The reasoning behind the shape, rather than the exact numbers, which are meant to be argued with:

- **Aircraft see furthest**, and by a wide margin: no terrain masks them, the view angle is open, and
  many carry a radar. A helicopter, usually low and slow, sees far less than an aeroplane.
- **Air-defence units see furthest on the ground** because watching the sky is their job and they
  carry optics for it. A MANPADS team is a spotter in the most literal sense.
- **Armour sees least.** A closed-down tank has a poor view of anything above the horizon.
- **Only what already feeds Skynet detects nothing here** — `EWR` and `AWACS`, which
  `veafSkynetIadsHelper.lua:1814` enrols as EW radars, and `SAM elements`, covered by the last line
  of defence. The exclusion is theirs alone: an earlier draft applied it to the whole `Air`
  attribute, which was wrong — a fighter or a transport belongs to no Skynet network. They all stay
  in the graph as relays regardless.
- **Ground detection ranges stay well under the radio range** on purpose, so that what limits the
  network is the sensing, not the plumbing. **Aeroplanes are the deliberate exception** at 30 km
  against a 20 km radio: an aircraft sees further than it can tell, so it has to close on the ground
  network to pass the word.

A consequence worth knowing: **a player flying for the network's coalition becomes a spotter**, and
a friendly patrol feeds the ground defence. Decided on 2026-09-21, and judged desirable.

Each unit draws its own range **once for the mission**, ±20 % around the table value. Drawing per
attempt would make the limit flicker — the same reason Skynet draws its last-line radius once per
site.

**DCS exposes no JTAC attribute.** David's original sketch had a JTAC seeing furthest; there is no
way to express that from attributes alone, so the first version does not distinguish them. If it
matters, the way in is a list of unit names supplied by the mission maker — noted, not designed.

## What it costs, measured

Run with `lua test/lua/bench_spotter_network.lua`. Three layouts, all on a 300 × 300 km theatre:
**uniform** (units anywhere, the worst case for connectivity), **clusters** (groups of a dozen
scattered across the map), **front** (the same groups confined to a 200 × 40 km band, which is what
a mission built around a contested area looks like).

Measured on **Lua 5.1.5**, the interpreter DCS runs. Lua 5.1 came out about 1.6× slower than 5.5 on
this workload, which is why the figures below are worth having rather than the ones an ambient
interpreter would give.

### Timings

All of it **at the settled 20 km range**, which matters: the sweep and the patch are O(edges), and
widening from 10 to 20 km roughly triples them. An earlier draft of this table was measured at
10 km and understated both by a wide margin.

| layout | units | edges | comps | largest | build | sweep | move check | patch, lists | patch, sets |
|---|---|---|---|---|---|---|---|---|---|
| uniform | 500 | 1 710 | 4 | 495 | 5.7 ms | 0.2 ms | <0.1 ms | 1.0 ms | 0.7 ms |
| uniform | 2000 | 26 678 | 1 | 2 000 | 86 ms | 1.75 ms | 0.15 ms | 10.3 ms | 9.7 ms |
| clusters | 500 | 4 552 | 28 | 48 | 5.7 ms | 0.1 ms | 0.05 ms | 0.7 ms | 0.7 ms |
| clusters | 2000 | 35 164 | 36 | 360 | 86 ms | 1.55 ms | 0.15 ms | 11.3 ms | 9.3 ms |
| front | 500 | 15 471 | 3 | 308 | 7.3 ms | 0.75 ms | 0.05 ms | 2.3 ms | 0.7 ms |
| front | 2000 | **230 577** | 1 | 2 000 | 113 ms | 10.6 ms | 0.15 ms | **86 ms** | **13.7 ms** |

**The cost the PRD called "the whole problem" does not exist.** A full rebuild of the worst case —
2 000 units on a dense front, 230 577 edges — is 113 ms, run once per 30 s loop. A sweep, one alert
crossing that whole network, is 10.6 ms. Spatial bucketing is not needed at any mission size we
ship, and that whole chapter of the PRD can be dropped.

**The movement check is free**: 0.15 ms for 2 000 units. It is fair to record that the three staged
loops therefore optimise almost nothing measurable; they were chosen for correctness of
dimensioning rather than for cost, and they do no harm.

**Hold the adjacency as sets, not lists** — `adjacency[i][j] = true` rather than an array of
indices. Removing a back-edge from a list means scanning it, so patching costs O(degree²) per node,
and on the dense front that is the single most expensive operation in the whole mechanism: **86 ms**
against **13.7 ms** for the same work on sets, a factor of six. Everywhere else the two are within
noise, so there is no case for lists. The sweep pays a little for `pairs` over `ipairs` and it does
not show at this scale.

That last column is also the answer to *"what does a combat zone spawning a hundred units cost?"* —
it is exactly the measurement, 100 units re-edged against 2 000, and the answer is **13.7 ms** with
sets on the worst layout we could build.

### What the shipped code actually costs, measured 2026-09-21

The table above measures a **model** of the graph, written before the code existed and indexing its
nodes by integer. The implementation keys everything by **unit name**, because that is what a DCS
mission hands us, and string keys are not free. Re-measured against `veafSkynet.reEdgeSpotterNode`
itself, on the same layout and the same interpreter, with `lua test/lua/bench_spotter_shipped.lua`:

| operation | model bench | shipped code |
|---|---|---|
| full build, 2 000 units, ~234 000 edges | 113 ms | **~205 ms** |
| re-edge 100 units | 13.7 ms | **~19 ms** |

Both accepted. The build is paid once per class loop at mission start — three smaller spikes at 10,
20 and 30 s rather than one — on a layout twice the size of any mission we ship, and Skynet's own
enrolment already runs at that moment.

A parallel array of nodes, scanned with `ipairs` instead of `pairs` over the hash, was measured at
181 ms against 253 ms on the same run, about 28 %. **Not taken:** it needs removal bookkeeping
(swap-remove plus an index map), which is precisely the individual-element removal the set
representation exists to avoid. Seventy milliseconds once at mission start does not buy that back.

The conclusion of the section is unchanged and now rests on the real code rather than on a model:
spatial bucketing is not needed at any mission size we ship.

### Connectivity, which is the real finding

The same 1 000-unit mission, varying the radio range. **Averaged over 8 draws** — a single draw
moves the reach by fifteen points, which is not a basis for choosing a default.

| layout | 5 km | 10 km | 20 km | 30 km | 40 km |
|---|---|---|---|---|---|
| uniform | 0.8 % | 17.5 % | **100 %** | 100 % | 100 % |
| clusters | 2.5 % | 5.1 % | 8.8 % | 28.2 % | 71.7 % |
| front | 13.0 % | 61.1 % | **100 %** | 100 % | 100 % |

Read as: the share of the mission's units reachable within the largest connected pocket. An alert
never leaves the pocket it starts in.

**At the 10 km the PRD proposed, the network barely exists on most layouts.** On scattered clusters
it reaches 5.1 % of the mission — an alert stays inside the group that raised it and reaches nothing
else. It only does real work on a dense front, where it reaches 61 %. The network percolates sharply
between 10 and 20 km, and **clusters never fully connect at any range tested**: at 40 km they still
top out at 72 %, which is the honest limit of the idea on a mission whose contents are spread thin.

Crossing times for the largest pocket, at the settled 3 600 km/h — so a hop takes range ÷ speed,
20 s at the default range:

| layout | range | hops | end to end |
|---|---|---|---|
| front | 20 km | 12.4 | **247 s** |
| uniform | 20 km | 22.9 | 457 s |
| clusters | 40 km | 12.8 | 510 s |

Holding the speed rather than the period makes the crossing time depend on the pocket's **size on
the map**, not on the hop length, which is the point: widening the radio range no longer smuggles
in a faster alert.

Sanity check on the default: four minutes to cross a fully connected 200 km front, against roughly
thirteen minutes for a fighter to fly it. The alert keeps a comfortable lead, which is the whole
purpose.

## What the measurement changes

**1. The default radio range is 20 km, not 10** (decided 2026-09-21). At 10 km the feature works
only on a dense front, and does almost nothing on any other layout, without anyone being able to
tell why. 20 km is defensible for a vehicle-mounted tactical VHF set, and it is where the network
stops being a collection of islands on every layout but the most scattered one.

**2. The propagation setting is a speed, not a period** (decided 2026-09-21). Range and period are
coupled: a hop
covers the radio range, so doubling the range at a fixed period doubles the alert's speed. Exposing
both separately means a mission maker who widens the range silently doubles the propagation speed.
Exposing **km/h** instead, with the period derived as range ÷ speed, keeps the three settings agreed
on and removes the trap. At 3 600 km/h — four times a penetrating fighter — a 20 km range gives a
20 s period.

**3. Spatial bucketing is off the table**, and the PRD text saying otherwise should go.

## Settings

Three keys under `modules.SKYNET`, per the decision of 2026-09-20:

| Key | Default | Why exposed |
|---|---|---|
| enabled | **false** | changes the balance of every existing mission; opt-in |
| radio range | **20 km** | decides whether the network is connected on *their* map |
| propagation speed | **3 600 km/h** | decides the lead the alert takes over the aircraft |

Both defaults confirmed on 2026-09-21. The hop period is derived, not set: range ÷ speed, so 20 s
at these values, and widening the range slows the hops instead of silently doubling the speed.

Everything else stays a constant: detection period, the three graph periods, movement threshold,
the 10 % margin, the 3-beat tolerance, the heartbeat period and the forget delay. These are
stability and cost values that nobody can set without measuring, and each exposed key is a contract
to document, validate and keep.

Off by default carries an obligation, or this becomes the `ewr` option all over again: the release
notes must say the feature exists, and a demonstration mission must ship with it on.

## Observability

A status page in the log, on the model of Skynet's and toggled the same way: nodes and edges, live
alerts with their aircraft and age, spotters that acquired this cycle, sites woken and by which
alert.

This matters more here than usual. Once this ships there will be **three** reasons a site can light
up — an EWR, the last line of defence, or a spotter — and an unexplained wake-up is the single most
common report on this subject. Without a trace the question is undecidable.

A game-master view on the map is in scope by David's decision, as **its own ticket**, so it can slip
without holding the mechanism.

**The map view is where redrawing can genuinely come in bursts** — every alert, every cancellation,
every graph pass is a reason to redraw, and a combat zone spawning changes hundreds of markers at
once. It must coalesce, on the pattern `veafRadio.refreshRadioMenu` uses (`veafRadio.lua:613`):

```lua
if not veafSkynet.spotterRedrawScheduled then
  veafSkynet.spotterRedrawScheduled =
    veaf.scheduleFunction(veafSkynet._redrawSpotterView, {}, timer.getTime() + 1)
end
```

with `_redrawSpotterView` clearing the flag as its first act, exactly as
`veafRadio._refreshRadioMenu` does at line 631. A hundred calls in a row then produce one redraw.

## Tests to write

- Latch: reports once on acquisition; silent while held; re-arms after 3 beats, not 2.
- Distance margin: an aircraft orbiting between range and range × 1.1 produces one report.
- Line of sight: masked at acquisition → no report; masked at loss → contact lost.
- Propagation: reaches units k hops away after k periods, and no sooner.
- Fronts: two spotters in one pocket merge; two in separate pockets stay independent.
- Cancellation: extinguishes along the path; a lost cancellation is caught by the heartbeat net.
- Ordering: a cancellation arriving before its alert does not leave a site holding a contact.
- Hand-over: no `reportContact` while the aircraft is outside the envelope; exactly one when it
  enters. **Assert the wiring, not just the handler** — that the periodic loops are actually
  scheduled and that the helper subscribes, which is the defect class that shipped green in August.
- Graph: a unit that dies leaves the graph at the next pass; one that spawns joins it.
- Map view: a hundred redraw requests in a row schedule **one** redraw, and the flag is cleared so
  a later request still works — a coalescing guard that never re-arms is worse than none.

## Answered on 2026-09-21

All four points the first draft left open are settled, and folded into the text above.

1. **Radio range defaults to 20 km**, not the 10 km the PRD carried.
2. **Propagation is expressed in km/h**, the hop period derived as range ÷ speed.
3. **Aircraft detect.** The first draft excluded the whole `Air` attribute on the grounds that
   Skynet already senses through it; that only holds for `AWACS` and `EWR`. Aeroplanes 30 km,
   helicopters 15 km.
4. The detection ranges are reasoned, **not sourced**, and that is what they will remain. The scale
   was put to David on 2026-09-21 and drew no objection beyond the aircraft line, so it is settled
   and should not be reopened without a reason from play.

## Still open

Nothing. The next step is implementation, on the breakdown in the PRD.
