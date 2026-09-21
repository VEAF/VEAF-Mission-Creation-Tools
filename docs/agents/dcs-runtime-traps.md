# DCS runtime traps — things that raise no error and cost you an afternoon

Read this before writing anything that **places, delays, activates or lights up** something in a
mission. Everything here is a measured value with the date it was measured and the mistake it caused.
Nothing here is inferred from reading DCS's Lua: this repository has been wrong that way more than
once, and each time the error looked like working code.

Companion pages, each deeper on one subject:

- [`dcs-coordinates.md`](dcs-coordinates.md) — `x`/`y`/`z` mean different things in a mission table
  and in the runtime API. **The single most expensive confusion in this repository.**
- [`module-initialisation.md`](module-initialisation.md) — what is loaded when, and in what order.
- [`../exploration/DCS-UNATTACHED-PLAYER-ROLES.md`](../exploration/DCS-UNATTACHED-PLAYER-ROLES.md) —
  what a game master is, from the scripting side.
- [`../exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md`](../exploration/DCS-HOOK-ENVIRONMENT-BOUNDARIES.md)
  — what the hook environment can and cannot reach.

**Adding to this page is the point.** When a DCS behaviour surprises you, write the measurement here
rather than the conclusion: the value, the date, and what it broke.

## Spawning and timing {#spawning}

### A late-activated group is fully visible to the scripting API before it is activated

**The most expensive one on this page, and the only one here that was a shipped product bug.**

Measured **2026-09-21**, on a group whose activation was still thirty seconds away:

| Asked | Answer |
|---|---|
| `coalition.getGroups(side, category)` | **returns it** |
| `Group:isExist()` | **true** |
| `Unit:isExist()` | **true** |
| `Unit:inAir()` | **true** |
| `Unit:isActive()` | **false** — the only one that tells the truth |

So `lateActivation = true` hides a group from the map and from nothing else. Anything sweeping
`coalition.getGroups` and filtering on `isExist()` or `inAir()` will treat an aircraft DCS has not put
in the world as a live, airborne contact.

**Always test `Unit:isActive()`** when sweeping for real units. `veaf.isUnitAlive(unit)` already does
it (`unit:isExist() and unit:isActive()`) and is the right thing to call.

*What it cost:* `veafSkynet.listHostileAircraft` reported a parked, unactivated intruder as an
airborne contact, so the spotter network relayed it across the map and woke real SAM sites for an
aircraft that did not exist. Late activation is ordinary in real missions, so this was not a rig
artefact — it was reaching every mission using the feature. Found by David watching the F10 map and
saying *"on me dit qu'il voit l'intruder mais il n'est même pas encore spawné"*.

### `start_time` on an aircraft group does not delay its spawn

Measured **2026-09-21**. A group with `start_time = 90` in the mission table was **airborne at
t = 9 s**. The field does not hold an air group back.

`lateActivation` is not the answer either, for the reason above: the group stops being *drawn* but
never stops being *seen*. **The only delay that is real is not putting the group in the mission at
all** and building it with `coalition.addGroup` from a scheduled function — before that call the
aircraft does not exist in any sense.

*What it cost:* two failed attempts in a row at the same requirement, in front of the person who had
asked for it.

### Activating a Skynet IADS undoes anything you forced beforehand

Measured **2026-09-21**. `veafSkynet.delayedActivate` → `SkynetIADS:activate()` **rebuilds the radar
coverage**, and building coverage calls `setToCorrectAutonomousState()` on every site. So any state
forced before the activation is silently overwritten.

Concretely: a `resetAutonomousState()` scheduled at t = 10 s left every battery `LIVE/autonomous`
again by t = 64 s. The same call at t = 40 s held for the whole mission.

**Schedule anything that fixes IADS state after the activation, not after the enrolment.** The two
are not the same moment.

## Air defence {#air-defence}

### A SAM site with no early-warning radar is not dark — it is permanently lit

Measured **2026-09-21**, and it is the opposite of the intuition. A Skynet SAM site is built with
`isAutonomous = true` and an autonomous behaviour of `AUTONOMOUS_STATE_DCS_AI`
(`skynet-iads-compiled.lua:3014`). A site is autonomous exactly when no valid parent radar covers it —
so removing every EWR hands **all** of them to the DCS AI, which lights everything up, all the time.

*What it cost:* a test rig designed around *"no EWR, so the only way to wake is the relay"*, which
delivered every battery lit from the first second, control battery included. The design had to be
thrown away.

### Only two unit types carry the `EWR` attribute

