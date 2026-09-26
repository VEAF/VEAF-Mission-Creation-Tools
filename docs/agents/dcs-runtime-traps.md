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

**Adding a trap is the point — but not on this page.** The traps that matter to someone building a
mission live in [`known-limitations.yaml`](../../src/python/veaf-tools/veaf_libs/data/known-limitations.yaml),
`kind: dcs`: that file ships in the executable and the MCP action `describe_known_limitations`
serves it, so an agent working without this repository sees them too. The sections below are
**generated** from it — edit the file, then run `poetry run python -m veaf_libs.known_limitations`;
a test fails when this page and the file disagree. When a DCS behaviour surprises you, write the
measurement rather than the conclusion: the value, the date, and what it broke.

Only the traps that concern **writing scripts** rather than building a mission are written by hand,
at the end of this page.

<!-- BEGIN GENERATED from src/python/veaf-tools/veaf_libs/data/known-limitations.yaml -->

## Spawning and timing {#spawning}

### `Disposition.getSimpleZones` honours neither its radius nor its clearance, and is not deterministic {#disposition-getsimplezones-is-a-lottery}

Measured **2026-09-26**.

The undocumented `Disposition` singleton is the only DCS API that knows where the forests are,
so it is what every scenery-aware placement in this codebase rests on. **It proposes points; it
does not answer questions**, and three of its four parameters mean less than they look.

Measured on GermanyCW-v6, `getSimpleZones(point, searchRadius, posRadius, attempts)`:

| Asked | What comes back |
|---|---|
| `searchRadius = 1000` | candidates at up to **2769 m** |
| `posRadius = 183` (clearance) | a candidate **blocked in 12 directions out of 12 at 10 m** |
| the same call, five times in a row | nearest candidate at **1335, 1476, 1404, 1355, 1293 m** — and a sixth found one at **153 m** |

The last line is the one that hurts: the scatter is not noise around a value, it is the
difference between "there is a clearing 150 m away" and "there is nothing within a kilometre".

The *small* query — "is there a patch of 5 m free within 20 m of this point?" — **is** reliable:
12 repetitions on the same points gave 0/12 against 12/12, with identical candidate counts. So
the singleton is dependable as a probe and unreliable as an oracle.
**And it goes blind inside a spawn's call stack.** Probed from within `veafUnits.settleGroup`,
fixed witness points whose truth is 9 blocked out of 15 answer **0 out of 15** — and answer 9 one
second later. It is global, not tied to the group being placed, and the units land exactly on the
coordinates examined (0.0 m of error over 15). Measured and ruled out: a burst of calls, warm-up,
creating or destroying units, the units blocking their own test, the shape of the table passed, a
prior large-radius call, and an exception swallowed as success — all 15 calls succeed and return
candidates. **The cause is unknown.**

**What to do:** Treat it as a source of *suggestions* and verify every point before acting on it, with the small
query above. Draw several times and merge, because one draw misses clearings a second one finds.
Never let the radius or the clearance you asked for stand in for a measurement — bound the result
yourself, on your own criterion.

Above all, **do not query it from inside a spawn flow**: ask in a phase of its own, while nothing
is spawning, and let the spawn consume an answer already settled. Deferring the spawn itself is
not the way out — the group name a spawn returns feeds `veafSkynet.declareSpawn`, convoy routing
and `veaf.readyForCombat`, so delaying creation silently empties all three.

*What it cost:* Three rounds on the same defect, two of them shipped green and inert. Ticket 08 of
FIX-PLACEMENT-IGNORES-SCENERY assumed the **radius** was honoured, so its acceptance test could
never pass and it displaced nothing, ever. Ticket 10 assumed the **clearance** was honoured and
wrote it into a comment — "a candidate is scenery-free by construction" — and translated groups
into the middle of woods; released in 6.25.0, measured inert the same day.

### A late-activated group is fully visible to the scripting API before it is activated {#late-activated-group-is-visible}

Measured **2026-09-21**.

On a group whose activation was still thirty seconds away:

| Asked | Answer |
|---|---|
| `coalition.getGroups(side, category)` | **returns it** |
| `Group:isExist()` | **true** |
| `Unit:isExist()` | **true** |
| `Unit:inAir()` | **true** |
| `Unit:isActive()` | **false** — the only one that tells the truth |

`lateActivation = true` hides a group from the map and from nothing else.

**What to do:** When sweeping for real units, test `Unit:isActive()`. `veaf.isUnitAlive(unit)` already does it
(`unit:isExist() and unit:isActive()`) and is the right thing to call.

*What it cost:* The one shipped product bug on this list: `veafSkynet.listHostileAircraft` reported a parked,
unactivated intruder as an airborne contact, so the spotter network woke real SAM sites for an
aircraft that did not exist — in every mission using late activation.

### `start_time` on an aircraft group does not delay its spawn {#start-time-does-not-delay-an-air-spawn}

Measured **2026-09-21**.

A group with `start_time = 90` in the mission table was **airborne at t = 9 s**. Late activation
is no substitute: the group stops being drawn, never stops being seen (entry above).

**What to do:** The only real delay is not putting the group in the mission at all, and building it with
`coalition.addGroup` from a scheduled function.

*What it cost:* Two failed attempts in a row at the same requirement.

### The mission's `start_time` is on the theatre's clock, with a fixed offset {#mission-clock-is-theatre-local}

Measured **2026-09-24**.

