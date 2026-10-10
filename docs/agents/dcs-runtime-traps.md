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

### A helicopter added by script on open ground takes off on its own unless it is `uncontrolled` {#scripted-helicopter-leaves-the-ground}

Measured **2026-10-02**.

Five Mi-8MT added with `coalition.addGroup` on the Kobuleti runway, side by side, watched for
five minutes:

| Group data | What DCS did |
|---|---|
| no route | engine started at once, **hovered 5–12 m up** for five minutes |
| one `TakeOffGround` point | sat cold, engine started at T+80 s, **took off at T+278 s**, landed at T+466 s |
| one `TakeOffGroundHot` point | took off at T+11 s, landed at T+193 s |
| `TakeOffGround` + `uncontrolled = true` | stayed on the ground, engine off |
| category `AIRPLANE` | refused: `Invalid Unit Module: "Mi-8MT"`, no group |

None of this raises an error: the group exists, `isExist()` is true, and a helicopter meant to
sit as a target is gone a few minutes later.

**What to do:** To keep a scripted helicopter where it was put, give it one `TakeOffGround` waypoint **and**
`uncontrolled = true`. Whether the controller's `Start` command then wakes it up is not measured.

*What it cost:* Measured for FEAT-HELICOPTER-SPAWN (DCS-SESSION-TODO R23): the obvious fix — submitting the
group under `HELICOPTER` — would have produced a hovering helicopter.

### A scripted helicopter given a `Land` waypoint lands on the nearest airfield's parking, not on the point {#helicopter-land-waypoint-goes-to-the-nearest-airfield}

Measured **2026-10-02**.

A Mi-8MT added by script on the Kobuleti runway with a waypoint of type `Land`:

| `Land` point | What it did |
|---|---|
| 1.2 km away, at the other end of the runway | passed 291 m from it, came back round, landed **1 678 m from it** on Kobuleti's parking |
| 3 km away on open ground, 2.85 km from the field | passed 193 m from it at 59 m/s, turned back, landed on Kobuleti's parking again |

(DCS-SESSION-TODO R24, R25.) No error: the group exists, it is on the ground, not where it was sent.

**What to do:** Give the helicopter a `Land` **task** (`{ id = "Land", params = { point, durationFlag } }`) on a
turning point instead of a `Land` waypoint.

*What it cost:* The first two readings of `task transport` (FEAT-HELICOPTER-SPAWN).

### A scripted helicopter given a `Land` task in a forest hovers at its edge and never lands {#helicopter-hovers-at-a-forest-edge}

Measured **2026-10-02**.

A Mi-8MT given a `Land` task on a point inside a forest, near Kobuleti, flew to it, slowed, and
then hovered **8 to 34 m above the open field at the forest's edge, 106–121 m from the point**,
for minutes, without touching down (DCS-SESSION-TODO R26, R27; David watching). The same task on
open grass put it down 30 m from its point in 90 s (R28).

**What to do:** Send a helicopter to open ground. `task transport` moves the landing point to a clearing within
300 m when the scenery search finds one, but that search accepts gaps of 10 m, and the DCS call
under it is a lottery (`disposition-getsimplezones-is-a-lottery`).

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

### `world.searchObjects` still finds ground units after their destruction {#destroyed-units-are-still-found-by-searchobjects}

Measured **2026-10-06**.

A volume search (`world.searchObjects(Object.Category.UNIT, …)`) around a garrison destroyed by
explosions keeps returning its units with their coalition, as if they still held the ground.
Measured on Caucasus at Senaki with a red garrison killed by `-shell`: without a filter the zone
stayed contested by red for minutes, two blue M1A2 in it and no live red unit on the F10 map; with
`isExist()` and `getLife() >= 1` tested, the same search right after the last death answered nobody.
Which of the two tests rejects the wrecks was not isolated.

**What to do:** Filter every object a search returns: `isExist()` true and `getLife()` at least 1.
`veafCampaign.holdsGround` does both.

