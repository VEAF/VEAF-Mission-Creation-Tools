# FEAT-SPOTTER-DEMO-MISSION — a mission that proves the word travels

Status: ✅ done — 2026-10-05. Every ticket done; ticket 05's walkthrough was built, committed and · archived 2026-11-24
validated by David on 2026-09-21. Its README was dropped: the feature has since been seen working in
four missions, so a walkthrough guide would serve nobody (David, 2026-10-05).

Origin: David, 2026-09-21, reading what `verify-mission-c` check 13 would have measured:

> *"l'idéal serait que tu fasses une mission de démo pour ça, avec dcs-bridge pour qu'on puisse
> tester avec"*

## Why check 13 could not answer its own question any more

`FEAT-SPOTTER-NETWORK` left exactly one debt: an in-game reading. It was written as check 13 of
`verify-mission-c`, and measuring that mission's contents showed the check had become
**indiscriminate** — killed by the lot that had just unblocked it.

| | Measured |
|---|---|
| red units able to spot in `verify-mission-c` | **two Ural-375 trucks**; the EWR and the three SA-6 are excluded from spotting by design |
| a truck's sight range | **3 km** |
| those trucks → nearest SA-6 | **8.9 km** |
| last-line-of-defence radius, shipped on by `FIX-SKYNET-HELPER-AND-VENDORING` | **10–15 km** |

Getting seen by a truck means flying within 3 km of it, hence 6–12 km from the battery — **inside its
own radius**. The battery would light up by itself and the `woke:` line would prove nothing.

## Two facts that killed the first two designs

Both read in the code rather than assumed, and both worth keeping: they are the reason the rig looks
the way it does.

1. **A battery with no EWR is not dark, it is permanently live.** A SAM site is built with
   `isAutonomous = true` and `AUTONOMOUS_STATE_DCS_AI` (`skynet-iads-compiled.lua:3014`), so with no
   parent radar it hands itself to the DCS AI and lights up. "No EWR, so the only way to wake is the
   relay" delivers the exact opposite: everything lit from the first second, control included.
2. **The site's own state cannot attribute the wake-up**, and the only thing that could —
   `spotterStatusWakeUps` — was **drained on every status cycle**, by a pair of assignments that sat
   *outside* the `if debugFlag` test. So the only trace that the feature had ever worked lived for at
   most thirty seconds, and reading it from outside raced the drain.

Fact 2 is a product defect before it is a testing problem: asked *"did the spotter network wake
anything on the server last night"*, nobody could answer. Ticket 01 fixes it, and the rig is then
trivial.

## Tickets

| # | Ticket | State |
|---|---|---|
| 01 | [A durable wake-up history, and a drain that only drains what it printed](FEAT-SPOTTER-DEMO-MISSION.md) | ✅ done |
| 02 | [The rig mission, and its geometry](FEAT-SPOTTER-DEMO-MISSION.md) | ✅ done |
| 03 | [An opt-in smoke suite that reads it](FEAT-SPOTTER-DEMO-MISSION.md) | ✅ done |
| 04 | [Check 13 says it no longer discriminates, and points here](FEAT-SPOTTER-DEMO-MISSION.md) | ✅ done |
| 05 | [The demonstration layer](FEAT-SPOTTER-DEMO-MISSION.md) | ✅ done |

David's sequencing, 2026-09-21: the discriminating rig first, then the demonstration; and within the
demonstration, bridge-driven before flyable.

## What the rig does not prove, said out loud

It proves **the report travelled and named the right battery**. It does not prove the battery went
*from dark to live because of it*: with no EWR the batteries are autonomous and already live, and the
hand-over records the wake-up all the same. Making a battery genuinely dark needs an EWR, and an EWR
that covers it may also be the one that informs it — so that half belongs to ticket 05 and to a human
reading the log, not to an automated check.

A rig whose limits are not written down is read as proving more than it does.

## Definition of done

