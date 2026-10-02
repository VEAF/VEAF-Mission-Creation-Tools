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

### `Disposition.getSimpleZones` counts vehicles as obstacles, honours neither its radius nor its clearance, and is not deterministic {#disposition-getsimplezones-is-a-lottery}

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

The *small* query — "is there a patch of 5 m free within 20 m of this point?" — **is** reliable
and repeatable: 12 repetitions on the same points gave 0/12 against 12/12, with identical
candidate counts. So the singleton is dependable as a probe and unreliable as an oracle.

**But it counts VEHICLES, not just scenery — and that has invalidated more measurements here
than anything else on this page.** It answers "is there room free here", and a tank occupies
room. Measured in game on 2026-09-26 (GermanyCW-v6), the same points probed twice, seconds
apart, the only difference being whether the group was standing on them:

| group | with its vehicles | group destroyed |
|---|---|---|
| `combatZone_Brocken` EWR, 3 vehicles | **3 / 3 blocked** | **0 / 3** |
| `combatZone_Borkenberge_Hard` S-300, 14 vehicles | **12 / 14 blocked** | **0 / 14** |

Fifteen of seventeen vehicles reported as "standing in trees" were standing in nothing but each
other. A tight SAM battery cannot pass this test wherever you put it, so **any count of "units
in scenery" taken after a spawn is largely a count of groups blocking themselves**. Three such
figures — 81, then 76, then 69 — were published before this was found.

It also explains, and disposes of, a "blindness" reported earlier the same day: probed from
inside `veafUnits.settleGroup` witness points answered "clear" and answered "blocked" one second
later. `settleGroup` runs **before the units exist**; the control ran after they had spawned.
Two different questions, not a singleton that lies.

**So probe where no vehicle of the group exists yet** — which is where `settleGroup` probes
anyway. Measured there, vehicles genuinely under trees on arrival were **22**, not 76, and
**4** after `settleGroup` had done its work.
**The clearance you ask for decides whether it answers at all.** Same point, varying nothing but
`posRadius`:

| asked | 5 | 10 | 20 | 40 | 80 | 120 | 200 | 300 |
|---|---|---|---|---|---|---|---|---|
| candidates over 3 draws | 30 | 30 | 30 | 30 | 30 | 30 | 21 | **0** |

Ask for a group's own footprint — 58 to 486 m on real groups — and it returns nothing, every
time. This is what made `veafUnits.settleGroup` inert: 31 calls in one activation of 25 combat
zones, **one** group translated, 30 giving up with no candidate to examine.

Some places are out of reach entirely: for them it returns **zero at every clearance, down to
5 m**, and no parameter will help.

A blindness inside the spawn's own call stack was reported on 2026-09-26 and **did not survive
remeasurement** the same evening: the same witness points answer the truth from inside
`settleGroup`, before and after its large draws, with 25 zones firing at once. Over 20 groups,
17 get candidates in flight, and replaying the identical queries from a quiet frame recovers
none.

**What to do:** **Use the small query as a probe, and never use the large one to find a clearing.** To find
open ground, sweep the neighbourhood yourself — offsets on rings of growing radius, closest
first — and ask the small query about each point you would use. It is 0.38 ms a call against
12 ms for the large one, and it gives the same answer every time. This is what
`veafUnits.settleGroup` does since FIX-PLACEMENT-IGNORES-SCENERY ticket 12, and what
`veafGrass.findClearBearing` asks about a FARP escort's wanted spot since
FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND ticket 03 — reading that spot off the nearest large-query
candidate never worked: the nearest one measured in game was 43.9 m away.

If you do use the large query, treat what it returns as *suggestions*: verify every point with
the small query, draw several times and merge, ask for little clearance (21 candidates at 200 m,
none at 300 m), and never let the radius or the clearance you asked for stand in for a
measurement.

Moving the query out of the spawn flow is **not** required, and was measured to buy nothing.
Deferring the spawn itself is a trap in its own right — the group name a spawn returns feeds
`veafSkynet.declareSpawn`, convoy routing and `veaf.readyForCombat`, so delaying creation
silently empties all three.

*What it cost:* Three rounds on the same defect, two of them shipped green and inert. Ticket 08 of
FIX-PLACEMENT-IGNORES-SCENERY assumed the **radius** was honoured, so its acceptance test could
never pass and it displaced nothing, ever. Ticket 10 assumed the **clearance** was honoured and
wrote it into a comment — "a candidate is scenery-free by construction" — and translated groups
into the middle of woods; released in 6.25.0, measured inert the same day.

### A grid of scenery probes 50 m apart steps over a copse; 25 m apart it does not {#scenery-probe-grid-steps-over-copses}

Measured **2026-09-28**.

The small `Disposition.getSimpleZones` probe answers "blocked" only where its whole 20 m disc is
covered, so a wood smaller than the gap between two probes can sit between them unseen. Measured
on Caucasus, on an empty mission, 12 points compared with rings probed every 20 m:

| probe spacing | worst error on the clear radius |
|---|---|
| 25 m | −20 / +10 m |
| 50 m | **+130 m** — 170 m promised where a copse stood 60 m away |
| 200 m | **+200 m**, several points |

Costs, same session: **0.15 to 0.17 ms** a probe on an empty Caucasus mission, **190 ms** a call
across `dcs-serve` whatever it carries. On GermanyCW the same sweep ran at about **0.3 ms** a
probe (1.45 M cells in 8 min), in line with the 0.38 ms measured there on 2026-09-26.

**What to do:** Sweep at 25 m where groups are placed, and never read a clear radius off a coarser grid. Batch
thousands of probes per call: the call, not the probe, is what costs.

*What it cost:* The whole-map 200 m pass FEAT-CLEAR-GROUND-AT-AUTHORING first planned would have promised
clearings in woods; ticket 01 measured it before it was built.

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

### Some static types placed without a `shape_name` are refused at mission load, and the object never exists {#static-without-shape-name-is-refused}

Measured **2026-09-28**.

`dcs.log` at load: `ERROR APP (Main): unknown static shape_name, category Fortification, type:
.Command Center` (and `category Warehouse, type: .Ammunition depot`). DCS does not create the
object, and nothing in the mission file, the build or a scripting call says so afterwards.
Many other types spawn without the field (Warehouse, Bunker, Barracks 2, Fuel tank, Tank, aircraft
statics): DCS resolves the shape itself for most types, not all.