*What it cost:* A campaign zone whose garrison was destroyed could never be captured: the wrecks held it for the
side that had lost it. Found in the first two-mission test of FEAT-MULTI-MISSION-CAMPAIGN.

### `Unit.getByName` answers nil for units that share a name {#unit-getbyname-misses-units-sharing-a-name}

Measured **2026-10-06**.

DCS accepts two units with the same name — it spawns both — but then resolves neither by that name.
On the v6 demo test mission, `[r]-Armored Platoon#10344` held two units both named
`[r]-Armored Platoon#10344 - MBT T-72B` (ids 200108 and 200109): `Unit.getByName` of that name
returned **nil**, and `veaf.findUnitsInCircle`, whose result is keyed by name, returned it once.
A first reading on 2026-10-05 blamed the « [CH] » vehicle pack; the units it could not resolve had
duplicate names.

**What to do:** Give every unit a unique name — `veafSpawnGround` numbers them `<group> - <type> #<n>` since
FIX-DUPLICATE-UNIT-NAMES. And once you hold the object — from `coalition.getGroups`,
`Group:getUnits`, a search — act on the object rather than looking it up again by name, as
`veafSpawn.destroy` (radius) and `veafMove.changeTanker` do since FIX-DEMO-RECETTE-FINDINGS.

*What it cost:* `_destroy, radius 2000` (`-menage`) left both tanks alive at 1 358 m and 1 405 m: the name lookup
missed them, and nothing said so.

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
is DCS that does not apply it to an object a script created. A **group** behaves the other way,
measured on 2026-10-03: a Su-27 pair `hidden = true` in the editor, recreated twice by
`coalition.addGroup` as a QRA, never showed on a blue F10 map (`optview_all`) that did show a
non-hidden red Shilka and red MiG-29S. DCS keeps `hidden` on a recreated group, drops it on a
recreated static.

**What to do:** Keep a decoration that must stay hidden out of every combat zone, or name it so that no zone takes
it over: the editor's own copy is the only one DCS hides.

### An aircraft spawned a few metres above the ground is not lifted: it flies into what stands there {#aircraft-spawned-too-low-is-not-lifted}

Measured **2026-10-03**.

`coalition.addGroup` takes an aircraft's altitude as given. A MiG-21 spawned 15 m above flat
farmland in Caucasus (`_spawn cap, side red, alt 2`) was in the air, hit shrubs and trees within a
second (`HIT` on `SHRUB`, `GREEN_ASH`, `EUROPEAN_BEECH`) and crashed (`PILOT_DEAD`, `CRASH`).
Nothing raises: the spawn succeeds and the aircraft dies.

**What to do:** Spawn an aircraft well above what stands on the ground. Not being under the terrain is not enough.
VEAF floors every aircraft it gives a role (`-cap`, a QRA or a wave defending its zone) at
`veafAircraftSpawn.MINIMUM_CLEARANCE_METRES` (150 m) above the ground under its spawn point, spawn
and patrol alike; the MiST-derived spawner lifts a requested altitude into a band for the same reason.

*What it cost:* `FIX-AIR-SPAWN-ALTITUDE-GUARD` had to choose between refusing and lifting; this measurement is what
settles that refusing only a point under the terrain leaves the crash in place.

### `trigger.smokeColor` and `trigger.flareColor` keys are `Red`, `Green`… — `RED` is nil, and DCS then refuses the call {#colour-enums-are-capitalised}

Measured **2026-10-03**.

Read in game: `trigger.smokeColor` is `Blue=4 Green=0 Orange=3 Red=1 White=2` and
`trigger.flareColor` is `Green=0 Red=1 White=2 Yellow=3`. `trigger.smokeColor.RED` is `nil`, and
`trigger.action.smoke(point, nil)` raises "Parameter #2 (color) missed" — inside a scheduled
function that is a line in `dcs.log` and no smoke. The two tables also disagree from 3 up: smoke 3
is orange, flare 3 is yellow; smoke 4 is blue, and there is no flare 4.

