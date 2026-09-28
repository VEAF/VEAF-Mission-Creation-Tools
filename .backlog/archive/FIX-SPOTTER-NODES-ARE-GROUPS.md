# FIX-SPOTTER-NODES-ARE-GROUPS — the spotter network reasons about groups, not units

Status: ✅ done — read back in game 2026-09-21 · archived 2026-09-28

Origin: David, 2026-09-21, looking at the F10 map of `spotter-network-walkthrough` after spawning two
transport groups to link the isolated SA-6 into the network:

> *"j'ai trouvé un défaut : on considère les unités et pas les groupes"*
> *"je ne parle pas que du dessin, mais aussi de l'algorithme… Gérer les groupes, avec un point
> médian, ça devrait suffire"*

## What he was looking at, measured

Two convoys of eleven vehicles each, parked. Read out of the live graph:

| | Measured |
|---|---|
| graph nodes | **37**, for **10** DCS groups |
| links drawn | **538** |
| draw budget (`SpotterViewMaxShapes`) | **400** |
| each 11-vehicle convoy contributes | 11 nodes, 11 overlapping range circles, 11 stacked squares, **55 internal links** |
| the same graph, one node per group | **10** nodes, at most **45** links |

So the view is **truncated by construction** as soon as a real convoy exists: the links alone exceed
the budget, and everything drawn after them is silently dropped. The picture David saw was a mat of
grey strokes with the demonstration underneath it.

This is not a contrived case. Linking a distant battery into the network with a transport group is
the intended use of the feature — it is what the walkthrough mission's own `RelayConvoy` does.

And it is not only drawing. The graph itself is O(units²): the propagation, the three graph passes
and the re-edging all carry that cost, and eleven vehicles in one parking space are treated as eleven
independent radio stations, which they are not.

## The model

**One node per DCS group.**

- **Position: the median point of the group's live units.** David's call, and it is enough — a parked
  convoy's median *is* where the convoy is.
- **Sight range: the range of the unit that sees furthest.** David's call, 2026-09-21. So a group
  mixing an `SA-18 Igla-S manpad` (10 km) with a `ZSU-23-4 Shilka` (0 — blind, see
  `docs/agents/dcs-runtime-traps.md`) sees 10 km.
- **Speed class: likewise the fastest of its units**, since the class only decides how often the node's
  edges are recomputed.
- `matchSpotterUnitRow` **stays per unit**: it is a type lookup, and it is what the two rules above are
  computed from.

### The approximation, stated rather than discovered later

A group strung out along a road — a convoy on the move over several kilometres — has one median point,
so its sight circle and its radio position are wrong by up to half its length. The error is bounded by
the group's own extent, it is nil for a stationary group, and it is small against ranges of 3–20 km.
Accepted deliberately; the alternative (a node per unit) is the defect this lot exists to remove.

## What it touches

Enumerated from the code rather than estimated — 122 occurrences of the unit-keyed structures in
`src/scripts/veaf/veafSkynetIadsHelper.lua`:

| Area | Functions |
|---|---|
| profile | `getSpotterProfile` (now group → best range, fastest class) |
| enumeration | `listSpotters` (groups, each with its median point) |
| detection | `spotterDetectionBeat` (line of sight traced from the median), `stepSpotterLatch`, `dropLatchesForVanishedContacts`, `forgetSpotter`, `spotterLatches` keyed by group |
| graph | `getSpotterGraph`, `removeSpotterNode`, `reEdgeSpotterNode`, `listSpotterRelays`, `spotterGraphPass` |
| propagation | `getSpotterContacts`, `deliverSpotterMessage`, `emitSpotterMessage`, `spotterPropagationTick`, `forgetStaleSpotterContacts`, `spotterHeartbeat`, `getHeldSpotterAircraft` |
| hand-over | `spotterHandoverPass`, `handOverSpotterAlerts` — this **simplifies**: a Skynet SAM site is a group already |
| reporting | `spotterStatusPage`, `describeSpotterGraph`, `recordSpotterAcquisition`, `recordSpotterWakeUp` |
| view | `spotterViewScope`, `paintSpotterView` — one shape set per group |
| new | a median-point helper; `SpotterMoveThreshold` re-edging now measured on the median |

