---
Status: ✅ done — R36 read in game 2026-10-03 (session d): with `airbase_logistics_radius: 1100`, the C-130 DCS parks on Ramstein stand #111, 997 m from the point, gets `EQUIPMENT (AB_Ramstein)` · archived 2026-11-24
---

# FEAT-CTLD-AIRBASE-LOGISTICS — airfields are outside CTLD's logistic system, and VEAF can put them in without touching CTLD

## The report, and what measuring it found

[Issue #1007](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/1007): a C-130
landed at Ramstein on Open Training GermanyCW v6 and its *Request Equipment* menu read **"Aucune
logistique à portée"**. Filed as a regression — *airfields used to be logistic zones*. It is not one,
and the distinction is what makes this a feature lot rather than a repair.

That mission's own log, `log-dcs-private1-2026.09.26.log` at 17:18:25:

    CTLDZoneManager: logisticUnitTypes — 0 object(s) registered
    CTLDZoneManager: logisticUnits 'logistic1' not found in mission     (×10)
    CTLDZoneManager ready — troop:0 logistic:0
    17:18:36 CTLDZoneManager: FOB logistic zone ' Goettingen' r=150m
    17:18:39 CTLDZoneManager: FOB logistic zone ' Baumholder' r=150m

The mission declares no `LGZ_` zone, no `logistic*` unit and no static object at all — its FARPs come
from `#veafInterpreter` at runtime, eleven seconds after the manager is ready. So the only two
logistic zones on the theatre are the two FOBs, and every airfield sits outside the system.

**Airfields were never logistic zones in a VEAF mission.** CTLD v1 resolves each name of
`ctld.logisticUnits` through `StaticObject.getByName` then `Unit.getByName`
(`migration/source/CTLD.lua:10828`) — an `Airbase` is neither, and that file carries no
`airbase`/`airport` concept anywhere in its logistics path. VEAF v5's wrapper
(`autoInitializeAllLogistic`, `veaf-scripts.lua:4083`) matched six DCS type names: four aircraft
carriers and two FARP types, and its own comment says *"all the carriers and FARPs"*. The v5 built
`.miz` carries 0 `LGZ_` zone and 0 static object, so on GermanyCW v5 the list reduced in practice to
`logistic #001..#020`.

What the memory is probably made of: **a FARP is itself a DCS `Airbase`** (category 2). FARPs were
registered by type in v5 and still are in v6, through `registerFOBAsLogistic`. From the cockpit,
*"I land on a field and I can load"* was true — for FARPs, never for airfields.

The gap is real anyway. On a theatre whose slots all start from airfields, a transport helicopter or
a C-130 has nowhere to load, and the maker's only recourse today is to hand-place `LGZ_` trigger
zones or to name units `logistic1..10`.

## Why no existing knob can carry it

CTLD 2 discovers logistic zones four ways. Three are closed to an airbase and the fourth is
runtime-only:

| Route | Resolution | Radius | Airbase? |
|---|---|---|---|
| `LGZ_<name>_<R\|B\|N>` trigger zones | `trigger.misc.getZone`, native radius | the zone's own | no — an airbase is not a trigger zone |
| `logisticUnits` (names) | `StaticObject.getByName` or `Unit.getByName` (`CTLD_zone.lua:1046`) | `maximumDistanceLogistic` | no — and an unresolved name **WARNs**, which is where the ten warnings above come from |
| `logisticUnitTypes` (DCS types) | `_forEachMissionUnit` / `_forEachMissionStatic` (`:765`) | `maximumDistanceLogistic` | no — and an airbase has no `getTypeName()` |
| `registerFOBAsLogistic(name, point, radius, coalition)` (`:1190`) | a point the caller already holds | `radius or 150` | reachable, but only from Lua at runtime |

Two consequences.

**The radius is wrong for the job even if the resolution were fixed.** Both configuration routes take
`maximumDistanceLogistic`, which this mission sets to **200 m**, and `CTLDLogisticZone:init` defaults
to 200 as well (`:388`). An airbase reference point sits near the middle of the field; Ramstein's
runway alone is roughly 3 km. A 200 m circle there covers grass.

**CTLD already resolves airbases — on the troop path only.** `_resolveTroopZoneObject`
(`CTLD_zone.lua:1611-1637`) walks trigger zone → unit or static → group's first unit →
**`Airbase.getByName`**, and `registerFARPTroopPickupFromScene` (`:1266`) resolves a spawned FARP as a
real DCS `Airbase`. Neither has a logistic counterpart.

## Decision: register from VEAF, through the public API, and leave CTLD alone

The fourth route is enough. `registerFOBAsLogistic` is public, takes a point, a radius and a
coalition, and VEAF already holds all three for every airbase of the theatre. So the change is
entirely inside `src/scripts/veaf/`, which `vendored.yaml` does **not** cover — that directory is
authored here, CI runs stylua over it — so this is one repository and one pull request, with no CTLD
release and no vendoring bump.

The rejected alternative was to fix the asymmetry where it lives, in CTLD: mirror
`_resolveTroopZoneObject`'s airbase branch into a logistic discovery step driven by a new
`logisticAirbases` list, with its own radius. Cleaner in the abstract — the capability gap *is*
CTLD's — but it costs an upstream change, a release, and a `CHORE-VENDOR-CTLD-*` bump, and it splits
the lot across two repositories. It stays available later: this design does not foreclose it, since
a VEAF that stops registering is all CTLD would need to see.

### The mechanism

1. **Home.** `veafTransportMission.initializeAllLogisticInCTLD()`
   (`src/scripts/veaf/veafTransportMission.lua:688`), which is today a deprecation stub logging
   *"Obsolete"*. It is the function a mission script already calls for exactly this job, so it is
   where a mission maker would look.
2. **Data.** `veafAirbases.Airbases`, built at module load from `world.getAirbases()`
   (`veafAirbases.lua:62`, called at `:449`). Each entry keeps the live handle (`DcsAirbase`),
   `Name`, `Category` and `Runways`. Nothing new to enumerate, and nothing read from
   `airdromes.yaml` — that file's own header declares it *"NOT CI-guarded"* and absent for a
   never-dumped theatre, so depending on it would trade a runtime truth for a stale copy.
3. **Filter.** `Category == Airbase.Category.AIRDROME`. That excludes `SHIP` — carriers are already
   covered by `logisticUnitTypes` / `troopZoneShipTypes` since FEAT-CTLD-AUTO-LOGISTICS — and
   `HELIPAD`, FARPs going through `veafSpawn.spawnLogistic` → `registerFOBAsLogistic` already.
4. **Gate.** `veaf.isCtldReady()` (`veaf.lua:5766`), the guard every other CTLD touchpoint uses.
5. **Register, then hold the state.** Every airdrome is registered once, with
   `coalition.side.BLUE` — never `0`, since `getLogisticZonesAtPoint` serves a `coalition == 0` zone to
   **both** sides (`:1503`). A name already registered makes `registerFOBAsLogistic` **WARN and return
   `false`** (`:1191-1194`), so a collision with an existing zone overwrites nothing. What changes
   afterwards is not the registration but the activation, through the pair CTLD already ships for
   exactly this: `deactivateLogisticZone` / `activateLogisticZone` (`:1296`, `:1310`), reversible,
   documented *"simulates capture or temporary loss"* and *"Deactivated zones are ignored by all
   getters until reactivated"*. No churn in `_logisticZones`, no duplicate warning per tick.

### The qualification rule, decided 2026-09-27

Two classes of airfield, decided by the coalition the airbase holds **on the first evaluation** —
which the VEAF layer snapshots once, since nothing can have been captured by then (on GermanyCW v6
CTLD is ready at 17:18:25 and the first FOB registers at 17:18:36).

**A — blue from the start.** A logistic zone immediately, and it stays one *for as long as the
airbase does not turn red or neutral*. Qualification is `Airbase:getCoalition()` alone: no unit
presence is required, so a field every blue aircraft has departed keeps its logistics. This is the
case that answers #1007, and the reason the rule is not the naive "allied units within 2000 m"
first proposed — that one would have made Ramstein stop being a logistic point the moment the last
blue unit flew out, reintroducing the reported symptom *intermittently*, which is far harder to
diagnose than never having it.

**B — red or neutral at the start, later blue.** Captured ground. It becomes a logistic zone only
after blue troops have held it for **two continuous minutes**, and it stops being one as soon as
every blue unit has withdrawn or been destroyed. The two minutes are also the hysteresis the
boundary needs: without them a single red unit at 1900 m appearing and dying would flip the zone
every tick, and each flip publishes `OnLogisticZoneUpdated` and makes CTLD rebuild the player's
*Request Equipment* menu (`CTLD_crate.lua:2628`).

An A airfield that falls and is retaken **leaves class A**: having been red, it re-enters through B
and owes the two minutes like any other capture.

**Red is mirrored.** The same two classes apply to red airfields, and a red-held field is a red
logistic zone. Both coalitions are therefore registered explicitly — BLUE and RED, never `0`, which
`getLogisticZonesAtPoint` would hand to either side (`:1503`).

### The zone itself, decided 2026-09-27

**One point per airfield, 250 m around it.** The centre is *not* `Airbase:getPoint()` — that sits near
the middle of the field, and 250 m there covers grass. It is a **placed point**, on the apron, and the
placement has to avoid the runway and the taxiways.

`Airbase:getParking()` answers this at runtime, and VEAF already calls it: `veafGrass.lua:135` iterates
an airbase's parking spots, and `getDesc().box` gives the bounding box (`veafGrass.lua:70-79` records
both being measured on a running DCS). A point taken from the parking list is **off the runway and off
the taxiways by construction** — which matters, because DCS exposes no taxiway geometry at all, so
"not on a taxiway" could not be tested directly even if the point were chosen another way. This also
removes any dependency on `veaf_libs/data/parking/*.json`: those captures cover only Caucasus, Persian
Gulf and Syria, and are a design-time copy for the Python tools, not a runtime source.

