# 09 — The destroyed-scenery register

Status: ✅ done — 2026-08-28
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

- [x] A register of destroyed scenery objects, fed by the event handler, holding what the caller reads
- [x] `veafCombatMission.lua:274` migrated; `grep 'mist.getDeadMapObjsInZones' src/scripts/veaf/`
      returns nothing
- [x] Lua tests: an object destroyed inside the zone, one destroyed outside it, one destroyed before
      the objective is configured, and a zone that does not exist
- [x] The mission-maker documentation for
      `configureAsPreventDestructionOfSceneryObjectsInZone` still describes what the objective does
      — unchanged, because the behaviour is unchanged: `zones` is still honoured
- [x] `stylua --check` clean; `luacheck` left to the CI gate (not installed on this workstation)

## What was built, and the two things the game decided

The register lives in `veafMissionDb`, next to the other things VEAF knows about the mission, rather
than in a module of its own: a new Lua module means editing five separate registries, three of which
fail silently when forgotten.

Measured in game on 2026-08-28 (see the memory note `scenery-death-events-in-dcs`), and both findings
changed the design:

1. **`event.pos` is nil on a scenery death.** Six objects, two scripted explosions, never filled. The
   position can therefore only come from the object itself at the instant of the event — which is why
   `veafEventHandler.transformEvent` now also carries `dcsInitiator`, the untransformed DCS object.
   Without it the register could hold ids but never place them, and the `zones` argument would have
   had to be dropped from a documented mission-maker API.
2. **`Object.isExist` is already false, while `Object.getPosition` still answers.** MiST guarded on
   `isExist`, so it recorded nothing for those six objects: `mist.DBs.deadObjects` held 11 unrelated
   entries and none of the ones just destroyed. The register does not ask.

`getName()` on a scenery object returns a **number**, equal to `id_` — the same number the mission
maker writes in the objective's table, so no conversion is needed anywhere.

## Wiring, and why it is tested

`veaf_build/worker.py` loads `veafMissionDb` **before** `veafEventHandler`, so the subscription cannot
happen at load time. It happens in `initialize`, which runs twice — once at load, once on the module
init pass — behind a guard, because a callback registered twice records every destruction twice. That
is the exact shape of the double event handler fixed in 6.17.0 (#824).

Three of the fifteen tests assert the **subscription**, not the handler, and were verified to fail
when the subscription is removed.