**The bulk of the work is the tests.** The 178 spotter tests build their situations unit by unit, and
every fixture has to be re-expressed in groups.

## Tickets

| # | Ticket | State |
|---|---|---|
| 01 | [A group's profile, and its median point](FIX-SPOTTER-NODES-ARE-GROUPS.md) | ✅ done |
| 02 | [Detection and latches keyed by group](FIX-SPOTTER-NODES-ARE-GROUPS.md) | ✅ done |
| 03 | [The graph, the propagation and the hand-over keyed by group](FIX-SPOTTER-NODES-ARE-GROUPS.md) | ✅ done |
| 04 | [The view draws one shape set per group](FIX-SPOTTER-NODES-ARE-GROUPS.md) | ✅ done |
| 05 | [Read it back in game](FIX-SPOTTER-NODES-ARE-GROUPS.md) | ✅ done |

Ordered so each one lands green: ticket 01 adds the two primitives without changing a caller, and the
behaviour moves in 02.

**Correction, made while doing it: 02, 03 and 04 are not separable, and were done as one change.**
Read in the code rather than assumed — `paintSpotterView` builds its scope from the **graph nodes**
and its `seeing` from the **latches**. Move the latches to groups while the nodes are still units and
the two keys stop matching: the tests would stay green and the map would be empty. That is the very
failure this repository keeps a note about — asserting the handler instead of the wiring. The tickets
remain as the checklist of the parts.

## Definition of done

- [x] One node per group, positioned at the median of its live units.
- [x] Group sight range = its furthest-seeing unit; speed class = its fastest.
- [x] The numbers pinned by tests: two 11-vehicle convoys are 2 nodes and 1 link, and a convoy draws
      one circle and one square.
- [x] A group that loses a vehicle keeps its contact; one that loses its last gives it up.
- [x] A mixed group (Igla + Shilka) sees 10 km, and an all-blind one sees 0.
- [x] The median approximation written into the module, and into **both** language versions of
      `doc/mission-maker/scripts/veafSkynetIadsHelper.md` — user-facing behaviour changed, so the
      pages say "group" where they said "unit" and now carry the colour table.
- [x] **Every new test checked against a mutated implementation**, including a mutation that puts
      `listSpotterNodes` back to one node per unit: 23 tests catch it, among them each of this lot's
      own. One test of mine was too weak on the first pass and was strengthened.
- [x] `poetry run test-lua` green (49 suites, 199 spotter tests), `stylua` clean. `luacheck` is not
      installed on this machine; the CI Lua gate runs it.
- [x] Re-read in game, on a purpose-built dense mission rather than two convoys: 26 groups, 71
      units, 135 shapes at the busiest against a budget of 400. Legible, and David confirmed every
      shape of the colour rule on the map.

---

## Tickets, in full

## 01 — A group's profile, and its median point

Status: ✅ done

The two new primitives the rest of the lot is built on, delivered **without changing a single
caller**, so this ticket lands green on its own and the behaviour change happens in ticket 02.

### What to build

#### `veafSkynet.spotterGroupMedianPoint(dcsGroup)`

The median of the group's **live** units — `veaf.isUnitAlive`, which tests `isExist()` *and*
`isActive()`, because a late-activated unit answers `isExist()` true and would drag the median to a
place nothing is standing (`docs/agents/dcs-runtime-traps.md`).

Returns a runtime vec3, or nil when the group has no live unit left. **Runtime convention**: `x`
northing, `y` **altitude**, `z` easting — read `docs/agents/dcs-coordinates.md` before touching this.

Median, not centroid, and say which in the code: David asked for a *point médian*. Take the
component-wise median of the live units' positions, which is what a human means by "where the convoy
is" and, unlike a mean, does not get dragged by one straggler. With an even count, the lower of the
two middles — an arbitrary but stated tie-break, so the value is reproducible.

#### `getSpotterProfile` accepts a group

- **Sight range: the range of the unit that sees furthest.** David's call, 2026-09-21.
  `matchSpotterUnitRow` stays per unit — it is a type lookup, and it is what this is computed from.
- **Speed class: the fastest of its units**, since the class only decides how often the node's edges
  are recomputed.
- A group whose every unit is blind gets range 0 and is not a spotter, exactly as a blind unit is not
  one today. Half the obvious air-defence vehicles are blind (`SAM elements`, range 0, wins over
  `MANPADS` in the table walk) — so a group mixing an `SA-18 Igla-S manpad` with a `ZSU-23-4 Shilka`
  must come out at **10 000 m**, not 0.

Keep the unit-taking form working for now, or give the group form its own name; ticket 02 is what
moves the callers.

### Tests

- The median of three units in a line is the middle one; of four, the stated tie-break.
- One straggler 10 km from a parked convoy does not move the median to the middle of nowhere — the
  test that says median rather than mean.
- A group with one dead unit medians over the survivors; with none alive, nil.
- A late-activated unit is excluded from the median.
- Mixed group (Igla 10 km + Shilka 0) → 10 000 m. **Both directions**: an all-Shilka group → 0.
- Speed class of a mixed group is the fastest.

### Definition of done

- [x] Both primitives, with docstrings naming the coordinate convention.
- [x] The tests above, each able to fail — checked by mutating the implementation six ways
      (median→mean, tie-break→upper, alive→isExist, max→min, max→min-non-zero, fastest→slowest)
      and confirming each is caught by the test named for that property. The first pass found a
      weak one: the mixed Igla/Shilka group did **not** pin "the furthest", because a Shilka at 0
      makes a min rule degenerate — a second group of two *seeing* units (4 km + 10 km) does.
- [x] No caller changed, `poetry run test-lua` green (49 suites, 192 spotter tests), `stylua` clean.

---

## 02 — Detection and latches keyed by group

Status: ✅ done

Where the behaviour actually changes. Everything here consumes `listSpotters`, so it moves in one
step or the code is broken in between.

### What to change

- **`listSpotters(coa)` returns groups**, each with its name, its median point (ticket 01) and its
  group profile. A group with no live unit, or with range 0, is not in the list.
- **`spotterDetectionBeat`** iterates groups; the line-of-sight ray is traced **from the median**. The
  memoisation of `seesIt()` per pair on a beat stays as it is.
- **`spotterLatches` is keyed by group name.** So are `stepSpotterLatch`, `onSpotterAcquired`,
  `onSpotterLost` and `forgetSpotter`.
- **`dropLatchesForVanishedContacts`** keeps the coalition filter added by
  `FEAT-SPOTTER-DEMO-MISSION`, now built from the coalition's *group* names. Do not lose it: without
  it no latch survives a beat at all, and it has a test that fails both ways.

### Two things not to get wrong

1. **A group that loses units keeps its latch.** The latch belongs to the group, so losing one truck
   must not release a contact the rest of the convoy still sees. Only the group's disappearance does.
2. **The latch is the live detection state; a contact record is a memory.** That distinction cost a
   spotter six minutes of a red circle on a dead aircraft. It is unchanged by this lot and must stay.

### Tests

The existing beat and latch suites are re-expressed in groups. Add:

- An 11-unit group latches **once**, not eleven times, and raises **one** alert.
- A group loses a unit: the latch survives. It loses its last: the latch goes and a cancellation is
  emitted.
- Line of sight is traced from the median: a group whose median is behind a ridge does not see, even
  when one of its units would.
- The coalition filter still fails both ways, with group keys.

### What was decided while doing it

Two things the ticket did not foresee, both found by reading the wiring rather than the handlers:

1. **`spotterLatches` is now partitioned by coalition**, not merely filtered by it. `onUnitLost`
   carries a **unit** name on purpose (the group name is unreliable at death time), so it can no
   longer key a latch — and the replacement, *release the latches of a spotter group that has gone*,
   cannot be correct without knowing which side a latch belongs to. A group that no longer exists
   cannot be asked its coalition. The surgical filter was right for a savepoint; the partition is the
   structural fix, and the filter's two-way test survives as a regression guard on the new shape.
2. **`forgetSpotter` is gone**, with its call in `onUnitLost`. Under the group model losing one truck
   must not release the convoy's contact, so nothing in production called it any more and it would
   have been dead code kept alive by a test. Its test is re-expressed on the real path
   (`test_a_latch_released_because_its_spotter_went_re_arms`), and
   `test_a_lost_unit_forgets_what_it_was_watching` is **inverted** into
   `test_a_lost_unit_does_not_release_its_groups_contact` — which is the assertion that pins the
   model. `onUnitLost` still writes the `lostUnits` ledger the vanished-sites sweep reads.

**A contact stays a unit**, deliberately: the cross on the map marks one aircraft and a flight of
four is four aircraft. Only the network's own nodes became groups.

### Definition of done

- [x] `listSpotters` returns groups; detection, latches and forgetting are keyed by group.
- [x] The coalition filter preserved — as a partition, with its two-way control kept.
- [x] An 11-unit group latches **once** and raises **one** alert.
- [x] A group loses a vehicle: the latch survives and is not re-reported. It loses its last: the
      latch goes.
- [x] The line-of-sight ray is traced from the median — one ray per group, not one per vehicle,
      asserted by capturing the point it is traced from.
- [x] `poetry run test-lua` green (49 suites), `stylua` clean.

---

## 03 — The graph, the propagation and the hand-over keyed by group

Status: ✅ done

The part that removes the O(units²), which is the measured defect.

### What to change

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

### The numbers this ticket exists to move

Measured in game on 2026-09-21, on `spotter-network-walkthrough`, with two 11-vehicle transport groups
spawned to link the isolated SA-6 into the network:

| | before | after |
|---|---|---|
| graph nodes | **37** (for 10 DCS groups) | 10 |
| links drawn | **538** | at most 45 |
| draw budget | 400 shapes | 400 shapes |

So the view was truncated by construction: the links alone exceeded the budget.

### Tests

- A graph of 10 groups holding 37 units has **10** nodes.
- Two 11-vehicle groups produce **one** edge between them, not 121.
- A group moving less than the threshold re-edges nothing, even when its units shuffle.
- A relayed contact's `via` names the group that passed it on.
- The hand-over still names the right battery, with the existing wake-up assertions.

### What the code lost, which is the good part

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

### Definition of done

- [x] Nodes, adjacency, contacts, hand-over and reporting all keyed by group.
- [x] The counts pinned: two 11-vehicle convoys are **2** nodes and **1** link, not 22 and 121.
- [x] A convoy shuffling in place is **not** re-edged — asserted as the node position being exactly
      unchanged, because "moved less than the threshold" would pass on a node nothing ever updates.
- [x] `poetry run test-lua` green, `stylua` clean.

---

## 04 — The view draws one shape set per group

Status: ✅ done

What David was looking at when he found the defect: a mat of grey strokes with the demonstration
underneath it.

### What to change

`spotterViewScope` and `paintSpotterView` walk groups. One circle, one square and one set of links per
group, anchored on the median.

The colour rule David settled on 2026-09-21 is unchanged by this lot and must survive it:

| shape | grey | blue | orange | red |
|---|---|---|---|---|
| square | has not been told | was told | — | element of a live battery |
| circle | spotter, nothing seen | — | spotter with a contact in sight | live battery's envelope |

A dark battery draws **no** envelope. Plus a red cross on each held contact, a grey dashed line for a
link, and a solid red line for one that carried an alert.

Two consequences of drawing per group, both of which simplify the code:

- A battery's **square** and its **envelope** now come from the same node, so the `liveSiteUnits` set
  that maps a site's unit names onto "red square" collapses into a plain "is this node a live site".
- The `SpotterViewMaxShapes` truncation warning should stop firing on the walkthrough mission. Check
  it still fires when it should: a warning that can no longer happen is a warning nobody will trust.

### Tests

- An 11-unit group draws **one** circle and **one** square, not eleven.
- Every cell of the colour table above, as the existing view suite already asserts them.
- The truncation warning still fires on a graph built to exceed the budget.

### Definition of done

- [x] One shape set per group: an 11-vehicle convoy draws **one** circle and **one** square.
- [x] The colour rule preserved, its assertions re-expressed in groups.
- [x] The truncation warning proved still reachable —
      `test_the_shape_budget_stops_the_drawing_and_says_so` still passes.
- [x] `poetry run test-lua` green, `stylua` clean.

The set that maps a live battery onto "red square" **did** collapse, and getting there found a
defect the review caught before it shipped: it was keyed by the site's **unit** names while the
square loop looks it up by node name, which is now a **group** name. The lookup always missed, so
**the red square never drew at all**. Proven by drawing the view against a faithful fixture — a real
unit inside the site's group — which produced zero red squares.

The suite could not see it: the fixture handed the Skynet site double a *group* where DCS hands a
unit, so `safeDcsName` returned the group name and the broken lookup accidentally matched. The
fixture now holds a unit, and the test fails when the defect is put back. Keyed by the site's group
name, the unit walk disappears entirely — a Skynet SAM site *is* a group.

`_spotterPoint` split in two, which is the rename that stops the confusion recurring:
`_contactPoint(unitName)` for an aircraft, and the group median for a node.

---

## 05 — Read it back in game

Status: ✅ done — read back in game 2026-09-21

A refactor whose whole justification is a picture nobody could read has to be re-read in the picture.

### Procedure

`dcs-serve` is mine to run, from a folder I control with a key I set, in loopback — see the
[[dcs-bridge-and-fiddle-setup]] memory. Everything except flying and looking is mine.

1. Rebuild and install `spotter-network-walkthrough`, then **remove the `build:` block the build
   writes back into `mission.yaml`** — it carries an absolute path and it has already been committed
   once by accident.
2. David loads it as **Game Master red** and **reopens the F10 map after loading**: a scripted drawing
   does not appear on an already-open map. He *can* toggle the view from the F10 menu — the submenu is
   coalition-scoped, not `USAGE_ForGroup`, so a game master reaches it.
3. Spawn the two transport groups that found the defect — `-transport, armor 0, defense 0, side red` —
   linking `SamIsolated` into the network.
4. Spawn the target **invisible**, not immortal. Measured 2026-09-21, and it is the right design for
   this rig: a site goes live because it was **told**, not because it sees, so `SetInvisible` lets a
   battery light up and show its envelope while never spending its magazine. An immortal target does
   the opposite — `SamCentre` emptied all 12 of its missiles into one, and a site with no ammunition
   never goes live again (`hasRemainingAmmo` false; David spotted it as `noAmmo = 1`). Weapons hold is
   **not** an alternative: Skynet sets ROE back to free whenever it brings a site live, so a hold set
   beforehand does not hold.
5. Read the graph out from inside the mission — nodes, the groups behind them, links — and compare
   against ticket 03's table. Read it in **one** call from a global a scheduled recorder filled;
   a sequence of bridge round trips outlives nothing and cost most of an afternoon.

### What was actually done, and it went further than the ticket asked

Two convoys were not enough to be worth the trip, so a **whole mission** was built for it:
`test/veaf-tools/spotter-network-dense/`, Syria, anchored on Palmyra — 26 groups and 71 units, a
screen of six observation posts over 95 km of front, two clusters packed the way a combat zone is
packed, three air patrols, and a real combat zone absent until activated.

Measured in game on 2026-09-21:

| | per group (measured) | per unit (the old model) |
|---|---|---|
| nodes | **21**, then **26** with the combat zone activated | 57, then 71 |
| links | **65–67**, then **78–83** | 576, then 713 |
| shapes drawn | **103–135** | ~690–855, against a budget of **400** |

So the mission would have been truncated by construction under the old model. David read the map
colour by colour and confirmed each shape, including the **red square and red envelope** of a battery
going live — the one shape that never drew at all before the review fix in `14cfc288`.

Three things learned doing it, each written where it belongs:

- **A red combat zone's radio menu goes to BLUE.** `getRadioMenuCoalition` falls back to the zone's
  *friendly* coalition — the side that attacks it — so a **red** game master sees the `ZONES DE
  COMBAT` root and nothing inside it. Not a defect; it cost a round of puzzlement, and activating
  from the bridge is the right route for a red-side test.
- **The combat zone respawns its groups under generated names** (`[r]-Canyon Platoon#25205`), and the
  graph picks them up as five groups rather than fourteen units.
- **The intruder was spawning at heading 0 with a route running south**, so it flew away, turned
  round, and arrived a minute late — long enough for a measurement window to close on "nobody sees
  it" and for me to raise a false alarm against working code. Fixed in both missions.

### Definition of done

- [x] Node and link counts measured in game, and they match ticket 03.
- [x] The picture is legible at 26 groups, and David says so.
- [x] No truncation: 135 shapes at the busiest, against a budget of 400.

---