- [x] A durable, attributed record of spotter wake-ups that the status page does not consume.
- [x] `test/veaf-tools/demo-spotter-network/` builds, validates, and ships the bridge.
- [x] `veaf-tools smoke-test --suite spotter` reads it, with a control that can fail.
- [x] `poetry run test-lua` and `poetry run pytest` green.
- [ ] The demonstration layer (ticket 05).
- [ ] The rig run once in DCS, and its reading recorded. **Needs DCS.**

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**a mission built so the answer cannot be mistaken for something else.** `verify-mission-c` check 13 was written to answer *does a spotter report travel to a battery that never saw the aircraft?* and had become indiscriminate three days later, killed by the lot that unblocked it: the only red units there able to spot are two trucks with 3 km of sight, sitting 8.9 km from a battery whose own last-line-of-defence radius is now 10–15 km. Two designs died before this one, both on facts read in the code: a battery with **no** EWR is not dark but permanently live (`isAutonomous = true`, `AUTONOMOUS_STATE_DCS_AI` at construction), and the only record attributing a wake-up to the relay was **wiped every cycle** by a drain sitting outside its own debug test — a product defect before a testing one, since nobody could answer *did the network wake anything last night?*. So: a durable history, a rig with a control battery out of radio reach, and an opt-in `smoke-test --suite spotter`. The demonstration layer and the in-game reading are what is left

## Tickets, in full

## 01 — A durable wake-up history, and a drain that only drains what it printed

Status: ✅ done

### The defect

`veafSkynet.spotterStatusWakeUps` is the only structure that names the spotter relay as the cause of
a site going live. It was wiped by two assignments at the end of `spotterStatusPage()` — placed
**outside** the `if debugFlag` test, so they ran on every cycle whether or not anything had printed.

Three consequences, in order of what they cost:

1. **No trace survives.** *"Did the spotter network wake anything on the server last night?"* had no
   answer and could not have one: the record lived thirty seconds at most.
2. **A mission with debug off filled two tables every cycle and threw them away**, unread.
3. **One coalition's page wiped the other's records.** A mission running red in debug and blue not
   lost blue's records on red's page, so switching blue's debug on later showed an empty first page —
   which reads as *nothing happened*, the one answer a diagnostic page must never give by accident.

### What was done

- **`veafSkynet.spotterWakeUpLog`** — per coalition, oldest first, never drained, capped at
  `SpotterWakeUpLogSize` (200) with the oldest dropped. An **array**, not a set: the page dedupes
  because the same contact is re-reported every 5 s, but a history collapsing two wake-ups two hours
  apart into one line is not a history.
- **`veafSkynet.getSpotterWakeUpLog(coa)`** to read it.
- The drain is now **per coalition, inside the branch that printed it**.
- The page buckets are only **filled** for a coalition that will print them
  (`_coalitionPrintsStatusPage`). Without that, the fix above would let them grow for the whole
  mission on a mission with debug off, since the page is the only thing that empties them.

The history is deliberately **not** behind that test: it is capped, and it is what answers the
question after the fact, when nobody thought to switch debug on beforehand.

### Definition of done

- [x] The history survives a page that drains the bucket — asserted, with the bucket checked empty in
      the same test so it cannot pass because nothing drains at all.
- [x] It is recorded with debug off, and the bucket is not.
- [x] Repeats are kept, the cap drops the oldest, coalitions do not read each other's.
- [x] A coalition that was not printed keeps its records.
- [x] `poetry run test-lua` green.

## 02 — The rig mission, and its geometry

Status: ✅ done

`test/veaf-tools/demo-spotter-network/`, Syria, anchored on the empty-desert point where DCS
reliably processes events. Full reasoning in
[its README](../../test/veaf-tools/demo-spotter-network/README.md).

### The geometry, and why each distance is what it is

| Distance | Why |
|---|---|
| target → `SpotterIgla` = **8 km** | under the Igla's 10 km of eyes |
| `SpotterIgla` → `NetworkSa6` = **10 km** | under the 20 km radio range |
| target → `NetworkSa6` = **18 km** | inside a Kub's firing envelope (~24 km) |
| `ControlSa6` at **60 km** | three times the radio range: unreachable by construction |

**The spotter is an `SA-18 Igla-S manpad`, and that is measured rather than chosen.** The profile
lookup in `veafSkynet.SpotterUnitTable` takes the **first** matching row, and `SAM elements`
(range 0, blind) comes before `MANPADS` (10 km). Resolved against `dcsUnits.lua`:

| Unit | First row it matches | Range |
|---|---|---|
| `SA-18 Igla-S manpad` | `MANPADS` | **10 000 m** |
| `Kub 1S91 str`, `Kub 2P25 ln` | `SAM elements` | 0 — blind, relays only |
| `ZSU-23-4 Shilka`, `Roland ADS` | `SAM elements` | 0 — **unusable as spotters** |
| `Ural-375` | `Unarmed vehicles` | 3 000 m |

The last two rows are the trap: an air-defence vehicle looks like the obvious forward observer and is
blind.

### The last line of defence is off, on purpose