**What to do:** Write the keys as DCS does, and never pass a smoke colour where a flare colour is expected beyond
red, green and white.

*What it cost:* Every coloured smoke and flare asked from a VEAF map marker, and the smokes and flares of `-farp`,
failed this way until `FIX-IN-GAME-SESSION-2026-10-03`; the unit tests compared `nil` with `nil`.

### A Group or Unit object kept in a script follows its id: a group created later with the same id answers for it {#a-dcs-object-is-its-id}

Measured **2026-10-03**.

A DCS object handed to a script is `{ id_ = n }` and nothing more. A combat zone deactivated
(`Group:destroy()`) and activated again respawned its SA-6 under a new name, `#10211` → `#10212`,
with the template's group id, 44, both times. The `Group` object Skynet had kept for `#10211`
then answered `isExist() == true`, `getSize() == 5` and `getName() == "…#10212"`, while
`Group.getByName("…#10211")` returned nil. Nothing raises: the old object simply speaks for the
new group.

**What to do:** Never take "the object I kept still exists" for "the thing I kept still exists". Look it up by
name, or compare the name it answers with the one you stored — which is what the Skynet sweep of
`veafSkynetIadsHelper.lua` does since FIX-IN-GAME-SESSION-2026-10-03.

*What it cost:* The vanished-sites sweep, written to drop a deactivated zone's SAM site from the IADS, kept every
such site for the rest of the mission: one more site per deactivation and reactivation.

### A heavy aircraft spawned on a `SmallSizeFighter` stand (`Term_Type` 100) is moved elsewhere without a word, or seated inside a hangar {#heavy-aircraft-on-a-small-fighter-stand-is-moved-or-clips}

Measured **2026-10-03**.

`coalition.addGroup` accepts the request and raises nothing either way. Three C-130s on GermanyCW,
each asked for the free type-100 stand of one airfield (`parking` = its `Term_Index`), read 10 s later:

| Airfield, stand | Where the C-130 ended up |
|---|---|
| Wittstock #97 | on the stand, 1.8 m off it — **2 m from a `HANGAR_COVERED_02_GREEN`**, i.e. inside it |
| Altes Lager #93 | **1 473 m away**, on stand #67 (type 104) |
| Bremen #13 | **339 m away**, on stand #1 (type 104) |

Type 100 is not Syrian only, as the parking captures of Caucasus, Persian Gulf and Syria
suggested: GermanyCW has some too (Ramstein, Wittstock, Altes Lager, Bremen at least).

**What to do:** Seat an aircraft only on the stand types its airframe fits: the tools offer 68, 72 and 104
(`AIRCRAFT_STAND_TYPES`) and leave 100 out. After spawning on a named stand, read the unit's
position back rather than trusting the stand you asked for.

### `Airbase:getPoint()` lands about a kilometre from the runways' centre {#airbase-getpoint-is-not-the-runways-centre}

Measured **2026-10-08**.

On 13 theatres, the point `getPoint()` returns for an airdrome is 300 m to 1.4 km (median per
theatre) from the middle of its runway thresholds, where the terrain's reference point — what the
Mission Editor and the `dcs-world-schema` reference data give — sits at a median 0 m. Nothing
says so: it is a valid point on the airfield's side. VMCT's airfield positions were captured with
`getPoint()` until FEAT-DCS-REFERENCE-DATA moved them to the reference point.

**What to do:** For "where is this airfield", use the shipped positions (`list_airfields`), which are the
reference points. In game, take a runway's position from `Airbase:getRunways()` rather than
`getPoint()` when the runway is what matters.

### `coalition.addGroup` with the name of an existing group replaces it {#addgroup-with-an-existing-name-replaces-the-group}

Measured **2026-10-08**.