Measured **2026-09-21** against `src/scripts/veaf/dcsUnits.lua`: `55G6 EWR` and `1L13 EWR`. Nothing
else. There is **no short-range early-warning radar** — so you cannot build a network whose EWR
parents a battery without also seeing everything the battery would.

### A battery lights up only when the contact is in *its own* envelope

So staggering wake-ups along a line means spacing the batteries **further apart than they can shoot**.
Measured **2026-09-21**: three Kub sites 15 km apart woke in the *same second*, because a Kub engages
out to ~24 km and the intruder entered all three envelopes at once.

The constraint bites because the spotter network's radio range is 20 km: spacing Kubs 25 km apart to
separate them would push them past the radio range and split the network into isolated pockets. The
two only fit with a short-range SAM — an Osa (~10 km) at 15 km spacing wakes each on its own.

### A fast, level aircraft is classified as a HARM — and that is deliberate

Measured **2026-09-21**: an F-15C flying a straight, level demonstration run at **804.88 kt** was
identified by Skynet as an anti-radiation missile, and the SAM sites went into evasion and shut down —
which silently defeated the demonstration they were there to give.

Not a bug, in Skynet or here. Its test is `groundSpeed > 800 kt` **and** at most two changes of
flight path, and `documentation/tactics.md` states the reasoning: a radar operator cannot read a
contact's type, so real systems classify from the track. Identification is probabilistic on top of
that — `harm_detection_chance` per radar type, combined when several radars see the same track.

**What this costs you when building a mission:** an aircraft meant to be seen and engaged must not
look like a HARM. Keep it **below 800 kt** and give its route a **change of altitude** — one dip in
the middle is enough, since a dead-level run has zero path changes and therefore passes the
flight-path half of the test. Note that DCS lets an aircraft accelerate well past the speed set on
its waypoints, so the altitude profile is the reliable half: the run above was given 200 m/s
(≈390 kt) and flew at 804.

The documentation says the two conditions exist to avoid false positives *"for example a fighter
flying very fast"* — which is exactly the case that still trips, because the guard only catches a
fast fighter that **manoeuvres**. David's call on 2026-09-21 was to leave Skynet alone and adapt the
mission, so this is written down rather than filed.

### Half the obvious "forward observers" are blind

`veafSkynet.SpotterUnitTable` is walked in order and the **first** matching row wins, and
`SAM elements` (range 0) comes before `MANPADS` (10 km). Resolved against `dcsUnits.lua` on
**2026-09-21**:

| Unit | First row it matches | Sight |
|---|---|---|
| `SA-18 Igla-S manpad` | `MANPADS` | 10 000 m |
| `ZSU-23-4 Shilka`, `Roland ADS` | `SAM elements` | **0 — blind** |
| `Kub 1S91 str`, `Osa 9A33 ln` | `SAM elements` | **0 — blind** |
| `Ural-375` | `Unarmed vehicles` | 3 000 m |

An air-defence vehicle looks like the obvious spotter and sees nothing. A truck sees further than a
Shilka.

## Players, roles and the map {#players}

### A game master **is** coalition-scoped for map marks

Measured **2026-09-21** by David, with one `markToAll` and one `markToCoalition(RED)` marker placed
side by side:

| Role taken | Sees |
|---|---|
| Game master **blue** | the `markToAll` marker only |
| Game master **red** | both |

So `trigger.action.markToCoalition(..., coalition.side.RED, ...)` reaches a **red** game master and is
invisible to a blue one. Do not infer from *"a game master has no group"* (true, and why
`USAGE_ForGroup` radio commands never reach him — see the roles page) that he has no coalition either.

*What it cost:* a false bug report against working code, and very nearly a "fix" to a drawing path
that was correct all along. The only defect was sending someone to watch a red network from the blue
side.

### `net.load_mission` is a no-op in single player

Present, `isServer()` is true, and calling it from the menu returns nil and loads nothing (ED: server
only). So an unattended harness cannot load a mission in SP — a human loads it, or you drive a server.

## Events and objects {#events}

### Scenery deaths do not look like unit deaths

`event.pos` is nil, `isExist()` is false while `getPosition()` still answers, and `getName()` returns
the numeric `id_`. Anything walking death events has to special-case scenery or it drops the
destruction silently.

### `Group:destroy()` is deferred

The destroyed groups still appear in `coalition.getGroups` within the **same** call and are gone a few
seconds later. A verification that reads back immediately will disagree with itself — the quirk
behind #946/#947.
