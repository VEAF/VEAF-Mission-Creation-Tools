# 04 — Prune the single-caller helpers

Status: ✅ done — 2026-08-28
Type: refactor

Rule 3 in its purest form: **314 MiST lines reached by 11 calls**, eight of them exactly once. Each is
replaced by the slice we actually use, not by a port of the function.

**Re-counted before starting: 7 of those 11 calls are live.** Three are commented-out lines, and one
of the remaining seven turned out not to be a helper at all — see below.

## The list

| Function | MiST lines | Calls | What we use it for |
|---|---:|---:|---|
| `mist.utils.converter` | **131** | **1** | one unit conversion — find which, port that line |
| `mist.utils.dostring` | 29 | 1 | evaluating a Lua string |
| `mist.utils.zoneToVec3` | 25 | 1 | a trigger zone's centre as a vec3 |
| `mist.getAvgPos` | 24 | 1 | average position of a unit list |
| `mist.getUnitsInPolygon` | 23 | 1 | units inside an arbitrary polygon |
| `mist.getDeadMapObjsInZones` | 20 | 1 | destroyed scenery in a zone |
| `mist.getAvgGroupPos` | 16 | 1 | average position of a group |
| `mist.utils.getHeadingPoints` | 13 | 1 | heading between two points |
| `mist.getNextUnitId` | 10 | 1 | the next free unit id |
| `mist.utils.getQFE` | 23 | 2 | QFE from QNH and altitude |

## Method, per function

1. Read the **one** call site and write down the exact inputs it passes and the shape it expects back.
2. Read the MiST implementation and identify the branch that call takes.
3. Port **that branch**. Delete the rest without reimplementing it.
4. Write the test from the call site's real inputs, not from the function's full contract.

`mist.utils.converter` is the case worth doing first — 131 lines for one call means we are almost
certainly using one conversion pair out of a generic table of them.

## Two that need a second look, not a mechanical port

- **`mist.getNextUnitId`** is not a helper, it is **shared mutable state**: MiST keeps a counter and
  skips the 6900–30000 band. If VEAF and MiST both allocate ids from the same space while both are
  loaded, our replacement must not hand out an id MiST has already used — during the campaign both run
  side by side. Establish who else allocates unit ids (the MCP and the builder assign them at design
  time too) before choosing a scheme, and record it.
- **`mist.utils.dostring`** evaluates a Lua string. Check what our single call site feeds it and whether
  it crosses a security boundary — `veafSecurity` exists, and `REVIEW-SECURITY-LAYER` closed findings in
  this area. If the input is anything other than our own literal, this becomes a security ticket rather
  than a port, and it stops being a rule 3 prune.

## Three of the eleven calls are commented out — including the security question

- **`mist.utils.dostring` has no live caller.** The ticket asked whether its input crosses a security
  boundary. It does not, because the call is gone: `veafRemote.lua:167` is the *comment* recording that
  VMR-130 removed the SLMOD bridge, and it says exactly why — *"a `mist.utils.dostring` of arbitrary Lua
  behind a shared password"*. The concern was real and was already answered; nothing to port.
- **`mist.utils.getQFE`** — two commented-out lines in `veafTransportMission`, next to the commented-out
  message that would have printed them.
- **`mist.utils.getHeadingPoints`** — inside a commented-out block in `veafUnits` that would have
  oriented a convoy on the nearest road.

None is ported. Rule 3 does not stop at "port only the branch we call": a function nothing calls is a
function we do not have. The commented-out lines are left where they are — deleting other people's
parked code is not this ticket's business — but they now name a function that will not exist after
ticket 08, which is worth one line in that ticket.

## One was not a helper, and left for ticket 09

`mist.getDeadMapObjsInZones` reads `mist.DBs.deadObjects`, a table MiST fills from its own
`S_EVENT_DEAD` handler, plus `mist.DBs.zonesByName`, which ticket 05 decided not to port. Porting it
means keeping a **register of destroyed scenery fed by events** for the whole mission — a service, not
a slice. Moved to [ticket 09](09-the-destroyed-scenery-register.md) rather than smuggled into a prune.

## What the seven live calls became

| Was | Is | Note |
|---|---|---|
| `mist.utils.converter("hpa", "inhg", p)` | `veaf.hPaToInHg(p)` | 131 MiST lines reached for one multiplication |
| `mist.utils.zoneToVec3(name)` | `veaf.zoneToVec3(name)` | **nil, not `{}`**, for a zone that does not exist — see below |
| `mist.getAvgPos(names)` | `veaf.getAvgPos(names)` | |
| `mist.getAvgGroupPos(group)` | `veaf.getAvgGroupPos(group)` | walks `getUnits()` rather than `getSize()`/`getUnit(i)` |
| `mist.getUnitsInPolygon(names, poly)` | `veaf.getUnitsInPolygon(names, poly)` | |
| `mist.pointInPolygon(point, poly)` | `veaf.pointInPolygon(point, poly)` | **pulled out of ticket 06**: `getUnitsInPolygon` is built on it, so porting one without the other would leave a MiST call inside a VEAF function. 4 more call sites migrated with it |
| `mist.getNextUnitId()` | `veaf.getNextUnitId()` | new `veafMissionDb.lua`, see below |

## A dead guard, brought back to life

`veafCombatZone:initialize` has always carried this:

```lua
self.zoneCenter = veaf.zoneToVec3(self.missionEditorZoneName)
if not self.zoneCenter then
  -- "Trigger zone [x] does not exist in the mission !", logged and shown to the pilot
```

**That branch could never run.** MiST's `zoneToVec3` answers `{}` for an unknown zone, and a table is
truthy in Lua. The port answers `nil`, so the guard works for the first time — and fifteen tests in
`test_veafCombatZone` turned out to be running against a zone the mock had never registered, which
`{}` had been hiding. They now register it, which is what a mission does.

## The id allocation scheme

`veafMissionDb.lua` is new, and starts life with the id allocator; ticket 05 will add the index, the
name registry and the player roster to it.

Ids start at **200000**. Three things have to be avoided: the ids the Mission Editor assigned (three or
four digits), the 6900–30000 band DCS reserves, and — while MiST is still injected — MiST's own
counter, which starts at the mission's highest id and jumps to 30000 once past 6900. MiST would have to
allocate 170 000 units in one session to reach us.

**This is a quantitative guarantee, not a structural one**, and it is worth saying plainly: nothing
prevents a collision by construction while both allocators run. It stops mattering at ticket 08. The
alternative — reading MiST's counter — would have been a new dependency in a lot whose purpose is to
remove them.

## Definition of done

- [x] Each live function is replaced by the slice its call site uses, in `veafMath.lua`, `veafGeo.lua`
      or `veafMissionDb.lua`
- [x] The 7 live call sites are migrated, plus the 4 `pointInPolygon` sites pulled from ticket 06
- [x] One test per function, written from the real call site's inputs
- [x] `getNextUnitId`: the scheme is decided and written down, with its guarantee stated honestly
- [x] `dostring`: established — no live caller; the security concern was closed by VMR-130
- [x] `stylua --check` and `luacheck` clean