With it on, a dark site keeps a radius drawn **at random between 10 and 15 km**, and `NetworkSa6`
sits 18 km from the target. The verdict would then depend on a dice roll made at mission start. A rig
whose verdict comes from a draw is not a rig.

### Definition of done

- [x] `veaf-tools mission validate .` clean, the mission builds.
- [x] The bridge is injected and present in the built `.miz`.
- [x] `security.disabled: true` at the root — the bridge drives this with nobody at the keyboard.
- [x] No `build:` block committed: a build writes an absolute `scripts_path` into it.
- [x] The built `.miz` carries `getSpotterWakeUpLog` and `LastLineOfDefence = false`, read back out
      of the archive rather than trusted from the yaml.

## 03 — An opt-in smoke suite that reads it

Status: ✅ done

`veaf-tools smoke-test --suite spotter`, two checks over the mission bridge.

| Check | Passes on | Means |
|---|---|---|
| `spotter-relay-reached-the-network-battery` | `woken:` ≥ 1 | a report crossed 10 km of radio and named a battery with no eyes of its own |
| `spotter-relay-did-not-reach-the-control-battery` | `woken:0` | the 60 km battery was never named — the half that lets the first one fail |

### Why a suite of its own rather than more entries in `CHECKS`

They assert on a geometry only this rig carries. In the default suite they would be **two permanent
failures** on every other mission, and a harness whose default run is always red is a harness nobody
reads — which is how the CTLD load gate was missed.

The other option was to fold them in with an expectation that accepts `no-such-site`, and it is
worse: a pass meaning *did not measure* is the green-light-earned-by-accident that module already
warns about.

### Traps respected

- **A check's Lua must return a string.** A Lua number, boolean or table all arrive as `''` over this
  transport, so the count is tagged — `woken:3` — and every expectation rejects `''`.
- **The history, not the page bucket.** Reading `spotterStatusWakeUps` from outside races the drain
  and reports a false negative; ticket 01 exists for that.

### Definition of done

- [x] The two checks are outside `CHECKS`, and a test asserts the two sets are disjoint.
- [x] Both run over `Transport.BRIDGE` — routed to the hook they would answer `veaf-absent` for ever.
- [x] No sentinel and no lost value can pass either of them, swept in a test.
- [x] The two halves disagree on the same reading, asserted — a run where both are green would mean
      the rig measured nothing.
- [x] `TestEveryChunkCompiles` walks **both** suites, so the opt-in one cannot go uncompiled until
      somebody runs it in front of a live DCS.
- [x] `--suite` refuses an unknown name instead of falling back to the default.

## 04 — Check 13 says it no longer discriminates, and points here

Status: ✅ done

Check 13 of `verify-mission-c` was written when the spotter network shipped, and
`FIX-SKYNET-HELPER-AND-VENDORING` made it indiscriminate three days later by turning the last line of
defence on: the only red units able to spot in that mission are two trucks with 3 km of sight, sitting
8.9 km from a battery whose own radius is now 10–15 km.

It is **not deleted**. It still carries readings worth taking in a session — the F10 menu, the
coalition scoping, the game-master case — and deleting the question would lose them. What changes is
that it no longer claims to answer *"does the word travel?"*, and says where that is answered.

### Definition of done

- [x] The check states plainly why it cannot discriminate, with the four measured figures.
- [x] It points at `demo-spotter-network`.
- [x] What it can still answer is kept and marked as such.

## 05 — The demonstration layer

Status: ✅ done — committed and validated by David on 2026-09-21 (`a3fe2438`, `36c9e999`,
`749d24af`); the README dropped on 2026-10-05.

The rig answers the question; it is not something a human enjoys loading. David's sequencing on
2026-09-21 was the rig first, then this — and within this, bridge-driven before flyable.

### What exists now

`test/veaf-tools/spotter-network-walkthrough/`, Syria. A north-south corridor the intruder flies from
end to end, so each spotter acquires it in turn and wakes the battery beside it.

| | |
|---|---|
| `SpotterNorth` / `SpotterCentre` / `SpotterSouth` | `SA-18 Igla-S manpad`, ~10 km of eyes, at −25000 / −40000 / −55000 |
| `SamNorth` / `SamCentre` / `SamSouth` | 2× `Osa 9A33 ln`, **10.3 km** envelope, 5 km south of each spotter |
| `RelayConvoy` | 3× `Ural-375`, 3 km of eyes, relays only, thickens the chain |
| `SamIsolated` | Kub, **25.0 km** envelope, 22 km east — out of the 20 km radio range **on purpose** |
| the intruder | built by `coalition.addGroup` from `mission-script.lua` at t+90 s |