A two-truck group spawned, then `coalition.addGroup` called again with the same group name and three
trucks: one group of that name afterwards, **the same group id**, three units, and the first group's
units gone (`Unit.getByName` nil) — in the same call and three seconds later.

**What to do:** Rebuilding a group under its own name is a replacement, not a duplicate; it is how the convoy merges
its unarmed vehicles back. It cannot carry damage over: the units come back whole.

### `land.getSurfaceType` answers `RUNWAY` for a whole airfield's concrete: taxiways, aprons and stands too {#an-airfields-concrete-is-all-runway-surface}

Measured **2026-10-09**.

Sampled every 20 m over 4 km around Batumi and Senaki-Kolkhi (Caucasus), with the fiddle hook:
all 12 of Batumi's stands and all 70 of Senaki's stand on `RUNWAY`, and `RUNWAY` cells reach more
than 300 m from the runway centreline — 1 059 cells at Batumi where the runway alone (2 070 × 60 m)
makes about 310. A terrain check that accepts `RUNWAY` (`veaf.DRIVABLE_TERRAIN`, kept for the dams
DCS reports as `RUNWAY`) therefore places vehicles on runways, taxiways and parking alike: on
*Kolkhida* mission 1 a Patriot on Batumi's runway and armour on Senaki's.

**What to do:** To keep something off an airfield, refuse the `RUNWAY` surface for each unit's own position
(`veafCampaign.isOnConcrete`), not only for the group's anchor: a group spreads its units around it.

### A client helicopter placed on an aircraft stand is seated elsewhere when the player takes the slot {#client-helicopter-on-an-aircraft-stand-is-seated-elsewhere}

Measured **2026-10-10**.

Two CH-47F (`CH-47Fbl1`) client slots, `TakeOffParking` on `Term_Type` 104 stands of Caucasus, the
unit's `parking` the stand's `Term_Index` (checked against `Airbase:getParking()` in the running
mission: Term_Index 24 is Kobuleti's stand 24, Term_Index 6 Batumi's stand 6). Taken by a player and
read back through the fiddle hook:

| Stand asked | Where DCS seated it |
|---|---|
| Kobuleti #24 | **1 201 m** from the stand, 209 m from the airfield's reference point |
| Batumi #6 (2026-10-09) | 244 m from the stand |

Nothing is raised or logged. The same slots set to `TakeOffGround` 40 m from the stand were seated
exactly there (40 m).

**What to do:** For a helicopter that must start at a given place — inside an airfield's CTLD logistic circle, for
one — use a ground start (`TakeOffGround`, `From Ground Area`) at that point, not a stand. After a
stand start, read the unit's position back rather than trusting the stand.

*What it cost:* A CH-47F on Kobuleti's stand 24, the very centre of the field's 250 m CTLD logistic circle, started
1.2 km outside it: no crate and no troops offered (Kolkhida test mission, R47 item 1).

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

### An AWACS can hold a contact for minutes flagged `DLINK` only, which Skynet does not read {#awacs-contact-radar-flag-comes-and-goes}

Measured **2026-10-05**.

`Controller:getDetectedTargets(Controller.Detection.RADAR)` on an AI A-50 leaves out contacts the
same call without a filter returns. A blue KC-135 82 km from the A-50, at 24 000 ft, was in its
list from t = 6 s but flagged `DLINK` only in every reading up to t = 239 s, and `RADAR` at
t = 269 s — while a C-130 and a second KC-135 spawned next to it, and an E-3A spawned 60 km from
the A-50, were flagged `RADAR` within a minute. Skynet asks for `RADAR` only, so for those minutes the AWACS fed the IADS
nothing about that aircraft. The A-50's radar range, as `getSensors` declares it, is 204 462 m
(55G6: 267 496 m), and Skynet reads it correctly.

**What to do:** Do not read one sample of a contact's detection flag as a property of the radar: read it over
several minutes. Do not count on an AWACS to report a given aircraft to Skynet the moment it
holds it: the same contact can stay invisible to the IADS for minutes.