**What to do:** Write the `shape_name` the Mission Editor writes — the unit database carries it for every static
(`dcsUnits.yaml`, from the datamine's `ShapeName`). `add_group` writes it, and `validate` reports a
static that lacks it.

*What it cost:* 4 objectives of GermanyCW-v6, placed by the MCP before it wrote the field, missing in game; a combat zone drew 4 elements from 3.

### `StaticObject.getByName` keeps returning a static after its destruction {#destroyed-static-is-still-returned-by-getbyname}

Measured **2026-10-01**.

A static destroyed in game is still found by name: `StaticObject.getByName` returns an object whose
`isExist()` is **false** and `getLife()` is **0**, and which still answers `getCoalition()`.
Measured on Caucasus with a red `Ural-375` static blown up by `trigger.action.explosion` (power 500):
10 s and 70 s after the explosion, both reads gave `isExist=false life=0`.

**What to do:** Never take "found by name" for "still there": test `isExist()` and `getLife() > 0`.
`veafCombatZone.getStandingStatic` does both, and is what the combat zone watchdog and its F10
report now use.

*What it cost:* The combat zone watchdog counted every static it found, so **a zone holding a static never
completed** — and the F10 report kept listing the destroyed targets. Found by the test mission of
FEAT-OBJECTIVE-MISSION-PROMPT, whose static zone stayed open with its truck destroyed.

### An aircraft spawned with a single waypoint and no task lands at the nearest airfield {#aircraft-at-the-end-of-its-route-lands}

Measured **2026-10-01**.

A group whose route is one waypoint at its own position has reached the end of its route the
moment it exists, and DCS does what it does then: it lands. Measured in the Tacview of *Ligne
rouge d'At Tanf*: the Sayqal QRA pair of MiG-29S appeared at **5 262 m**, descended in turns,
flared on runway 090 at 695 m and was gone **four and a half minutes** after appearing — three
scrambles (2 700 s, 3 990 s, 5 160 s), no interception. Nothing raises; the group simply never
does what it was placed for.

**What to do:** Give a flight a route that keeps it busy (an orbit, a `SwitchWaypoint` loop) and a task. A QRA or
an air wave does it for a group tasked `CAP` or `Intercept` whose route engages no aircraft: it is
cloned with the `zone_defense` role (FEAT-AIRCRAFT-ROLES), and the build says so. Any other group
placed this way still lands.

*What it cost:* Three scrambles of a QRA that defended nothing, on a mission built by the MCP's `create_qra`.

### `land.getHeight` never answers below 0: ground under sea level reads 3 m on Syria {#dcs-ground-is-never-below-sea-level}

Measured **2026-10-01**.

The whole Syria map swept every 250 m (12.1 M points, `veaf-tools dcs terrain-sweep`) holds no
height below 0: the sea reads 0, and every point measured where the real ground lies under sea
level reads **exactly 3 m** — Lake Tiberias (real surface about −210 m), the Jordan valley at
Beit She'an, Jericho (about −250 m), the north of the Dead Sea (about −430 m). The real figures
are approximate, from general knowledge; the DCS ones are measured.

**What to do:** Take a ground height from DCS's terrain (`terrain_elevation`), never from a real-world source:
in the Jordan rift the two differ by hundreds of metres, and it is DCS's that the aircraft flies
over.

*What it cost:* None yet — found while sweeping the elevation grid. A briefing that took a target's altitude from a
real-world map would have given a negative figure DCS does not have.

### A static created by script shows on the F10 map even when it is submitted `hidden = true` {#dcs-scripted-static-ignores-hidden}

Measured **2026-09-19**.

Measured by Tripack on a v6 Cyprus mission, from a blue Hornet slot and as Tactical Commander
(#953): the neutral sandbags placed **hidden** in the Mission Editor and touched by no script stay
off the map, while the identical ones a combat zone puts back — removed by deactivating the zone,
recreated by activating it again — are on the map. VEAF submits `hidden = true` to
`coalition.addStaticObject` for them (`test_the_static_the_zone_puts_back_is_still_hidden`), so it
is DCS that does not apply it to an object a script created. Only a static was measured: whether a
**group** recreated by `coalition.addGroup` keeps its hiding is not established.

**What to do:** Keep a decoration that must stay hidden out of every combat zone, or name it so that no zone takes
it over: the editor's own copy is the only one DCS hides.

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

### A player whose side the briefing does not know sees the red pictures, then the blue ones {#briefing-pictures-red-then-blue}

Measured **2026-09-29**.

The mission's briefing pictures are three lists, `pictureFileNameR`, `pictureFileNameB` and
`pictureFileNameN`. DCS's briefing (`MissionEditor/modules/me_autobriefing.lua`) picks the list of
the player's side, and it knows that side only from a unit whose skill is `Player`. With none —
a `Client` slot (a test mission flown from one included), a dynamic slot, a spectator — it shows
**the red list followed by the blue one**. A picture put in both lists, the natural way to "show
it to everyone", is shown twice: seen on GermanyCW-v6, in a case not written down.

Read in DCS's Lua on 2026-09-29, not observed slot by slot. The in-flight and multiplayer
briefing takes its pictures from the engine (`DCS.getPlayerBriefing()`,
`Scripts/UI/BriefingDialog.lua`), whose rule cannot be read: whether a multiplayer pilot in a
red slot gets the red list is **to be confirmed**.

The panel also fits each picture to its own size: a theatre map 1600 px wide is shrunk until its
labels cannot be read. The mouse wheel zooms, which few players know.

**What to do:** Put every picture in `pictureFileNameB` and `pictureFileNameN`, and leave `pictureFileNameR`
empty: whoever DCS cannot place sees each picture once. The cost falls on a red player DCS does
identify: they may get no picture. Keep that for missions whose red classic slots do not need the map
(an arena), and say so in the briefing text.

Against the fitted panel, add zoomed maps after the theatre map, one per area, each with a title.

*What it cost:* Found on GermanyCW-v6, whose briefing showed its map twice, too small to read.

### A departing player's last slot change arrives after DCS has forgotten the player {#player-leaves-slot-after-dcs-forgot-the-player}

Measured **2026-09-30**.

When a player disconnects, DCS fires the hook callback `onGameEvent("disconnect", id)` and then
`onPlayerChangeSlot(id)`, and by that second call `net.get_player_info(id)` returns nil. Measured
on the six VEAF servers' `dcs.log`, 2026-09-29 18:04 → 2026-09-30 17:45: 21 disconnects, 21 slot
changes with no player info, each right after the disconnect of the same id, none anywhere else.

**What to do:** A hook reading the player in `onPlayerChangeSlot` must accept nil, and can tell this ordinary case
from an unexplained one by remembering the ids `onGameEvent` reported disconnecting — which is what
`VEAF-Server-hook.lua` does.

*What it cost:* The VEAF hook logged it at ERROR, once per departure: on private1 it was the first suspect for an
unrelated security defect until its context was measured.

## Radio and frequencies {#radio}

### The text of `Radio.lua` is not the airfield frequencies DCS uses — DCS completes the missing bands {#radio-lua-is-not-what-the-f10-view-shows}

Measured **2026-10-01**.

`Mods/terrains/<T>/Radio.lua` looks like the airfields' ATC frequencies, and holds fewer than DCS
uses. The Mission Editor (`MissionEditor/modules/Mission/AirdromeData.lua`) asks DCS for them with
`DCS.getATCradiosData(radioId)`, which returns bands the file does not hold. Measured on Persian
Gulf: `radio.lua` gives Al Dhafra **one** frequency, 126.5 VHF, and DCS returns **four** — 39.5,
126.5, 251.1 and 4.3, what the editor's airport panel shows; Bandar-e-Jask has `frequency = {}` in
the file and four bands in DCS. Every Persian Gulf entry of `radio.lua` carries VHF only. Where
DCS completes them is not visible in the install.

**What to do:** Take an airfield's frequencies from the reference shipped with the tools
(`veaf_libs/data/airfield-frequencies.yaml`, captured from a running DCS with the editor's own
logic) — through `describe_airfield_channels` / `set_airfield_channels`, or
`veaf-tools content airfield-channels` — never from `Radio.lua`, and never typed by hand.

*What it cost:* The tools' reference was parsed from the text of `Radio.lua`: on Persian Gulf it held no UHF channel
for any airfield, and made the hand-written channel collection — which was right — look wrong.

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