**The stand nearest the centroid of the stands.** `getParking()` scatters them across the whole apron —
Ramstein's cargo ramp is not next to its fighter shelters — so the point has to be chosen, and the
**centroid itself cannot be it**: an average of parking positions is not a parking position, and can land
on a taxiway or through a building, which is the one thing the placement must not do. Averaging to find
the middle of the apron and then taking the **real stand nearest that average** keeps the point on the
apron by construction while making it as central as a real stand can be.

That leaves a known, accepted gap rather than an open question: on a spread field a C-130 parked further
than 250 m from the chosen stand still reads *"Aucune logistique à portée"* at an airfield that is
registered and active. David settled it on 2026-09-27 by **declining the measurement** that would have
sized the gap on GermanyCW fields — one zone per airfield is the design, and the radius is a setting
next to the 2000 m, so a field that turns out too spread is a number to raise, not a design to reopen.

**One zone per airfield, drawn on the map, nothing spawned.** Decided 2026-09-27: a single 250 m
circle per airfield, and the map is how a pilot finds it — no crate, no flag, no smoke, no static of any
kind is added to the simulation.

The drawing reuses `VeafCircleOnMap` (`veaf.lua:5208`), not a raw `trigger.action` call: it already
carries `setCenter` / `setRadius` / `setColor` / `setFillColor` / `setLineType`, a `draw()` that erases
before redrawing, and the `dcsMarkerIds` bookkeeping that `erase()` uses to remove the markup. Four
modules already use it that way, the closest being
`veafSkynetIadsHelper.lua:4362` — `:setCenter(centre):setRadius(range):setColor("red"):setLineType("solid"):setFillColor("transparent")`.

**Green and transparent, and hatching is not on offer.** `VeafDrawingOnMap.COLORS` has `["green"] =
{0,1,0,1}` — fully opaque — and `["transparent"] = {0,0,0,0}`, so the fill wants a *named* green
carrying its own alpha, the way `["pink"] = {1,0,0,0.3}` already is a translucent red. The table's own
comment states the rule: colours are *"Named here rather than passed as raw RGBA at the call site,
because a colour nobody can name is a colour the next caller re-invents slightly differently."* An alpha
around 0.15 matches `veafGeo.drawTriggerZone`'s default fill.

**Hatched fill is not available.** `VeafDrawingOnMap.LINE_TYPE` offers `none, solid, dashed, dotted,
dotdash, longdash, twodashes`, and the DCS schema for `circleToAll` describes `lineType` as *"Line style
for the circle **outline**"* — it styles the border, never the interior. Faking a hatch would mean
drawing many `lineToAll` stripes and clipping them to the circle by hand, for a markup DCS does not
support. The distinction the hatch was meant to carry has to come from the outline style or from the
fill alpha instead.

**Visibility is per coalition.** `circleToAll`'s first argument is *"Coalition that can see the
circle"*, so drawing each zone for its own side keeps a green circle meaning *ours* — with every zone
green and visible to all, a blue pilot could not tell a blue logistic point from a red one.

### Why nothing is spawned

A spawned crate or flag is a **static object**. The class-B occupation probe looks for whoever holds the
field, so a marker placed to show the zone would itself be the blue presence that keeps the zone alive —
the airfield qualifying because of the object its own qualification produced. Drawing the zone instead
of spawning it removes the circularity outright.

The probe still searches `Object.Category.UNIT` only, filtered to ground units, and **never `STATIC`** —
because the circularity does not need this lot to exist: a FARP or an FOB built in flight near a captured
field is a static, and counting statics would let the logistics of one installation qualify the airfield
beside it. That is also what "troops" means in the rule, and why a transport that lands on a captured
field is an aircraft, so it does not start the two-minute clock on the zone it landed to use.