*What it cost:* Read at t = 6 and t = 78 alone, it looked like "an AWACS only reports datalink contacts", and
was announced as the cause of three blind A-50s (INVESTIGATE-SKYNET-AWACS-BLIND) before a later
reading refuted it.

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

The zero is VEAF's, and deliberate: DCS does give the Shilka and the Osa optics, but `SAM elements`
are covered by Skynet's last line of defence, and a second competing radius would make one of the
two settings dead weight (`veafSkynetIadsHelper.lua`, above `SpotterUnitTable`).

**What to do:** Use manpads or ordinary vehicles as spotters, not air-defence vehicles.

### A CAP flight engages nothing without an `EngageTargets` task, and a task numbered after its endless orbit is never read {#cap-engages-only-through-an-engage-task-before-its-orbit}

Measured **2026-10-03**.

The group's main task `CAP` does not make it fight. Three MiG-29S pairs on GermanyCW, identical
but for the task list of their first waypoint, each with an immortal C-130 orbiting 12 km away
and detected by its lead (`getDetectedTargets`): with `EngageTargets` (`key = "CAP"`, `Air`)
numbered **before** the race-track `Orbit`, the pair fired its first R-77 74 s after it was
activated and four missiles within 3.5 minutes; with no `EngageTargets`, and with the same task numbered **after** the
`Orbit`, both pairs held fire for four minutes at 8.5 km from a target they had detected.

**What to do:** Give every CAP an `EngageTargets` (or `EngageTargetsInZone`) task numbered before its `Orbit`, as
the Mission Editor does when the CAP task is chosen. `create_cap_mission` writes it that way, and
`edit_route add_task` takes `task_position` to insert a task before an orbit instead of appending.

*What it cost:* The on-demand CAPs `create_cap_mission` built before FIX-SCRATCH-MISSION-FINDINGS ticket 17 carried
an `Orbit` alone: they patrolled and never fought.

## Players, roles and the map {#players}

### An `arrowToAll` slides away from its points as the F10 map is panned, and its tip is the first point {#arrow-to-all-slides-on-the-f10-map}

Measured **2026-10-08**.

Observed by David on *Kolkhida* mission 1 (Caucasus, Colchis plain): each assault-convoy arrow,
drawn with `arrowToAll(-1, id, source, target, …)`, was right only fully zoomed in; panned, even
zoomed, it slid away "as if on another plane", about 25 % longer than its axis. Points at `y = 0`
and points at the terrain height (`land.getHeight`) gave the same picture. `circleToAll`,
`lineToAll` and their labels, at `y = 0`, held still.

**The tip is the first point**, not the second: the arrows pointed at their source. MOOSE
(`COORDINATE:ArrowToAll`, `Core/Point.lua`) passes the tip first, and so do `veaf.lua` and the
Skynet spotter tests; the DCS schema shipped in `veaf_libs/data/dcs-schema/dcs-world-api.lua`
says the opposite and is wrong. MOOSE has nothing against the sliding: a plain call, "no control
over other dimensions of the arrow".

**What to do:** Draw a direction with `lineToAll` in the side's colour rather than an arrow — the campaign's axes
since FIX-CAMPAIGN-ARROW-ALTITUDE; the Skynet spotter view had already dropped arrows for their
8 km heads. An arrow that must stay: tip first.

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

### A removed F10 menu entry's id goes to the next entry created, so a menu left open fires the wrong command {#f10-menu-entry-id-is-recycled}

Measured **2026-10-09**.

DCS tracks each `missionCommands` entry by an internal id, not by its position nor its label, and
hands the id of a removed entry to the next entry created. The player's F10 screen is not updated
while it stays open, so a click on what it shows reaches whichever entry now holds the id.
Measured in single player on raw `missionCommands`, mission restarted before each test, clicks
with the mouse, while the player held `TEST MENU > Liste` (A, B, C, D) open:

| Change applied while the list is on screen | Clicked | Fired |
|---|---|---|
| remove A, B, C, D, then add them again, identical | B | **C** |
| remove A, then add E | A | **E** |
| remove A, then add E | B | B |
| remove A, then add X and Y elsewhere; menu reopened fresh | X, Y | X, Y |
| group menu: remove A, then add E | A | **E** |
| remove A, add a command for a group that does not exist, then add E | A | that command |

The ids are one pool for the whole server: a global entry's id went to a command added for another
group. So a stale click can fire **another group's** command, a secured one included, which then
runs with that group's identity.

A freshly opened menu is always right. Reported by players on CTLD and on VEAF menus: both wipe
and rebuild a whole tree on every refresh, which reassigns every id at once. Delaying the rebuild
(CTLD ADR 0015) changes nothing, the stale screen outlives the delay.

**What to do:** Never recreate an entry that did not change: remove only what disappeared and add only what
appeared. Right after each removal, add an inert command for a group id no player can hold: it
takes the freed id, nobody sees it, and a stale click on the removed entry lands on it.

*What it cost:* Wrong F10 commands fired in multiplayer, among them a CTLD smoke instead of a troop embark
(VEAF/CTLD#257).

## Ground AI {#ground-ai}

### A convoy under fire drives on, and its `getDetectedTargets` can stay empty {#a-convoy-drives-through-an-ambush}

Measured **2026-10-08**.

Measured on Caucasus east of Kutaisi, a blue convoy (armed HMMWV, Stryker, two M818) driven along a
road into two BMP-2 and a BTR-80 placed 400 m off it: the ambush opened fire at ~1.3 km and the
convoy **drove on at 10 m/s without firing a round** until its four vehicles were dead. Its group
`getDetectedTargets()` stayed **empty for 45 s under fire**, until one vehicle was left. The same
road with a Bradley in the convoy: an enemy detected at 1 227 m, 10 s before the first shot.
`S_EVENT_SHOOTING_START` carries its target (a convoy unit) and its shooter; some `S_EVENT_HIT` by
shells carry a nameless initiator; a truck's explosion raises `S_EVENT_HIT` on its neighbours with
the truck as the initiator.

**What to do:** Do not wait for DCS to notice: watch for the enemy yourself (`world.searchObjects`, then
`land.isVisible`) and react to `S_EVENT_SHOOTING_START` / `S_EVENT_HIT`, ignoring a same-coalition
initiator. `veafGroundAI`'s convoy watch does it (FEAT-CONVOY-UNDER-FIRE).

*What it cost:* Every convoy of every mission was a sitting duck: the reason for FEAT-CONVOY-UNDER-FIRE.

### A ground group given a new route under fire: only its lead obeys {#a-new-route-under-fire-moves-only-the-lead}

Measured **2026-10-08**.

Alarm state red, ROE open fire and a new `Mission` task set at the first shot on a five-vehicle
convoy: the **lead** turned and drove back within 3 s, and the convoy returned fire, but the rest
of the column stayed where it was — a truck still on the road, destroyed, another damaged. Off
road, the lead itself bogged down at 0.6 m/s on a 9 km straight line across country.

**What to do:** A group moves as one: to make some vehicles leave while others stay, respawn them as their own
group (`coalition.addGroup` where they stand) and route that one. Keep off-road legs short.

### Smoke does not blind DCS's AI {#smoke-does-not-blind-the-ai}

Measured **2026-10-08**.

Three `trigger.action.effectSmokeBig` (preset 7) set between two BMP-2 and their target 350 m away:
the BMPs **kept detecting all three targets and firing** — about 300 hits in the next 60 s, the
rate falling only because their 30 mm HE ran out.

**What to do:** A smoke screen is for the players' eyes, never cover. Use smoke to mark (`trigger.action.smoke`),
as the convoy's call for help does.

### `world.searchObjects` finds no tree {#searchobjects-finds-no-trees}

Measured **2026-10-08**.

A `SCENERY` search of 3 km radius east of Kutaisi returned 117 objects — houses, garages, bridges,
39 light poles — and **no tree**. `land.isVisible` does not account for them either.

**What to do:** Forest cannot be found by script as cover; only terrain (`land.isVisible`) and the towns
(`veafCities`) can. `Disposition.getSimpleZones` knows where forests are, with the caveats of
`disposition-getsimplezones-is-a-lottery`.

### Ground AI does not see an enemy `land.isVisible` says is in sight, and `knowTarget` does not make it {#ground-ai-does-not-see-what-isvisible-sees}

Measured **2026-10-08**.

Two Bradleys halted 1.9 km from a BMP-2 and a BTR-80 on flat ground, in sight by `land.isVisible`:
in two minutes **neither side fired a round**; the Bradleys' unit-level `getDetectedTargets` stayed
at 0, and neither `Controller.knowTarget(enemy, true, true)` on each unit nor a `FireAtPoint` task
on the group made them fire (seven TOW still aboard). Sent forward, they opened fire at ~1.3 km and
destroyed both in 16 s. Earlier the same day, stationary trucks 1 km from BMPs, in sight by
`isVisible`, were never engaged in five minutes; at 350 m at once. Vegetation is the likeliest mask.

**What to do:** To make ground units fight an enemy you can see by script, send them closer — `veafGroundAI`'s
convoy closes in to 900 m.

### `world.searchObjects` on a `SPHERE` returns units beyond its radius {#searchobjects-sphere-overshoots-its-radius}

Measured **2026-10-08**.

Caucasus, *Kolkhida* mission 1: a `SPHERE` search of radius 2000 m centred on Poti (`y = 0`) returned
the blue convoy's nine units at **2036 to 2077 m** from its centre, 2D and 3D alike (units at
`y = 5 m`); 40 s earlier, the same search had found the convoy while its nearest unit stood **2117 m**
away — up to about 6 % beyond the radius, by a margin nobody has explained.

