# 07 — Spawn, routes and teleport

Status: 🔄 in-progress — **the enumeration is written** (2026-08-28, below); implementation not started
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
      route arithmetic over it
- [ ] 64 call sites migrated
- [ ] Lua tests covering every branch in the enumeration table, including a group category we spawn but
      MiST handled specially
- [ ] Position asserted against known coordinates, with the convention named in a comment
- [ ] Smoke-harness checks added for placement; anything it cannot reach filed in `DCS-SESSION-TODO.md`
- [ ] `stylua --check` and `luacheck` clean