### What the rule costs, and what it does not

Class A needs only `Airbase:getCoalition()`, read per tick over the airdrome set — cheap, and no
spatial query at all. The sphere probe is therefore only ever run for class B: airfields that are
blue now and were not at the start, plus the active B zones being checked for a blue withdrawal. On a
typical mission that is a handful of airfields, not sixty.

The probe itself reuses what `veafGrass.isSpotOccupied` already established (`veafGrass.lua:267`):
a `world.VolumeType.SPHERE` volume, `world.searchObjects` under `pcall`, and the two traps that go
with it. **`searchObjects` is called per category**, so the categories must be chosen, not
accumulated: `Object.Category.UNIT` and `STATIC` at most, and never `SCENERY`, which has no
coalition and would make a "no red here" test meaningless. **It matches an object's *position*, not
its footprint** (`:261`), so a unit straddling the boundary is counted by its centre. And the
coalition test happens in the callback, not in the query.

`isSpotOccupied` fails **open** — *"treating the spot as clear"* — when `searchObjects` raises. Here
the direction has to be chosen deliberately rather than inherited: an unusable probe should leave a
zone **as it was**, not deactivate it, or a DCS quirk would make a logistic point flicker out for a
reason nobody can see in the mission.

### Every 30 seconds, and announced when it changes

**The tick is 30 s**, decided 2026-09-27. A front does not move in seconds, so there is nothing to gain
from evaluating it faster: the class-A checks are cheap but the class-B sphere probes are not free, and
30 s keeps them at two per minute per captured airfield instead of one per frame. It stays a **setting**
next to the 250 m and the 2000 m rather than a constant, so a mission with a fast-moving front can ask
for less. The loop belongs on `veafScheduler` like every other periodic VEAF behaviour — nothing in
`veafTransportMission` polls today.

**Every status change is announced to the coalitions**, decided 2026-09-27. A logistic point appearing
or disappearing is exactly the kind of thing a pilot cannot see: the *Request Equipment* menu changes
under him, mid-flight, for a reason that is nowhere on his map except a circle he may not be looking at.
So each transition — a class-A field turning red or neutral, a captured field crossing its two minutes,
a captured field losing its last blue unit — sends `trigger.action.outTextForCoalition`, with the text
from `veaf.t()` and its entry in the `veafI18n` catalogue in **both** languages, the way
`veafSpawnGround.lua:223` already announces `spawn.fob_built`. The side that **gains** the point is told
it can now load there; the side that **loses** it is told it can no longer. The message is a
consequence of the state machine, not a parallel narration of it: it fires on the transition, never on
the tick, so a quiet front stays quiet.

### What this design does not need

No mission-file surgery — the builder reads trigger zones for validation
(`mission_builder_worker.py:1471`) but no zone-writing path was found in `mission_builder_worker.py`
or `miz_tools.py`, and none has to be built. No circular footprint drawn by hand over a real
airfield. No dependency on a data dump. No upstream release.

## What remains to settle

Nothing that gates the work. Two details were open when the tickets were written, and each is now
carried by one:

**The stub's contract.** The comment above `initializeAllLogisticInCTLD()` (`:676-680`) states that a
logistic point *is* an `LGZ_` zone, declared in `ctld-config.yaml`, with *"nothing to run"*. Giving the
function a body contradicts it, so ticket 01 rewrites the comment in the same change, and ticket 05
amends ADR 0016, which already stopped being strictly "verbatim" with `manage_logistics`.

**Where the snapshot can be wrong.** Class A is decided on the first evaluation, so a mission script
that captures an airfield in its opening seconds — a T+0 trigger — could have the field classified B and
owing two minutes it should not owe. Unlikely, and recorded as a watch-out in ticket 01 rather than
designed around.

## Risks to name

- **Zone naming.** The two FOB zones already carry a **leading space** — `' Goettingen'`,
  `' Baumholder'`. If airbase zones are registered through a path that builds names the same way, they
  inherit it. Cosmetic today, and it would break any exact-name lookup. Its origin is not established
  yet; it is worth finding before this lot ships, not after.
- **Every activation draws a markup, so every deactivation must erase one.** The zones are ours to draw
  now, which means stale circles are ours to leak: a field captured, lost and retaken across a four-hour
  session draws three times unless one `VeafCircleOnMap` is kept per airfield and re-drawn — `draw()`
  erases first — or erased on the way down. `veaf.getUniqueIdentifier()` supplies the ids. Related and
  still unverified: whether CTLD draws its *own* markup for a registered logistic zone, which would
  double the circles on the map.
- **`world.getAirbases()` returns everything** — ships, helipads, neutral fields. The
  `Category.AIRDROME` filter is what keeps the set sane, and the class-A snapshot is what keeps a
  neutral field out until it is actually taken.
- **Coupling to CTLD 2 API.** `CTLDZoneManager:getInstance()`, `registerFOBAsLogistic`,
  `deactivateLogisticZone` and `activateLogisticZone` are CTLD 2, not v1. The `veaf.isCtldReady()` gate
  covers a mission where CTLD never started, but not a future CTLD that renames one of them.
  FEAT-CTLD-AUTO-LOGISTICS accepted the same kind of coupling.
- **A per-tick state machine is a new thing in this module.** `veafTransportMission` is today a radio
  menu, a marker handler and two stubs; nothing in it polls. The loop belongs on `veafScheduler` like
  every other periodic VEAF behaviour, and the state it keeps per airfield has to survive a
  re-initialisation without re-classifying a field that was captured while nobody was looking.

## Out of scope

- **The ten `logistic1..logistic10` warnings.** CTLD's own defaults (`CTLD.lua:3173-3184`) are carried
  verbatim into `ctld-config.yaml`, so every VEAF mission starts with ten unresolved names and ten
  WARNINGs. VEAF v5 reset `ctld.logisticUnits = {}` and never warned. Pure noise, no behavioural
  effect — but it is the one genuine v5 → v6 difference this investigation found, and it wants a chore
  of its own.
- **`logisticUnitTypes` blind to runtime spawning.** Discovery walks the mission database at init,
  which is why the `#veafInterpreter` FARPs registered 0. `veafSpawn.spawnLogistic` already calls
  `registerFOBAsLogistic` explicitly, so this is by design — recorded so nobody re-investigates it.
- **Answering #1007 itself.** The reporter's symptom is expected behaviour on that mission as built, and
  this lot is the answer David chose for it. The reply on the issue still has to be written, and it
  should say the two things the report got wrong: that it is not a regression, and that the field was
  never a logistic point — before saying when it will become one.

