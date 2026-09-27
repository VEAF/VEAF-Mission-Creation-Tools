---
Status: ⬜ ready — every decision is taken and nothing waits on a measurement; ready for tickets
---

# FEAT-CTLD-AIRBASE-LOGISTICS — airfields are outside CTLD's logistic system, and VEAF can put them in without touching CTLD

## The report, and what measuring it found

[Issue #1007](https://github.com/VEAF/VEAF-Open-Training-Mission-GermanyCW-v6/issues/1007): a C-130
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

### What this design does not need

No mission-file surgery — the builder reads trigger zones for validation
(`mission_builder_worker.py:1471`) but no zone-writing path was found in `mission_builder_worker.py`
or `miz_tools.py`, and none has to be built. No circular footprint drawn by hand over a real
airfield. No dependency on a data dump. No upstream release.

## What remains to settle

Three implementation details, none of them a design question.

**1. The tick interval.** A front does not move in seconds, so the interval can be generous; the
class-A checks are cheap but the class-B probes are not free. Whatever it is, it belongs in the module's
settings next to the 250 m and the 2000 m, not hard-coded.

**2. The stub's contract.** The comment above the function (`:676-680`) states that a logistic point
*is* an `LGZ_` zone, declared in `ctld-config.yaml`, with *"nothing to run"*. Giving the function a body
contradicts it, so the comment is rewritten in the same change, and ADR 0016 likely needs a line: it
already stopped being strictly "verbatim" with `manage_logistics`.

**3. Where the snapshot can be wrong.** Class A is decided on the first evaluation, so a mission script
that captures an airfield in its opening seconds — a T+0 trigger — could have the field classified B and
owing two minutes it should not owe. Unlikely, cheap to note, and cheaper to note than to discover in
flight.

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

## Definition of done

Nothing is left to decide, and **nothing is left to measure**: the placement rule stands on its own and
the verification happens in flight, on the mission that reported the issue. Done looks like:

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
- The log says how many airfields VEAF registered and which class each one is in.
- A mission that wants none of it can say so, and says so in `mission.yaml`.