Corridor easting 405386; mission-table coordinates, `x` northing (`docs/agents/dcs-coordinates.md`).

### Decisions taken, with the measurement behind each

- **Osa, not Kub, along the corridor.** Three Kubs 15 km apart woke in the *same second*: a Kub
  engages to ~24 km, so the intruder entered all three envelopes at once. A battery wakes only when
  the contact is in **its own** envelope, so staggering means spacing them further apart than they can
  shoot — which at 25 km would break the 20 km radio chain into separate pockets. Only a short-range
  SAM satisfies both.
- **`SamIsolated` stays a Kub**, because the point it makes is that it *could* fire at 22 km and does
  not. With an Osa it would be silent for two reasons and prove half as much.
- **The batteries are held dark** by no EWR + `coverage_refresh_interval_s: 0` + a reset **polled**
  every 2 s for the first minute. Polled and not timed: the reset must land after
  `delayedActivate` rebuilds the coverage, and a fixed 40 s was both a guess and forty seconds of a
  map covered in lit sites.
- **The intruder is not in the mission table.** `start_time` does not delay an aircraft group at all,
  and `lateActivation` hides it from the map but **not from the scripting API** — see
  `docs/agents/dcs-runtime-traps.md`, which this lot filled.
- **Speed 150 m/s with a dip to 2000 m.** Flying straight and level at 804 kt got it classified as a
  **HARM** by Skynet, which sent the sites into evasion — Skynet behaving correctly on a badly chosen
  intruder. David's call: leave Skynet alone, adapt the mission.

### Where the visual validation stopped

The map view was rewritten to David's specification over the session (grey for inactive, colour for
active; lines rather than arrows because DCS sizes arrowheads at ~8 km; envelopes; node squares;
contact cross). Each round of looking at it found something real, and all of it is fixed:

- the view only redrew on spotter events, so a battery going dark left a stale orange envelope on
  screen for fifty seconds → a **5 s periodic refresh**;
- the detection circle was coloured from `contact.origin`, a memory that outlives the aircraft by
  `SpotterForgetDelay`, so a spotter kept a red circle six minutes after the kill → it now follows
  the **latch**;
- grey was `{0.6, 0.6, 0.6}` and invisible on a sand map → darkened; node squares were sub-pixel →
  1500 m.

**What is left to confirm by eye**, and the reason the session stopped: the cross and the red
detection circle. Every attempt to hold a target still enough to look at it ended with the target
destroyed — and the cause was found only at the end: **the spotters are MANPADS and they shoot.**
Setting weapons hold on the four `Sam*` groups is not enough; the three `Spotter*` Igla groups have
to be silenced too.

### How to resume

1. `dcs-serve` is mine to run (not David's) — from a folder I control, with a key I set. See
   [[dcs-bridge-and-fiddle-setup]].
2. Load `SpotterWalkthrough_<date>.miz`, **Game Master red**, and **reopen the F10 map after
   loading** — scripted drawings do not appear on an already-open map.
3. Weapons hold on **every** red ground group, spotters included, before spawning anything.
4. Spawn a target ~5 km from `SpotterCentre` at 2000 m and check, in order: red cross on the target,
   red solid circle on `SpotterCentre` only, grey dashed circles elsewhere, blue squares on alerted
   nodes, red solid links where the alert travelled, orange envelope on the site that lights up, and
   `SamIsolated` grey throughout.

**Measure from inside the mission, not across the bridge.** A scheduled recorder writing into a
global and read afterwards survives a target that lives thirty seconds; a sequence of `exec` calls
does not, and chasing one cost most of an afternoon. `dcs.log` is better still — it had the answer
(`saw:` / `woke:` lines proving detection worked) while the bridge measurements were saying the
opposite.

### Definition of done

- [x] The corridor, the pockets and the isolated battery, with the geometry measured rather than
      assumed.
- [x] Batteries dark at start, and the wave visibly staggered.
- [x] The map view to specification.
- [x] Seen and validated by David, 2026-09-21 — the contact cross confirmed by eye and the
      detection circle visible in his own screenshot. Getting there needed a product defect
      fixed first: `dropLatchesForVanishedContacts` walked the whole `spotterLatches` table on
      every coalition, so the pass for a side with an empty sky cancelled the other side's
      detections and the two shapes were **unobservable** rather than merely unverified.
- [x] ~~The README this folder does not yet have.~~ Dropped 2026-10-05: the feature has been seen
      working in four missions since, and nobody needs a guide to this one (David).
