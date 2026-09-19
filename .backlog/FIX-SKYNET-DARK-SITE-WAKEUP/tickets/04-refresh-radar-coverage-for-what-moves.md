# 04 — Refresh radar coverage for whatever moves

Status: ⬜ ready

## Decision

Settled with David, 2026-09-19: **add a periodic refresh of the EWR↔SAM coverage**, under three
constraints that are part of the decision, not optimisations for later.

## Problem

Coverage — which battery is "under" which radar — is computed geometrically and then treated as if
it never changed. Two holes.

**The incremental rebuild never purges.** When an AWACS has moved 10 NM, `evaluateContacts` calls
`buildRadarCoverageForEarlyWarningRadar`, which routes to
`buildRadarCoverageForAbstractRadarElement` — and that one only ever *adds*, through
`insertToTableIfNotAlreadyAdded`. Only the global `buildRadarCoverage()` clears anything
(`clearChildRadars` + `clearParentRadars`), and there is **no function at all** to remove a single
parent or child. So an AWACS in transit accumulates: it keeps every battery it has ever flown near,
and those batteries keep it as a parent for the rest of the mission — held non-autonomous by a
tutor 300 km away that will never feed them a thing.

The upstream comment says why the mistake was made: *"during runtime it is sufficient to call [the
incremental version], this saves script execution time"*. True for an **addition** — a new SAM, a
fixed EWR. False for an element that **moves**, and the AWACS is the only one it was applied to.

**Mobile SAM sites are refreshed by nothing at all.** The 10 NM mechanism tests
`getmetatable(ewRadar) == SkynetIADSAWACSRadar`, so it covers AWACS and nothing else. A SA-15, a
SA-8 or a Shilka driving in a convoy or a combat zone keeps the parents it had when it spawned,
for the whole mission. VEAF ships a lot of mobile content; only a periodic sweep catches this.

**Measured, and stated honestly**: the accumulation is *not* visible in the reporting log. Over the
24-minute session the three A-50s hold a constant coverage (16, 2 and 0 sites), consistent with
tight orbits — `getDistanceTraveledSinceLastUpdate` measures straight-line distance from the last
reference point, not distance flown, so an aircraft going round in circles never trips the 10 NM
threshold. The defect is established by reading the code. It bites AWACS that **transit**: climbing
to station, changing zone, going home.

## The three constraints

### 1. Sweep what moves, not everything

`buildRadarCoverage()` is O(N²), and each pair tests every combination of the two elements' radars.
On the reported mission — 20 SAM sites plus 8 EWRs, 28 elements — that is roughly 3 000
`isInRadarDetectionRangeOf` calls, ~12 000 radar pairs and ~48 000 DCS API calls, all inside a
single frame. Estimated from the code, not measured in game. A 100-element campaign is twelve times
that.

Two changes take it out of the danger zone:

- **only mobile elements are re-evaluated** — the geometry between two fixed elements never changes.
  M × N instead of N²: 84 pairs instead of 784 here, 300 instead of 10 000 on 100 elements;
- **one position and one max range per element**, not per radar. A site is a point; iterating over
  radar pairs buys nothing and costs the factor of four.

Together: ~80 tests instead of ~12 000 on this mission. At that price the sweep can run every 10 s.

### 2. Only touch the state of what actually changed

`buildRadarCoverage()` ends with `informChildrenOfStateChange()` on every SAM →
`setToCorrectAutonomousState` → for a covered site, `resetAutonomousState()` → **`goDark()`**. Run
periodically as-is, that sends an extinction order to the whole network on every sweep. `goDark`'s
guards protect a site that has acquired a track or has missiles in flight — but **not** one that has
just gone live on designation and not yet locked on. That site gets switched off and has to wait for
the next cycle.

So: compare each site's parent list before and after, and call `setToCorrectAutonomousState` **only
on those whose list actually changed**. It protects the state and cuts the cost further.

### 3. Keep the immediate reaction to an EWR's death

The sweep makes the death-driven path redundant in theory. Keep it anyway: it costs nothing and it
reacts **at once** instead of waiting up to a sweep interval. An EWR killed in a SEAD run has to hand
its batteries their autonomy immediately — that is a moment of play, not a technical detail. Remove
the event path later, only if it ever becomes a nuisance.

## What has to be written

- Individual removal of a parent and of a child radar. Neither exists; today it is all-or-nothing
  through `clearParentRadars` / `clearChildRadars`.
- A per-element notion of "has moved since the last sweep", so fixed elements are skipped outright.
  The existing `SkynetIADSAWACSRadar` distance check is the model, generalised beyond AWACS.
- The sweep itself, its interval settable, surfaced by `veafSkynet`.

## Definition of done

- An AWACS that transits loses the batteries it has left behind, and they revert to autonomous.
- A mobile SAM site's parents follow it.
- A site that is already live and has not changed parents is **not** sent dark by a sweep — a test
  asserts exactly that, and it is the one that would catch a regression nobody would notice in play.
- Killing an EWR still frees its batteries without waiting for a sweep.
- `poetry run test-lua` green, `CHANGELOG.md` updated.