**What to do:** Never mix the two answers to one question. Either filter what the search returns by the exact
distance, or take the search's result as the definition everywhere it is asked — the campaign does
the latter (`VeafCampaignZone:groundHolders`). Expect a few percent of slack beyond a sphere's radius.

*What it cost:* The campaign's capture trusted the search and its absorption of the assault convoy measured the exact
distance: the convoy took Poti, was not found in it, and a 24-unit garrison was drawn from blue's
reserve under it (`a-captured-zone-may-draw-a-garrison-under-its-convoy`).

## Mission scripting {#scripting}

### A Lua file with more than 200 top-level locals is refused whole {#lua-chunk-over-200-locals-is-refused}

Measured **2026-10-08**.

DCS runs Lua 5.1, which accepts at most 200 active `local` variables in one function — and a
script file's top level is one function. Past that, the file does not load at all:
`Mission script error: [string "l10n/DEFAULT/veaf-scripts.lua"]:81100: main function has more
than 200 local variables`. Nothing in the file runs, and every later script that uses it fails
in turn (`attempt to index global 'veaf' (a nil value)`).

Measured on the VEAF bundle, which concatenates every module into one file: 190 top-level
`local` lines loaded on 2026-10-07, 198 lines (202 names) failed on 2026-10-08, after the
campaign, opposition and convoy modules were added. Every module loaded alone was fine.

**What to do:** Wrap each part of a long script in its own `do ... end` block: its locals die at its `end`, and
the limit applies per block. The VEAF build does it for every module since
FIX-BUNDLE-LOCAL-LIMIT. In a hand-written `mission-script.lua`, keep state in a table
(`myMission = {}`) rather than in hundreds of top-level locals.

*What it cost:* *Kolkhida* mission 1, rebuilt from `develop` the afternoon it was to be flown, loaded no VEAF
module; no test had ever run the concatenated bundle.

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