## Tickets

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Register every airdrome as a CTLD logistic zone](FEAT-CTLD-AIRBASE-LOGISTICS.md) | ✅ |
| 02 | [The 30-second tick, and a class-A airfield that changes side](FEAT-CTLD-AIRBASE-LOGISTICS.md) | ✅ |
| 03 | [Class B: two continuous minutes of ground occupation](FEAT-CTLD-AIRBASE-LOGISTICS.md) | ✅ |
| 04 | [One green transparent circle per active airfield, on the F10 map](FEAT-CTLD-AIRBASE-LOGISTICS.md) | ✅ |
| 05 | [The opt-out, the three settings, and the documentation](FEAT-CTLD-AIRBASE-LOGISTICS.md) | ✅ |

Each ticket names what blocks it: 01 blocks 02 and 05, 02 blocks 03 and 04. Work the frontier — 01
alone at the start, then 02 and 05 together, then 03 and 04. 05 ships last in practice, so the
documentation describes what was built rather than what was intended.

## Definition of done

Nothing is left to measure, and what is left to settle is two implementation details a ticket can close
on its own. The verification happens in flight, on the mission that reported the issue. Done looks like:

- A C-130 at Ramstein on GermanyCW v6 reads something other than *"Aucune logistique à portée"*, parked
  where a C-130 actually parks — not at the airbase reference point. If a field turns out too spread for
  one 250 m circle, that is the radius setting to raise, not the design to reopen.
- A field captured in flight becomes a logistic point two minutes after blue **ground** troops arrive,
  and stops being one when the last of them withdraws or dies. The mirror holds for red.
- A blue-from-the-start field keeps its logistics with no blue unit left anywhere near it, and loses
  them when it turns red or neutral.
- One green transparent circle per active airfield on the F10 map, drawn through `VeafCircleOnMap`,
  visible to the coalition that holds it, erased when the zone deactivates — and **nothing spawned**
  into the simulation to mark it.
- Every transition is announced to the coalition that gains the point and to the one that loses it, in
  the player's own language, and **nothing is said on a tick where nothing changed**.
- The state is evaluated every **30 s**, and that number is a setting beside the 250 m and the 2000 m,
  not a constant in the loop.
- The log says how many airfields VEAF registered and which class each one is in.
- A mission that wants none of it can say so, and says so in `mission.yaml`.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

On the Caucasus session mission David received the capture message for Kobuleti (logistic zone
activated). The C-130 loading at Ramstein, the check #1007 asked for, was not flown. #1007 closed on
that evidence.

## The Ramstein loading, measured — 2026-10-03 (session c)

GermanyCW, `develop` `d3823f7e`, read through the fiddle hook:

- `AB_Ramstein`: class A, registered, active, held by blue. The call CTLD's *Request Equipment* menu
  makes, `getLogisticZonesAtPoint(point, BLUE, "cratesPickup")`, returns the zone at the zone's own
  point — so the registration and the read both work.
- An AI C-130 spawned with **no stand imposed**, so DCS parked it where it parks a C-130: stand #111
  (terminal type 104), **997 m** from the logistic point. The same call at its position returns
  nothing — the menu reads *« Aucune logistique à portée »*.
- Ramstein's 90 large-aircraft stands (terminal types 72 and 104): **one** within 250 m (#108, 249 m),
  then 446, 601, 665, 709, 820 m … and 2 001 m for the farthest.

