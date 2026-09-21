# FIX-SPOTTER-NODES-ARE-GROUPS — the spotter network reasons about groups, not units

Status: ✅ done — read back in game 2026-09-21

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
| 01 | [A group's profile, and its median point](tickets/01-a-groups-profile-and-median-point.md) | ✅ done |
| 02 | [Detection and latches keyed by group](tickets/02-detection-and-latches-by-group.md) | ✅ done |
| 03 | [The graph, the propagation and the hand-over keyed by group](tickets/03-graph-propagation-and-handover-by-group.md) | ✅ done |
| 04 | [The view draws one shape set per group](tickets/04-the-view-draws-one-shape-set-per-group.md) | ✅ done |
| 05 | [Read it back in game](tickets/05-read-it-back-in-game.md) | ✅ done |

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
