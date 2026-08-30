# 07 — Spawn, routes and teleport

Status: 🔄 in-progress — enumeration written and **half (A) shipped** (2026-08-28); half (B) not started
Type: refactor

80 call sites over **726 MiST lines** — the functional core of the dependency, and the reason this lot
is a campaign rather than a ticket. Every VEAF spawn path ends up here.

## The list

| Function | Calls | MiST lines | What it does |
|---|---:|---:|---|
| `mist.dynAddStatic` | 18 | 102 | create a static object at runtime |
| `mist.dynAdd` | 17 | 222 | create a group at runtime |
| `mist.teleportToPoint` | 15 | 223 | move a group, route and all |
| `mist.goRoute` | 11 | 24 | push a route onto a group |
| `mist.getGroupRoute` | 11 | 70 | read a group's route |
| `mist.getGroupData` | 4 | 70 | read a group's record |
| `mist.respawnGroup` | 4 | 15 | respawn a group in place |

## Start from what is already known to be right

The #290 investigation read `mist.teleportToPoint` **end to end** and found it correct: it deep-copies
the route, translates every waypoint by the teleport delta, and hands the group to `dynAdd` with its
route attached. That is recorded in `ROADMAP.md` and it matters here for two reasons.

First, this is not a rewrite motivated by a bug — the behaviour to reproduce is the behaviour we have,
and any divergence is a regression rather than an improvement. Second, `teleportToPoint` **calls
`dynAdd`**, so the two are one problem: port `dynAdd` first and `teleportToPoint` becomes route
arithmetic on top of it.

## The dependency, settled

Ticket 00 read every database access these seven functions make. **None of them needs a live index.**

| MiST function | What it reads | Needs |
|---|---|---|
| `mist.getGroupRoute` | `MEgroupsByName` for the id, then walks `env.mission` | editor snapshot |
| `mist.getGroupData` | `groupsByName`, plus a partial-name match no VEAF caller relies on | editor snapshot |
| `mist.teleportToPoint` | `groupsByName` to fill in `country` / `category` when the caller omits them | editor snapshot |
| `mist.getCurrentGroupData` (the `teleport` action) | `unitsByName`, to enrich each unit with skill and callsign — with a complete native fallback in its `else` branch | nothing hard |
| `mist.dynAdd` | `groupsByName` / `unitsByName`, **only on the `clone` path**, to decide whether a name is free | the name registry |

All 15 `teleportToPoint`, 4 `respawnGroup` and both `veafSpawnAircraft` clone sites start from an
**editor** group name — a template, a Pedro, a carrier, an asset. VEAF never respawns or clones a group
it created itself.

So this ticket depends on **two named bricks from ticket 05**, not on its index:

1. the **editor snapshot** of groups and units, and
2. the **name registry** — which is what `veafSpawnAircraft.lua:788-789` hand-rolls today by deleting
   two `mist.DBs` entries so a dead AFAC's callsign can be reused. Port `dynAdd`'s uniqueness test
   against the registry, and that workaround disappears with it.

05 still lands first because both bricks live there. If 05 grows, those two can be split out and
reviewed on their own without holding this ticket.

## Method

Rule 3 applies hard here. `mist.dynAdd`'s 222 lines handle every group category, every spawn variant
and a long tail of DCS quirks. Enumerate — from the code, not by sampling — which of those paths our 17
call sites actually reach, and port those. A category we never spawn is not ported.

**The enumeration is the deliverable, not a by-product.** Write it as a table in this ticket before
touching code: call site → group category → the `dynAdd` branch it takes. That table is also the test
matrix.

## The enumeration, 2026-08-28 — written before touching code, as this ticket requires

### The count, re-measured

**64 real call sites, not 80.** The difference is not slack in the estimate: 16 of the 80 grep hits are
comments, log traces or commented-out code, and one is a defensive guard on MiST's own presence.