This is the gap the PRD accepted — "a number to raise, not a design to reopen" — now with its number.
**David chose on 2026-10-03 to raise it for GermanyCW only** (`airbase_logistics_radius` in that
mission's `mission.yaml`), not the default: one field is measured, and a default for every theatre
would be set on that one field. The mission is set to **1 100 m**, which covers stand #111 with a
margin and the six nearest large-aircraft stands. Left: rebuild GermanyCW-v6 and re-run
`c_ramstein.lua` once (`DCS-SESSION-TODO.md`, R36).

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**airfields are outside CTLD's logistic system, and no configuration knob can put them in.** Filed from #1007, a C-130 at Ramstein reading *"Aucune logistique à portée"*, and reported as a regression — but measured not to be one: CTLD v1 resolves `logisticUnits` through `StaticObject`/`Unit` only, and VEAF v5's wrapper matched six DCS types, four carriers and two FARP kinds, *"all the carriers and FARPs"* by its own comment. What the memory is made of is that **a FARP is itself a DCS `Airbase`**, so FARPs were registered and airfields never were. CTLD 2's four discovery routes are all closed to an airbase — the two configuration ones resolve by name or type and take their radius from `maximumDistanceLogistic`, **200 m** on this mission, against a reference point at the middle of a 3 km field — and CTLD resolves airbases on the **troop** path only, in `_resolveTroopZoneObject`. Decision: register from VEAF through the public `registerFOBAsLogistic`, off `veafAirbases.Airbases` (already built from `world.getAirbases()`) filtered on `Category.AIRDROME`, reviving the `initializeAllLogisticInCTLD()` stub, and hold it with the `deactivateLogisticZone`/`activateLogisticZone` pair CTLD already ships for *"capture or temporary loss"*. One repo and one PR, no CTLD release and no vendoring bump, since `src/scripts/veaf/` is authored here and absent from `vendored.yaml`. **Qualification rule decided 2026-09-27**, in two classes snapshot from the coalition held on the first evaluation: an airfield **blue from the start** is a logistic zone for as long as it does not turn red or neutral — no unit presence required, so a field every blue aircraft has departed keeps its logistics, which is precisely what the naive "allied units within 2000 m" first proposed would have broken, and intermittently; an airfield **captured later** owes **two continuous minutes** of blue occupation, and loses the zone as soon as the last blue unit withdraws or dies — the two minutes doubling as the hysteresis the boundary needs, since every flip republishes `OnLogisticZoneUpdated` and rebuilds the player's menu. Class A costs only `getCoalition()`, so the sphere probe runs for class B alone. **Red is mirrored**, and both coalitions are registered explicitly — never `0`, which `getLogisticZonesAtPoint` would hand to either side. Zone geometry decided: **one placed point per airfield with 250 m around it**, the point taken from `Airbase:getParking()` — a runtime API `veafGrass.lua:135` already iterates — which puts it on the apron and therefore off the runway **and off the taxiways by construction**, DCS exposing no taxiway geometry to check against; this also drops any dependency on `data/parking/*.json`, which covers only Caucasus, Persian Gulf and Syria. Marking is **one green transparent circle per airfield on the F10 map**, drawn with `VeafCircleOnMap` — the fluent wrapper over `trigger.action.circleToAll` + `removeMark` (`veaf.lua:5208`, whose `draw()` is `:5248`) that `veafSkynetIadsHelper.lua:4362` already uses — visible to the owning coalition only. **Hatching is not on offer**: `lineType` styles the circle *outline* per the DCS schema, never the interior, so the distinction a hatch was meant to carry comes from colour and transparency instead. Nothing is spawned into the simulation to mark it, and it must stay that way, because a spawned crate or flag is a **static**, and a probe counting statics would let the marker be the blue presence that keeps its own zone alive. Occupation is therefore `Object.Category.UNIT`, ground only, which is also why a transport landing on a captured field does not start the clock on the zone it landed to use. Trap recorded on the way: `zone.coalition == 0` serves **both** sides. Placement is settled **without measuring**: the point is the **real stand nearest the centroid of all the stands**, since an average of parking positions is not itself a parking position and can land on a taxiway, and the accepted gap is that a C-130 parked beyond 250 m on a spread apron still reads nothing — the radius sits in the module settings next to the 2000 m, so a field that turns out too spread is a number to raise, not a design to reopen. The state is evaluated **every 30 s** on `veafScheduler`, and **every status change is announced** with `outTextForCoalition` + `veaf.t()` to the side that gains the point and to the one that loses it, never on a tick where nothing changed. **Five tickets cut, 01 is the frontier**: register every airdrome (which is #1007's answer on its own), the 30 s tick and class-A flips, class B's two minutes and its ground-unit probe, the green circle, then the opt-out, the three settings and the docs. One choice is still David's and it is costed both ways in ticket 05: `modules.CTLD.manage_airbase_logistics` beside its sibling, or `settings:` keys with no new plumbing

## Tickets, in full

---
Status: ✅ done
---

## 01 — Register every airdrome as a CTLD logistic zone

**Blocked by:** none. This is the tracer bullet, and on its own it is the answer to #1007.

### What it delivers

A C-130 parked at Ramstein on GermanyCW v6 opens *Request Equipment* and gets a menu instead of
*"Aucune logistique à portée"*. Every airdrome of the theatre is a CTLD logistic zone from mission
start — with no CTLD change, no mission-file surgery and nothing spawned into the simulation.

### Where

- The stub to revive: `veafTransportMission.initializeAllLogisticInCTLD()`,
  `src/scripts/veaf/veafTransportMission.lua:688`. The comment above it (`:676-680`) states that a
  logistic point *is* an `LGZ_` zone declared in `ctld-config.yaml` with *"nothing to run"*; it stops
  being true in this ticket, so it is rewritten **here** rather than deferred to 05.
- The airbase list: `veafAirbases.Airbases`, an array built once from `world.getAirbases()`
  (`veafAirbases.lua:62`), `initialize()` idempotent (`:56-58`) and already run at load (`:449`). Each
  record carries `Name`, `DisplayName`, `Category`, `DcsAirbase`, `Runways` (`:244-250`), and
  `DcsAirbase` is the live handle reaching `getParking()` and `getCoalition()`.
- The registration: `CTLDZoneManager:getInstance():registerFOBAsLogistic(name, point, radius,
  coalitionId)` (`CTLD_zone.lua:1190`).

### Do

- Gate the whole thing on `veaf.isCtldReady()` (`veaf.lua:5766`), the guard every other CTLD
  touchpoint uses, and log once when it answers no.
- Keep only `Category == Airbase.Category.AIRDROME`. Ships and helipads are out: carriers and FARPs
  already have their route (`manage_logistics`, and `veafSpawn.spawnLogistic` → `registerFOBAsLogistic`).
- Place the point from `DcsAirbase:getParking()` — the runtime API `veafGrass.lua:135` already
  iterates. Average the stand positions into a centroid, then take the **real stand nearest that
  centroid**. The centroid is never the point: an average of parking positions is not a parking
  position and can land on a taxiway. `Airbase:getPoint()` is never the point either — it sits near
  the middle of the field, where 250 m covers grass.
- An airfield whose parking list is empty is **skipped, with a warning naming it**. No fallback to
  `getPoint()`: a 250 m circle on the reference point can sit on a runway, and a zone a pilot cannot
  legally use is worse than an airfield honestly missing from the log line.
- Name each zone `AB_<airbase name>`. `registerFOBAsLogistic` uses the name verbatim as its registry
  key and adds neither prefix nor coalition suffix (`:1191-1201`), and CTLD's parsers read only
  **trigger zones** named `LGZ_` / `TRZ_` / `WPZ_` / `AIZ_` (`:734-745`, `:1728-1748`) — so `AB_` is
  free. The equipment menu never displays a zone name, so this is a log-and-registry identifier only.
- Register with the airfield's **own** coalition from `DcsAirbase:getCoalition()`, never `0`:
  `getLogisticZonesAtPoint` serves a `coalition == 0` zone to **both** sides (`:1503-1511`).
- Radius 250 m, read from settings rather than written at the call site (ticket 05 decides where the
  setting lives; until then a module-level local is fine, and 05 moves it).
- Before registering, ask `getLogisticZonesAtPoint(point, coalition)` whether something already covers
  that stand; if it does, skip and log. A maker's hand-placed `LGZ_` zone over Ramstein wins, and the
  alternative is two overlapping zones at one airfield.
- Check the return value: a name that already exists makes CTLD **WARN and return `false`**
  (`:1191-1194`). Log it at our level too, naming the airfield, or the only trace left is a CTLD line
  that does not say who asked.
- Snapshot each airfield's class into the per-airfield state table this lot keeps — A for a field held
  by a coalition from the start, B for the rest — because 02 and 03 read that snapshot and nothing can
  have been captured yet at first evaluation.
- One summary log line: how many airdromes registered, how many skipped and why, and each one's class.

### Watch out

- The class snapshot is taken at **first evaluation**, so a mission script that captures an airfield in
  its opening seconds — a T+0 trigger running before this module initialises — would record the field as
  class B and make it owe two minutes it should not owe. Unlikely (on GermanyCW v6 CTLD is ready at
  17:18:25 and the first FOB registers at 17:18:36) and cheaper to note than to discover in flight. If
  it ever bites, the fix is to snapshot from the `warehouses` table the builder wrote rather than from
  the live coalition.
- The two FOB zones already registered on this mission carry a **leading space** — `' Goettingen'`,
  `' Baumholder'`. Build our names without one, and find where that space comes from while in there: if
  a shared helper produces it, our names inherit it and every exact-name lookup breaks.
- Nothing is spawned to mark the zone and it must stay that way: a spawned crate or flag is a
  **static**, and 03's probe would let the marker be the blue presence keeping its own zone alive.
- The Lua tests have no DCS. `world.getAirbases()` returns `{}` (`dcs_mocks.lua:286`) and
  `Airbase.getByName` returns nil (`:448-453`), so build fake airbase records the way
  `test_veafAirbases.lua:38-42` already does and override the mock per test — that file's own comment
  states the convention. `CTLDZoneManager` is already a **recording** mock (`:1027`, calls land in
  `instance.calls`), but its `registerFOBAsLogistic` returns nothing where the real one returns
  `true`/`false`: give it a controllable return so the collision path is testable at all.
- `getLogisticZonesAtPoint` is **absent** from that mock; add it, recording like the others.
- The gates a PR here meets: `luacheck src/scripts/veaf/`, `stylua --check src/scripts/veaf/ test/lua/`,
  and `poetry run test-lua --cov-fail-under 80.9`.

### Done when

- On GermanyCW v6 a C-130 at Ramstein reads a real *Request Equipment* menu.
- The log gives the number of airdromes registered and each airfield's class.
- Lua tests assert: an AIRDROME registers at 250 m with its own coalition; a SHIP and a HELIPAD do not
  register; the point is a real stand, neither the centroid nor `getPoint()`; an empty parking list
  skips with a warning; a stand already covered registers nothing; `registerFOBAsLogistic` returning
  `false` is logged rather than swallowed; nothing is registered when `veaf.isCtldReady()` is false.
- The comment at `:676-680` describes what the function now does.

---
Status: ✅ done
---

## 02 — The 30-second tick, and a class-A airfield that changes side

**Blocked by:** 01 — it reads the per-airfield state table and the registrations that ticket builds.

### What it delivers

A blue-from-the-start airfield captured in flight stops being a logistic point within half a minute —
its *Request Equipment* menu goes away — and comes back when it is retaken. Both coalitions are told,
in their own language, at the moment it changes. A field every blue aircraft has departed **keeps** its
logistics, which is what makes this rule and not "allied units within 2000 m" the answer to #1007.

### Where

- The loop goes on `veafScheduler.scheduleFunction(f, vars, t, rep, st)` (`veafScheduler.lua:129`,
  removal at `:159`), like every other periodic VEAF behaviour. Nothing in `veafTransportMission`
  polls today, and it must not start doing so on its own timer.
- The reversible pair CTLD already ships for exactly this: `deactivateLogisticZone` /
  `activateLogisticZone` (`CTLD_zone.lua:1296`, `:1310`) — documented *"simulates capture or temporary
  loss"* and *"Deactivated zones are ignored by all getters until reactivated"*, which is what
  `getLogisticZonesAtPoint` (`:1503-1511`) and therefore the menu obey.
- The messages: `trigger.action.outTextForCoalition` with text from `veaf.t()`, keys in the
  `transport.*` family of `veafI18n.lua`, following that file's own header (*"add a
  `["my.key"] = { fr = "...", en = "..." }` entry here, then call `veaf.t("my.key", ...)` at the
  message site"*). The nearest precedent is `veafSpawnGround.lua:223`, announcing `spawn.fob_built`.

### Do

- One recurring task, **30 s**, the interval read from settings and never written into the loop.
- Per tick, per registered airfield: read `DcsAirbase:getCoalition()` and compare it with the last
  known state. Act only on a **difference** — do not re-issue an activation for a zone already active.
- A class-A airfield whose coalition is no longer the one it was snapshot with is **deactivated**; when
  it comes back, **activated**. Never unregister and re-register: that would churn `_logisticZones` and
  produce a duplicate warning per tick.
- No unit presence is consulted for class A. The coalition is the whole test.
- An airfield that was class A, falls, and is retaken **leaves class A**: having been held by the other
  side, it re-enters through B and owes ticket 03's two minutes like any other capture. Record the
  transition in the state table so 03 does not have to guess.
- Announce every transition: to the coalition that **gains** the point, that it can now load there; to
  the one that **loses** it, that it can no longer. Two keys, both languages, and the airfield's display
  name as the argument so the message says which field. Fire on the transition only — a tick where
  nothing changed sends nothing and writes nothing.
- A coalition read that raises leaves the zone **as it was**, and says so in the log.
- The state table survives a module re-initialisation without re-snapshotting: an airfield already
  registered is not re-classified, or a field captured while nobody was looking would be recorded as
  blue-from-the-start and granted logistics it has not earned.
- Add `deactivateLogisticZone` and `activateLogisticZone` to the recording `CTLDZoneManager` mock
  (`dcs_mocks.lua:1027`); both are absent today.

### Watch out

- Every flip publishes `OnLogisticZoneUpdated`, which makes CTLD rebuild the player's *Request
  Equipment* menu (`CTLD_crate.lua:2628`). At 30 s that is invisible; a state comparison that misfires
  turns it into a menu rebuilding itself every half minute, which a pilot will report as lag.
- 30 s is generous on purpose — the class-A test is one `getCoalition()` per airfield per tick, and no
  spatial query at all. Do not "optimise" it into a per-frame check, and do not let 03's probe run for
  class A.
- A neutral airfield is a **loss**, not a third state to announce: the message goes to the side that
  held it, and the zone stays deactivated until somebody holds it again.
- `outTextForCoalition` takes a coalition side, so `-1`/all is not an option here: telling both sides
  means two calls, and the losing side must not receive the gaining side's wording.
- The Lua coverage floor (`--cov-fail-under 80.9`) counts the tick body: drive it by calling the tick
  function directly with an injected clock, never by sleeping.

### Done when

- In flight: capturing a blue-start airfield removes its menu within one tick and announces it to both
  sides; retaking it restores both; a field with no blue unit left anywhere near it keeps its logistics.
- A tick where nothing changed sends no message, writes no log line and calls no CTLD method.
- Lua tests assert, against the recording mocks: deactivate on coalition loss, activate on return, an
  A→B reclassification when a retaken field changes hands, no CTLD call when the coalition is
  unchanged, one message per side per transition, and a raising `getCoalition()` leaving the zone as it
  was.

---
Status: ✅ done
---

## 03 — Class B: two continuous minutes of ground occupation

**Blocked by:** 02 — it reuses the tick, the state table and the activate/deactivate pair. Nothing to
wait for in 04: the map circle is drawn by the same transitions.

### What it delivers

Troops landed on a red or neutral airfield make it a logistic point **two minutes later**, and it stops
being one the moment the last of them withdraws or dies. Red is mirrored: red troops holding a field
that was blue do the same for their side. Both transitions are announced.

### Where

- The probe pattern `veafGrass.isSpotOccupied` already established (`veafGrass.lua:267-300`): a
  `world.VolumeType.SPHERE` volume, `world.searchObjects` called **once per category** under `pcall`,
  the answer decided in the callback.
- The tick and the state table from 02; `activateLogisticZone` / `deactivateLogisticZone`
  (`CTLD_zone.lua:1296`, `:1310`).

### Do

- Class B is a registered airfield whose snapshot (01) was **not** the coalition that holds it now,
  plus every airfield 02 moved out of class A. It is the only class that costs a spatial query: class A
  is decided by `getCoalition()` alone.
- Probe a sphere of **2000 m** around the zone's own point, `Object.Category.UNIT` only, and count an
  object as holding the field when all of these hold:
  - `object:isExist()`;
  - `object:getCoalition()` is the coalition in question — the test happens **in the callback**, since
    `searchObjects` does not filter on coalition;
  - `object:getCategoryEx() == Unit.Category.GROUND_UNIT` (`= 2` in the vendored schema,
    `dcs-world-api-schema.json:7268`). **Not `getCategory()`**: that returns an `Object.Category`, and
    `dcs_mocks.lua:611-613` records the trap by name — it looks like it answers "airplane or ground
    unit?" and does not.
- Never add `Object.Category.STATIC` to the loop. A FARP or an FOB built in flight near a captured
  field is a static, and counting statics would let one installation's logistics qualify the airfield
  beside it — and would let a maker's own crate hold a zone open. Never `SCENERY` either: scenery has no
  coalition, so a "no enemy here" test over it is meaningless.
- Two **continuous** minutes: a tick that finds nobody returns the field to "not yet" and clears the
  clock, rather than pausing it. The two minutes are measured on the mission clock (`timer.getTime()`)
  from the first tick that sees the occupier, never as a count of ticks — a count only equals two
  minutes when the interval divides 120 (decided in review, 2026-09-27). Assert it with an injected
  clock, never by sleeping.
- The losing side keeps its zone only while it holds the field: an airfield is a logistic point for one
  coalition at a time, so the transition activates for the new holder and deactivates for the old one.
  Announce both, as 02 does.
- An unusable probe leaves the zone **as it was** and logs it. `isSpotOccupied` fails *open* —
  *"treating the spot as clear"* (`veafGrass.lua:281-298`) — and inheriting that direction here would
  make a logistic point flicker out on a DCS quirk, for a reason nobody can see in the mission.
- `searchObjects` matches an object's **position**, not its footprint (`veafGrass.lua:261`), so a
  unit straddling the 2000 m boundary counts by its centre. Accepted; write it into the documentation
  rather than trying to compensate for it.

### Watch out

- `dcs_mocks.lua:298` is `searchObjects = function(category, volume, fn) end` — it **never calls the
  callback**, so a test written against it today asserts nothing about occupation. Extend it to walk an
  injectable object list, call `fn` per object and record the `{category, volume}` it was given, in the
  style the file already argues for: *"what a spawner hands DCS **is** the behaviour under test, and
  asserting against a no-op stub asserts nothing"* (`:394-396`). `world.VolumeType.SPHERE` already
  exists (`:292`).
- Categories are queried **separately**: one call per `Object.Category`, not one call with a list. A
  loop over a single category keeps the cost visible, which is the point of restricting this to class B.
- The probe runs for class-B airfields and for active class-B zones being checked for a withdrawal —
  not for the whole theatre, and not for class A. On a typical mission that is a handful of airfields.
  If the log shows it running for sixty, the filter is wrong.
- A transport that lands on a captured field is an aircraft: it must **not** start the clock on the zone
  it landed to use. That falls out of `GROUND_UNIT`, and it is worth an explicit test because it is the
  case a pilot will actually hit.
- Coverage floor and stylua, as in 01.

### Done when

- In flight: blue ground troops on a red airfield make it a logistic point two minutes later, announced
  to both sides; destroying the last of them removes it, announced; a lone blue aircraft parked on the
  same field never starts the clock; red troops on a blue field behave identically for red.
- Lua tests assert, against the extended `searchObjects` mock: activation after four consecutive
  positive ticks and not after three; the clock cleared by one empty tick; an aircraft ignored; a static
  ignored; scenery never queried; the probe queried for class B only; a raising `searchObjects` leaving
  the zone as it was.

---
Status: ✅ done
---

## 04 — One green transparent circle per active airfield, on the F10 map

**Blocked by:** 02 — the circle is drawn on activation and erased on deactivation, and those
transitions are what 02 builds. Nothing to wait for in 03: class-B zones are drawn by the same edges.

### What it delivers

A pilot opens the F10 map and sees exactly the logistic airfields his coalition holds, as green
transparent circles, appearing and disappearing with the status. The map is how he finds the zone, which
is why nothing is spawned into the simulation to mark it.

### Where

- `VeafCircleOnMap` (`veaf.lua:5208`), whose `draw()` (`:5239-5251`) erases first, then calls
  `trigger.action.circleToAll` (`:5248`) and records the id in `dcsMarkerIds`; `erase()` is inherited
  from `VeafDrawingOnMap` (`:5196-5205`) and calls `trigger.action.removeMark` per recorded id.
- The fluent precedent: `veafSkynetIadsHelper.lua:4362` — `:setCenter(centre):setRadius(range)
  :setColor("red"):setLineType("solid"):setFillColor("transparent")`.
- Colours in `VeafDrawingOnMap.COLORS` (`veaf.lua:5039`), line styles in `LINE_TYPE` (`:5029`); the
  setters accept names (`:5113`, `:5124`, `:5135`).
- Alpha precedent: `veafGeo.drawTriggerZone`'s defaults (`veafGeo.lua:400-409`) — colour
  `{1,1,1,0.5}`, fill `{1,1,1,0.15}`, `lineType = 2`.

### Do

- Add a **named** translucent green to `COLORS`. The existing `["green"] = {0,1,0,1}` is fully opaque
  and `["transparent"] = {0,0,0,0}` is nothing, so neither can express "green, see-through". The
  table's own comment states the rule: colours are *"Named here rather than passed as raw RGBA at the
  call site, because a colour nobody can name is a colour the next caller re-invents slightly
  differently"* — and `["pink"] = {1,0,0,0.3}` is already a translucent red, so an alpha around **0.15**
  (matching `veafGeo`) is in family.
- Draw with `:setCenter(point):setRadius(<the 250 m setting>):setColor("green"):setFillColor(<the new
  name>):setLineType("solid")`, and `:setCoalition(<the holder>)`: `circleToAll`'s first argument is
  *"Coalition that can see the circle"*, so a per-side drawing is what keeps green meaning *ours*. With
  every zone drawn for everyone, a blue pilot could not tell a blue logistic point from a red one.
- `:setName()` to the zone name, so the trace lines say which airfield is being drawn.
- Hook the transitions from 02 and 03: draw on activation, `erase()` on deactivation. Keep **one circle
  object per airfield** beside its state, created once and reused; `draw()` already erases before
  redrawing, so re-activation cannot double up.
- Erase on module re-initialisation, and never leave a circle whose zone is gone: a leaked markup is a
  circle on the map with nothing behind it, and a pilot who lands inside it gets
  *"Aucune logistique à portée"* — the exact symptom this lot exists to remove.
- **No hatching, and do not fake it.** `LINE_TYPE` offers `none, solid, dashed, dotted, dotdash,
  longdash, twodashes`, and the DCS schema describes `circleToAll`'s `lineType` as *"Line style for the
  circle **outline**"* — it styles the border, never the interior. Stripes drawn with `lineToAll` and
  clipped by hand are not a hatch and cost more than the distinction is worth; the distinction comes
  from colour and fill alpha.

### Watch out

- `dcs_mocks.lua:193-196` are `removeMark = function(id) end` and `circleToAll = function(...) end`:
  both **discard their arguments**, so a test can assert nothing about what was drawn today. Record
  them the way `addGroup` / `addStaticObject` do, and clear the records in `dcs_mocks.reset()`.
- `VeafDrawingOnMap:erase()` **never clears `dcsMarkerIds`** (`:5196-5205`), so a second `erase()` on
  the same object re-issues `removeMark` for ids already removed — harmless to DCS, but it makes "erase
  was called once" the wrong assertion. Assert on the **recorded markup** (a circle exists after
  activation, none after deactivation) rather than on call counts, and do not "fix" `erase()` in this
  ticket: four modules share that base class.
- One circle per **airfield**, not per zone: an airfield changing hands must not leave two circles at
  the same point, one per coalition, since both are 250 m around the same stand.
- Coverage floor and stylua, as in 01.

### Done when

- In flight: one green transparent circle per active logistic airfield, visible only to the coalition
  that holds it, appearing on activation, gone on deactivation, and none left over after a
  re-initialisation or a change of hands.
- Lua tests assert against the recording mocks: the centre is the stand 01 chose, the radius is the
  setting, the coalition is the holder's, the fill is the new named colour, a deactivation leaves no
  circle drawn, and a change of hands leaves exactly one.

---
Status: ✅ done
---

## 05 — The opt-out, the three settings, and the documentation

**Blocked by:** 01 — the flag has to gate something that exists. Ships last so the documentation
describes what was built rather than what was intended.

### What it delivers

A mission maker who wants none of this says so in `mission.yaml`, in plain sight, and the three numbers
this lot introduced are his to change without editing Lua. The documentation says what an airfield
logistic zone is, when it opens and closes, and why a field can be registered and still read
*"Aucune logistique à portée"* 400 m from the stand.

### The one choice left, and it is David's

Where the opt-out key lives. Both work; they cost differently.

1. **`modules.CTLD.manage_airbase_logistics`** *(recommended)* — the sibling of `manage_logistics` from
   FEAT-CTLD-AUTO-LOGISTICS, so a maker reading his CTLD block sees both logistics flags together.
   Cost: `manage_logistics` is consumed by the **builder** (`_build_ctld_user_config` merges
   `ctld-config.yaml` on the way into the `.miz`), while this one is consumed by **VEAF Lua at runtime**,
   so the generator's CTLD branch has to emit it into `veaf-config.lua` — a new emission path, plus the
   validator and the scaffold.
2. **`settings:` keys** (`lua_config_generator.py:12` — *"arbitrary `veaf.config.XXX = value`"*) — zero
   new plumbing, straight to `veaf.config`, and the three numbers want to live there anyway. Cost: the
   flag sits away from the CTLD block it belongs to, which is exactly the invisibility
   FEAT-CTLD-AUTO-LOGISTICS ticket 01 was opened for — *"a maker who never sees the key cannot know the
   behaviour exists"*.

Whichever is chosen, the scaffold must **emit it** when CTLD is enabled, with a comment saying what it
does, and the disabled form must show the same shape so the key is discoverable before CTLD is switched
on.

### Do

- The flag, default **true**, and the three settings beside it: the zone radius (**250 m**), the
  occupation radius (**2000 m**) and the tick (**30 s**). None of the three is a constant at its call
  site once this ticket lands — 01, 02 and 03 each leave a module-level local to be replaced here.
- `src/defaults/mission-folder/mission.yaml` carries the same keys. The defaults file is a **lockstep**
  obligation (CLAUDE.md §9.7): the shipped default must match what the generator produces, in the same
  lot, and a test already compares the two — keep it green.
- `yaml_validator.py`: accept the keys, reject a non-boolean or a non-number with the same shape of
  message the neighbouring checks use. Do **not** touch the `settings:` rejection.
- With the flag off: nothing registers, no tick is scheduled, no circle is drawn, and the log says the
  feature was **asked to stay off** — not that no airfields were found. The two read the same to a maker
  debugging a mission and only one of them is true.
- Rewrite the documentation, in **both** languages (`doc/` and `doc/mission-maker/` are `.md` + `.en.md`,
  and `docs-check.yml` gates the pair):
  - `doc/MISSION_YAML_REFERENCE.md` + `.en.md`: the new key and the three settings.
  - `doc/mission-maker/GUIDE.md` + `.en.md`, CTLD section, next to what `manage_logistics` already says:
    airfields are logistic zones now, the two classes, the two minutes, the 30 s tick, and the fact that
    occupation counts **ground units** — so a transport landing on a captured field does not open it.
  - The gap David accepted on 2026-09-27, written down rather than discovered in flight: one 250 m zone
    per airfield, centred on the stand nearest the centroid, so on a spread apron an aircraft parked
    beyond 250 m reads *"Aucune logistique à portée"* at an active field — and the radius is the setting
    to raise.
- Amend **ADR 0016** (`docs/adr/0016-ctld2-sidecar-configuration.md`): VEAF now registers logistic zones
  CTLD did not discover, which is a further step past "the sidecar configuration is carried verbatim" —
  `manage_logistics` was the first. One paragraph, not a new ADR; 0018 (*undocumented DCS API
  dependency*) is worth a look while in there, since `Airbase:getParking()` is documented but its
  per-theatre contents are not.
- The messages 02 and 03 added get a line in whatever page lists in-game messages, if one does; ADR 0006
  (`lua-runtime-i18n`) is the rule they follow.

### Watch out

- Do not let the flag reach Lua as a **string**. `manage_logistics` is a boolean in YAML and the
  generated Lua must not become `veaf.config.X = "false"`, which is truthy in Lua and would silently
  enable the feature for every maker who typed the word instead of the value.
- The scaffold emission and the defaults file are the same change: emitting one without the other fails
  the lockstep test.
- A key nobody reads is worse than no key. Grep for the setting's name in `src/scripts/veaf/` before
  declaring this done, and add a Lua test that the module honours it — a Python test proving the YAML
  generates is not the same claim.

### Done when

- A mission scaffolded with CTLD enabled shows the flag and the three numbers in plain sight, with a
  comment saying what they do.
- A mission that sets the flag to `false` registers nothing, schedules nothing, draws nothing, and logs
  that it was asked not to.
- `manage_airbase_logistics: "yes"` (or the chosen key) fails validation with a readable message.
- The lockstep test, `docs-check`, `luacheck`, `stylua --check` and `poetry run test-lua
  --cov-fail-under 80.9` are green.
- ADR 0016 carries the paragraph, and the documentation states the accepted 250 m gap.