Caucasus 2022-06-29 at 01:28 is pitch dark (sunrise 01:43 UTC there), so not UTC. GermanyCW,
Ramstein 1980-06-01 at 04:58 is dawn with the sun not up: UTC+2 (sunrise 03:28 UTC; +1 would
have put the sun 30 min up). One fixed offset per map — `veafTime.getTimezone()` in game,
`weather_injector/utils/theatre_offsets.py` at build. Not the IANA zone: DCS models no daylight
saving time. GermanyCW was measured in June only; whether DCS keeps +2 in winter is not known.

**What to do:** Write a mission start time in the theatre's local time; the `sunrise…` / `sunset…` weather
variants already do (since FIX-SCRATCH-MISSION-FINDINGS 02).

*What it cost:* Every solar-time weather variant of every v6 mission started 2 to 4 hours early until 02 fixed it.

## Air defence {#air-defence}

### A SAM site with no early-warning radar is not dark — it is permanently lit {#sam-without-ewr-is-lit}

Measured **2026-09-21**.

A Skynet SAM site is autonomous exactly when no valid parent radar covers it, and autonomous
means `AUTONOMOUS_STATE_DCS_AI`: removing every EWR hands **all** sites to the DCS AI, which
lights everything up, all the time.

**What to do:** Give a network that must stay dark an EWR covering its sites.

*What it cost:* A test rig built around "no EWR, so only the relay wakes them" delivered every battery lit.

### Only two unit types carry the `EWR` attribute {#only-two-ewr-types}

Measured **2026-09-21**.

`55G6 EWR` and `1L13 EWR`, nothing else. There is no short-range early-warning radar, so an EWR
parenting a battery also sees everything the battery would.

**What to do:** Plan the network around those two types.

### A battery lights up only when the contact is in *its own* envelope {#battery-wakes-in-its-own-envelope}

Measured **2026-09-21**.

Three Kub sites 15 km apart woke in the *same second*: a Kub engages out to ~24 km and the
intruder entered all three envelopes at once.

**What to do:** To stagger wake-ups along a line, space batteries further apart than they can shoot. With the
spotter radio range at 20 km, that only fits a short-range SAM — Osas (~10 km) 15 km apart wake
one at a time.

### A fast, level aircraft is classified as a HARM — and that is deliberate {#fast-level-aircraft-is-a-harm}

Measured **2026-09-21**.

An F-15C on a straight, level run at **804.88 kt** was identified by Skynet as an anti-radiation
missile, and the SAM sites went into evasion and shut down. Skynet's test is `groundSpeed > 800
kt` **and** at most two flight-path changes (`documentation/tactics.md`), identification being
probabilistic on top.

**What to do:** An aircraft meant to be seen and engaged must stay **below 800 kt** and have a **change of
altitude** on its route — one dip is enough. DCS lets an aircraft fly well past its waypoint
speed (the run above was set to ≈390 kt), so the altitude profile is the reliable half.

*What it cost:* The demonstration the SAM sites were there to give was silently defeated.

### Half the obvious "forward observers" are blind {#air-defence-spotters-are-blind}

Measured **2026-09-21**.

`veafSkynet.SpotterUnitTable` is walked in order and the first matching row wins; `SAM elements`
(range 0) comes before `MANPADS` (10 km):

| Unit | First row it matches | Sight |
|---|---|---|
| `SA-18 Igla-S manpad` | `MANPADS` | 10 000 m |
| `ZSU-23-4 Shilka`, `Roland ADS` | `SAM elements` | **0 — blind** |
| `Kub 1S91 str`, `Osa 9A33 ln` | `SAM elements` | **0 — blind** |
| `Ural-375` | `Unarmed vehicles` | 3 000 m |

**What to do:** Use manpads or ordinary vehicles as spotters, not air-defence vehicles.

## Players, roles and the map {#players}

### A game master **is** coalition-scoped for map marks {#game-master-marks-are-coalition-scoped}

Measured **2026-09-21**.

With one `markToAll` and one `markToCoalition(RED)` marker side by side, a **blue** game master
sees the `markToAll` marker only, a **red** one sees both. A game master has no group (so no
`USAGE_ForGroup` radio command reaches him) but he does have a coalition.

**What to do:** Watch a red network from a red game-master slot.

*What it cost:* A false bug report against working code, and very nearly a "fix" to a correct drawing path.

<!-- END GENERATED -->

## For script developers {#script-developers}

Written by hand: these concern code running in DCS, not a mission someone is building.

### Activating a Skynet IADS undoes anything you forced beforehand

Measured **2026-09-21**. `veafSkynet.delayedActivate` → `SkynetIADS:activate()` **rebuilds the radar
coverage**, and building coverage calls `setToCorrectAutonomousState()` on every site. So any state
forced before the activation is silently overwritten.

Concretely: a `resetAutonomousState()` scheduled at t = 10 s left every battery `LIVE/autonomous`
again by t = 64 s. The same call at t = 40 s held for the whole mission.

**Schedule anything that fixes IADS state after the activation, not after the enrolment.** The two
are not the same moment.

### `net.load_mission` is a no-op in single player

Present, `isServer()` is true, and calling it from the menu returns nil and loads nothing (ED: server
only). So an unattended harness cannot load a mission in SP — a human loads it, or you drive a server.

### Scenery deaths do not look like unit deaths {#events}

`event.pos` is nil, `isExist()` is false while `getPosition()` still answers, and `getName()` returns
the numeric `id_`. Anything walking death events has to special-case scenery or it drops the
destruction silently.

### `Group:destroy()` is deferred

The destroyed groups still appear in `coalition.getGroups` within the **same** call and are gone a few
seconds later. A verification that reads back immediately will disagree with itself — the quirk
behind #946/#947.