| Function | grep hits | **Real calls** | What the difference is |
|---|---:|---:|---|
| `mist.dynAddStatic` | 18 | **18** | — |
| `mist.dynAdd` | 18 | **13** | 2 comments, 3 log traces (`veafSpawnAircraft` 1163/1169/1170) |
| `mist.teleportToPoint` | 15 | **12** | 3 comments/traces in `veafCombatZone` |
| `mist.goRoute` | 11 | **9** | 2 commented out (`veafMove:838`, `veafSpawnAircraft:686`) |
| `mist.getGroupRoute` | 11 | **8** | 2 comments, 1 presence guard (`veafCombatZone:442`) |
| `mist.getGroupData` | 4 | **3** | 1 is `veaf.mist.getGroupData`, the façade the other two go through |
| `mist.respawnGroup` | 3 | **2** | 1 commented out (`veafTransportMission:672`) |

### `dynAdd` — call site → category → branch

The 13 real calls, and the branch each one reaches:

| Call site | What it creates | Category passed | Branch |
|---|---|---|---|
| `veafCasMission.lua:1039` | a CAS threat package | `"GROUND_UNIT"` | ground |
| `veafCombatMission.lua:924` | a combat-mission flight | **variable** (`_group.category`) | any |
| `veafGrass.lua:1481` | the FARP group | variable (caller's `country`/category) | ground |
| `veafGrass.lua:1890` | the FARP escort | variable | ground |
| `veafSpawnAircraft.lua:191` | a spawned plane | **`"PLANE"`** | airplane |
| `veafSpawnAircraft.lua:194` | a spawned ship | `"SHIP"` | ship |
| `veafSpawnAircraft.lua:197` | spawned ground units | `"GROUND_UNIT"` | ground |
| `veafSpawnAircraft.lua:681` | a cloned aircraft group | variable, `sameName = true` | any + clone |
| `veafSpawnAircraft.lua:1164` | a spawned aircraft group | variable | any |
| `veafSpawnCore.lua:792` | a ship | `"SHIP"` | ship |
| `veafSpawnCore.lua:794` | an aircraft | **`"AIRPLANE"`** | airplane |
| `veafSpawnCore.lua:796` | ground units | `"GROUND_UNIT"` | ground |
| `veafSpawnGround.lua:381` | ground units | `"GROUND_UNIT"` | ground |

**Four categories are reached: GROUND_UNIT, AIRPLANE, SHIP — and whatever a variable carries.**
`HELICOPTER` never appears as a literal, but `veafCombatMission:924`, `veafSpawnAircraft:681` and
`:1164` pass a group table built from a template, so a helicopter template reaches `dynAdd` through
them. **`BUILDING` is never reached** — statics go through `dynAddStatic`.

#### The naming tolerance that must be reproduced

`veafSpawnAircraft:191` passes **`"PLANE"`** while `veafSpawnCore:794` passes **`"AIRPLANE"`** for the
same thing. That is not a bug: [`mist.lua:1919-1922`](../../../src/scripts/community/mist.lua) maps
them explicitly, along with two more spellings for ground:

```lua
if catName == "GROUND_UNIT" and (string.upper(groupType) == "VEHICLE" or string.upper(groupType) == "GROUND") then
  newCat = "GROUND_UNIT"
elseif catName == "AIRPLANE" and string.upper(groupType) == "PLANE" then
  newCat = "AIRPLANE"
end
```

**A port that accepts only the canonical spelling silently breaks `veafSpawnAircraft:191`** — silently,
because an unresolved category leaves `typeName` nil and the group is built anyway. Accept
`PLANE`/`AIRPLANE`, `VEHICLE`/`GROUND`/`GROUND_UNIT`, and the numeric ids, and make the mismatch loud
rather than nil.

### `dynAddStatic` — 18 calls, and 12 of them are one feature

| Call site(s) | What it creates |
|---|---|
| `veafGrass.lua` 613, 621, 627, 647, 653, 673 | grass runway plots and the tower |
| `veafGrass.lua` 1622, 1645, 1663, 1710, 1779, 1801 | FARP tents, markers, other props, windsock |
| `veafSpawnGround.lua` 105, 183, 197 | the FARP static, an outpost, a tower |
| `veafSpawnEffects.lua` 137, 214 | cargo, and a static object |
| `veafSpawnAircraft.lua:187` | a static aircraft |

Two thirds of the surface is `veafGrass` placing FARP and runway furniture. **That makes `veafGrass` the
test bed for this half**: one feature, many objects, and a placement already verified in game on
2026-08-24 and again on 2026-08-28.

### `respawnGroup`, `getGroupData`, `getGroupRoute`, `goRoute`, `teleportToPoint`

- **`respawnGroup`** — 2 calls, both in `veafAssets.respawn` (the asset itself, then each `linked`
  group). Both start from an **editor** group name. Note that
  [`FIX-ESCORT-RESPAWN-DISTANCE`](../../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md) will add a third here.
- **`getGroupData`** — 1 direct call (`veafAirWaves:1022`) plus `veaf.mist.getGroupData`, through which
  `veafCarrierOperations` 342 and 488 ask whether a Pedro or a tanker exists in the mission at all.
- **`getGroupRoute`** — 8 calls, **every one with `"task"` as the second argument**. The other output
  form is never asked for and does not need porting.
- **`goRoute`** — 9 calls. Two take a group *object* (`veaf.lua:1943`, `veafSpawnCore:420/422`), the
  rest a group *name*. Both forms have to keep working.
- **`teleportToPoint`** — 12 calls. Two pass the second argument `true` (`veafSpawnAircraft` 648 and
  1133, `veafCombatMission:898`); the others rely on the default.

### One thing the port removes for free

[`veafCombatZone.lua:442`](../../../src/scripts/veaf/veafCombatZone.lua) guards on MiST being loaded at
all:

```lua
if not name or not mist or not mist.getGroupRoute then
```

That guard exists because a mission can load a hand-picked subset of scripts. Once the route reader is
VEAF's own and ships in the bundle, the guard is dead weight — and it is the kind of dead guard ticket
04 has been removing.

### What this changes for the plan

- The two bricks ticket 05 was to provide are **shipped**: `veafMissionDb` carries the editor snapshot
  and the name registry. This ticket is unblocked.
- The work splits cleanly in two, and the halves are independent:
  **(A)** `dynAddStatic` — 18 calls, no route, no clone path, two thirds of them one feature.
  **(B)** `dynAdd` → `teleportToPoint` → `goRoute`/`getGroupRoute` — the group half, where the clone
  path, the id allocation and the route arithmetic live.
  **(A) should ship first**: it is the larger call count, the smaller risk, and it exercises the
  coordinate convention on its own before any route arithmetic is layered on top.

### Half (A) — `dynAddStatic`, read end to end 2026-08-28

Its 100 lines do eight things, in order: flatten a MiST-format `units[1]` into the object; resolve the
country (a string with spaces becomes underscores, or a numeric id) and **fail loudly** if it does not
resolve; allocate `groupId` and `unitId` when absent or when cloning; name the object
(`name or unitName`, else `"<country> static N"`); default `dead` to false; give it a **random heading**
when none is set; map `categoryStatic` onto `category` and force `"Cargos"` when `mass` is present;
resolve `shape_name`. Then it validates `x`, `y` and `type` and calls
`coalition.addStaticObject(country.id[newCountry], newObj)`.

Four things decided by reading our own 18 call sites:

**1. The `shape_name` lookup has to be ported, and the number that justifies it is 93.**
`mist.DBs.const.shapeNames` holds **124 entries**, and the objects that most obviously need it do not
use it: the FARP passes `shape_name` explicitly (`veafSpawnGround.lua:86`), so do the windsock and the
runway cones. `"outpost"` and `"house2arm"` are not in the table at all, so the lookup is a no-op for
them.

What makes it necessary is `veafSpawnEffects.lua:214`. Despite the file's name that call is **not an
effect**: it is `doSpawnStatic`, the function behind `-spawn static`, and the `type` comes from the
mission maker, validated against the 873-unit catalogue by `veafUnits.findDcsUnit`. Crossing the two
tables: **93 of the catalogue's types are keys of `shapeNames`** — `.Ammunition depot`,
`.Command Center`, `Barracks 2`, `Cafe`, `Boiler-house A`, `Airshow_Crowd` and so on, all structures.

So 93 spawnable statics get their shape from this table and from nowhere else. The remaining 31 entries
are shapes only the Mission Editor places, and no VEAF command can reach them. The table is a constant,
so porting it is mechanical — but port it against the catalogue rather than wholesale, and skipping it
would break exactly the spawns nobody tests.

**2. `veafSpawnAircraft.lua:187` is the only site using the MiST wrapper format** —
`{ country, groupName, units = units }` rather than a flat object — so it is the only one that exercises
the `units[1]` flattening at the top. It is also the only one that must keep working through it.

**3. The random heading is behaviour, not a detail.** An object spawned without a heading gets
`math.rad(math.random(360))`. Several of our statics rely on that (nothing in `veafSpawnEffects` sets a
heading), so a port that defaults to 0 would line up every cargo drop on the same axis — a visible
change in game that no unit test would catch.

**4. `mass` silently overrides `category`.** `veafSpawnEffects.lua:132` passes both `category = "Cargos"`
and `mass`, so the override is a no-op there today — but it is the kind of rule that has to be ported
deliberately rather than discovered later.

Coordinate note, per the trap above: a static's table uses `x` for the northing and **`y` for the
easting** — `veafSpawnGround.lua:89` writes `["y"] = spawnPosition.z`. The port must not "fix" that.

### Half (B) — `dynAdd` and the route calls, read 2026-08-28

`dynAdd`'s 222 lines do, in order: resolve the country; resolve the category (with the alias table
above); pick a `typeName` marker used only for generated names; allocate a group id; settle the group
name; default `sameName`, `hidden`, `visible`, `start_time`; then per unit — allocate a unit id, settle
the unit name, default `skill` to `"Random"`, and for **aircraft only** default `alt_type` to `RADIO`,
`speed` to 150 (plane) or 60 (helicopter), `alt` to 2000 or 500, and **fetch the payload** through
`mist.getPayload`; for ground units default `playerCanDrive` to true. Then it normalises the route,
rewrites `EPLRS` / `ActivateBeacon` / `ActivateICLS` task ids, strips its own bookkeeping fields, and
calls `coalition.addGroup`.

