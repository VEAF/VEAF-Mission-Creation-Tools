# 09 — The destroyed-scenery register

Status: ⬜ ready
Type: refactor

One call site, and it was ticket 04's tenth line — until reading it showed it is not a helper at all.

## Why it left ticket 04

`mist.getDeadMapObjsInZones(zones)` looks like the other single-caller helpers: twenty lines, called
once. But those twenty lines are a **query over runtime state MiST accumulates**, not a computation:

- it reads [`mist.DBs.deadObjects`](../../../src/scripts/community/mist.lua), a table filled by MiST's
  own `S_EVENT_DEAD` / `S_EVENT_CRASH` handler, one entry per destroyed object with its `objectType`,
  `objectPos` and `typeName`;
- it reads `mist.DBs.zonesByName`, one of the tables ticket 05 decided **not** to port.

So porting it means keeping our own register of destroyed scenery, fed by an event handler, for the
lifetime of the mission. That is a service, and ticket 04 is a prune. Moved here rather than smuggled
in.

## What it is for

[`veafCombatMission.lua:274`](../../../src/scripts/veaf/veafCombatMission.lua), inside
`configureAsPreventDestructionOfSceneryObjectsInZone` — a combat mission objective that **fails** when
a named piece of scenery inside a zone is destroyed. The caller matches `object.object.id_` against a
table of ids it was given, so the register has to keep the DCS object, not just a position.

It is a **documented mission-maker API** (`doc/LUA_API_REFERENCE.md`), and a mission does use it.
Searched across the whole VEAF organisation on 2026-08-28: one caller outside this repository, in
`VEAF-Open-Training-Mission-Caucasus`, `src/scripts/missionConfig.lua`:

```lua
:setName("HVT Gudauta")
:setDescription("the mission will be failed if any of the HVT on Gudauta are destroyed")
:configureAsPreventDestructionOfSceneryObjectsInZone(
    { "Gudauta - Tower", "Gudauta - Kerosen", "Gudauta - Mess" },
    { [156696667] = "Gudauta Tower", [156735615] = "Gudauta Kerosen tankers", [156729386] = "Gudauta mess" })
```

Three scenery objects, by `id_`, in three named zones. The repository is live (last push 2025-09-09).
So this is not a candidate for removal, and that call is the acceptance case: three zones, a table of
ids, and an objective that must fail when one of them is destroyed and only then.

## Shape to consider

- `veafEventHandler` already dispatches events and is the supported way to register a callback — this
  is a normal consumer of it, unlike the Skynet handler in ticket 01 which had to be removable.
- The zone side needs no index at all: `trigger.misc.getZone(name)` is native and gives centre and
  radius, which is exactly what MiST's `getDeadMapObjectsFromPoint` used them for.
- MiST filters on `objectType == "building"`. Establish whether that matters to the one caller before
  reproducing it.

## Definition of done

- [ ] A register of destroyed scenery objects, fed by the event handler, holding what the caller reads
- [ ] `veafCombatMission.lua:274` migrated; `grep 'mist.getDeadMapObjsInZones' src/scripts/veaf/`
      returns nothing
- [ ] Lua tests: an object destroyed inside the zone, one destroyed outside it, one destroyed before
      the objective is configured, and a zone that does not exist
- [ ] The mission-maker documentation for
      `configureAsPreventDestructionOfSceneryObjectsInZone` still describes what the objective does
- [ ] `stylua --check` and `luacheck` clean
