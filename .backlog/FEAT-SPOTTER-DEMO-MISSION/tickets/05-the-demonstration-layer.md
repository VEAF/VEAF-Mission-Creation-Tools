# 05 — The demonstration layer

Status: 🔄 in-progress — built and running; the visual validation was interrupted on 2026-09-21 and
resumes in a fresh session. **Nothing in this lot is committed.**

The rig answers the question; it is not something a human enjoys loading. David's sequencing on
2026-09-21 was the rig first, then this — and within this, bridge-driven before flyable.

## What exists now

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

## Decisions taken, with the measurement behind each

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

## Where the visual validation stopped

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

## How to resume

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

## Definition of done

- [x] The corridor, the pockets and the isolated battery, with the geometry measured rather than
      assumed.
- [x] Batteries dark at start, and the wave visibly staggered.
- [x] The map view to specification.
- [x] Seen and validated by David, 2026-09-21 — the contact cross confirmed by eye and the
      detection circle visible in his own screenshot. Getting there needed a product defect
      fixed first: `dropLatchesForVanishedContacts` walked the whole `spotterLatches` table on
      every coalition, so the pass for a side with an empty sky cancelled the other side's
      detections and the two shapes were **unobservable** rather than merely unverified.
- [ ] The README this folder does not yet have.