Measured against our 13 call sites, three things shrink the job and one grows it:

**1. The clone path is never reached directly.** Every `clone` in VEAF is a `teleportToPoint`
parameter, never a `dynAdd` one. So `dynAdd`'s name-uniqueness test against `mist.DBs` is reached only
*through* the teleport, which means the name registry from ticket 05 is needed once, in one place,
rather than at every call site. (The count of those sites was corrected to 5 — see above.)

**2. `newGroup.sameName = true` at `veafSpawnAircraft.lua:676` is a no-op.** MiST reads `sameName` only
inside `if newGroup.clone and …`, and that site passes no `clone`. It has never done anything. Port it
as inert — this ticket must not change behaviour — but it is worth knowing that the AFAC teleport
trickery next to it (its own comment: *"since MIST does not store cloned group data, this is a bit of
trickery"*) rests on a flag that does nothing.

**3. `playerCanDrive` and `start_time` are never set by a caller**, so their defaults are the behaviour
and have to be reproduced exactly. `startTime` (camel case, rounded) is used by `veafCombatMission`.

**4. `mist.getPayload` has to be ported, and the snapshot does not carry what it needs.** `dynAdd`
calls it for any aircraft unit with no payload, and `veafSpawnCore.lua:794` builds `AIRPLANE` groups
with **no payload field at all** — grep finds none in that file. `getPayload` reads
`mist.DBs.MEunitsByName` for the unit id and then walks `env.mission` for the loadout;
`veafMissionDb.unitRecord` deliberately keeps only what VEAF reads, and a payload is not among its
fields.

**Decided 2026-08-28, by measurement: the snapshot carries the payload.** The question was whether that
costs memory for every mission. Measured on the session mission — 435 units, 356 payload blocks — the
payloads are **287 KB, 10.7 % of a 2.7 MB mission file**, which looked like a real price. It is not,
because `mist.getPayload` ends with `return unitData.payload`: **a reference into `env.mission`, never a
copy**. Holding the same reference in a unit record costs one pointer per unit, and `env.mission` is
resident anyway.

Two consequences worth writing down. It is iso-behaviour including the sharing: a spawned group that
mutates its payload mutates the mission table, exactly as it does today under MiST — reproduce it, do
not "fix" it in this ticket. And it removes the walk: `getPayload` searches every coalition, country and
group to find one unit, on every aircraft spawn without a loadout.

The three route functions are the easy end: `getGroupRoute` is always called with `"task"`, `goRoute`
takes either a group object or a name, and `teleportToPoint` is route arithmetic over `dynAdd` — the
#290 investigation already read it end to end and found it correct.

### The API half (B) ships — decided with David, 2026-08-28

The port is not allowed to change *behaviour*, but it is allowed to change the *interface* — and
`mist.teleportToPoint` has one worth replacing. David's words: *"j'espère que tu as prévu d'implémenter
de jolies fonctions pour remplacer les bricolages du type `vars.action = \"clone\"` ? … avec de vrais
paramètres, bien clairs"*.

#### What the `vars` table was hiding

It is not a parameter object, it is **three different verbs behind a string**, plus a fourth behind an
unnamed boolean:

| `vars.action` | What it really does | Where the data comes from |
|---|---|---|
| `"clone"` | creates a **new** group with new names | the editor definition, plus a `clone = "order66"` flag |
| `"respawn"` | puts **the same** group back as the editor placed it | the editor definition |
| `"teleport"` / `"tele"` | moves the group **as it is right now** | its live state |
| *(2nd arg `true`)* | builds the data and creates **nothing** | — |

**Corrected 2026-08-28**: an earlier count here said no site used `teleport`. That was wrong — it came
from grepping `vars.action =` as a separate assignment, which misses the sites that build the table in
one expression. The real count is **clone 5, respawn 3, teleport 5**, so all three verbs are in use and
`getCurrentGroupData` has to be ported after all. The three sites passing the unnamed `true` are all
clones.

#### The shape chosen: chaining, not an options table

Three writings were compared on `veafQraCore.lua:1022`. An options table is the closest Lua has to
Python's keyword arguments — and it keeps `vars`'s worst property: **nobody validates the keys**, so
`{ radus = 500 }` is silently a zero radius. Positional arguments would give
`veaf.cloneGroupAt(name, point, 500, route, nil, nil, false)`.

Chaining wins because the repository already speaks it — **150 chainable `:setXxx` methods** across
`VeafCircleOnMap`, `VeafCombatMissionObjective`, `VeafCombatZone` and the rest — and because a typo in a
method name fails loudly where a typo in a table key does not.

```lua
local newGroup = VeafGroupSpawn:new()
  :forGroup(groupName)
  :at(spawnPoint)
  :withRadius(self.respawnRadius)
  :withRoute(veaf.getGroupRoute(groupName))
  :clone()
```

The terminal verb carries what `vars.action` used to: `:clone()`, `:respawn()`, `:teleport()`, and
`:buildCloneData()` for the prepare-only case. So the action can no longer be a misspelled string, and
an unfinished chain creates nothing rather than silently defaulting to `tele` — which is what MiST does
today when `action` is unrecognised.

`withRadius` also absorbs the three lines of `point.z = point.y` juggling copied at every call site —
the exact place where `FIX-AIRWAVES-COMMAND-EASTING` slipped in.

#### Order of work

1. ~~`veafDcsSpawner.addGroup`~~ — **shipped 2026-08-28**, and it refuses an unknown category rather
   than submitting an unclassifiable group.
2. ~~`veaf.getGroupRoute` / `veaf.goRoute`~~ — **shipped 2026-08-28**, and the mission snapshot gained
   the route and the payload by reference to serve them.
3. ~~`VeafGroupSpawn` over both, replacing `teleportToPoint`~~ — **shipped 2026-08-28**, all 12 sites
   migrated. Its two bricks shipped the same day:
   `veaf.isTerrainValid` (with the per-category surface lists) and `veaf.getCurrentGroupData` (the
   source the `teleport` verb reads).
4. Migrate the 42 remaining call sites.

### `teleportToPoint`, read 2026-08-28 — what the chain has to carry

Beyond the three verbs, its 223 lines do four things that are behaviour and not plumbing:

- **A valid-terrain draw.** It tries up to 100 random points in the circle and keeps the first whose
  terrain suits the group: ships get `SHALLOW_WATER`/`WATER`, ground units `LAND`/`ROAD`/`RUNWAY` — with
  a VEAF comment from 2023 explaining that runways are included because DCS calls dams "RUNWAY". A
  caller can override with `validTerrain`, or skip the check with `anyTerrain`, which `veafMove` uses
  for its AFAC. So the chain needs `:onAnyTerrain()` and `:onTerrain(list)`.
- **The whole group moves by one offset.** The draw positions unit 1; every other unit keeps its
  formation by moving the same `diff`. Unless `disperse` is set, in which case each unit gets its own
  draw within `maxDisp`.
- **An altitude rule for aircraft.** If the requested point is more than 10 m above the ground, it is
  used; otherwise the aircraft is placed at a **random** height above terrain — 300–9000 m for a plane,
  200–3000 m for a helicopter. That randomness is behaviour: a fleet of respawned aircraft stacked at
  one altitude would look wrong.
- **A start time relative to now.** A group whose editor `start_time` has already passed spawns
  immediately; one still in the future keeps the remainder.

Plus `groupData`, which `veafMove` passes for its AFAC instead of a group name — hence `:withGroupData()`
on the chain.

## Two traps

- **Coordinates.** `dynAdd` and `dynAddStatic` place objects, so
  [`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) is mandatory reading:
  `x`/`y`/`z` mean different things in a mission table and in the scripting API, and confusing them
  raises no error — only a wrong position. This is the single most likely way to ship a silent
  regression in this ticket.
- **Group and unit ids.** `dynAdd` allocates ids. Ticket 04 settles the allocation scheme for
  `getNextUnitId`; this ticket must use it, and must not collide with MiST's counter while both are
  loaded.

## Verification

Unit tests cannot see whether a group actually appeared at the right place in DCS. Two things carry that:

- `FEAT-DCS-SMOKE-HARNESS` (closed 2026-08-15) asserts through the bridge inside a running DCS and has
  already answered spawn-placement questions by machine rather than by a pilot. **Use it here** — this
  is exactly the lot it was built for.
- Whatever the harness cannot reach goes into [`DCS-SESSION-TODO.md`](../../../DCS-SESSION-TODO.md) with
  the commands to paste, not into a "verified" checkbox.

## Definition of done

- [x] Ticket 05 has shipped the editor snapshot and the name registry (`veafMissionDb`), and this
      ticket uses them
- [x] The call-site → category → branch enumeration is written in this ticket **before** implementation
      — done 2026-08-28; it re-counted the slice at **64 real calls, not 80**
- [ ] Ported into a dedicated module behind `veaf.*` façades; `dynAdd` first, then `teleportToPoint` as
      route arithmetic over it — **`veafDcsSpawner.lua` created**, `veaf.addStatic` shipped
- [ ] 64 call sites migrated — **60 done**: `dynAddStatic` (18), `getGroupRoute` (8), `goRoute` (9),
      `dynAdd` (13) and `teleportToPoint` (12). Left: `getGroupData` (3) and `respawnGroup` (2)
- [ ] Lua tests covering every branch in the enumeration table, including a group category we spawn but
      MiST handled specially
- [ ] Position asserted against known coordinates, with the convention named in a comment
- [ ] Smoke-harness checks added for placement; anything it cannot reach filed in `DCS-SESSION-TODO.md`
- [ ] `stylua --check` and `luacheck` clean
