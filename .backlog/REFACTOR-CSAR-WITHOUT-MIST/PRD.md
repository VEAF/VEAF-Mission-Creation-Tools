# REFACTOR-CSAR-WITHOUT-MIST — cut CSAR's 18 calls to MiST

Status: ✅ done — checked in game 2026-08-31, and it found two defects

Origin: David, 2026-08-28, on `DROP-MIST` ticket 08 — *"CSAR : comme pour CTLD, on pourrait s'affranchir
de MiST ; c'est un script qu'on a repris aussi je crois (pas vendored), donc on peut le modifier non ?
Sans utiliser les stub VEAF..."*.

## Why CSAR and not the others

Four community scripts appeared to need MiST. Re-counted properly — the first pass mistook comments
for calls — the picture is:

| Script | Real calls | Status |
|---|---:|---|
| `skynet-iads-compiled.lua` | 33 | a **compiled artefact** of an upstream fork; patching it here is overwritten on the next regeneration |
| **`CSAR.lua`** | **18** | **this lot** |
| `Hercules_Cargo.lua` | 3 | removed entirely — `CHORE-DROP-HERCULES-SCRIPT` |
| `CTLD.lua` | **0** | already free of MiST in v2, on its own |

CTLD proves the trajectory exists on the biggest of them. CSAR is next because **VEAF already owns it
in practice**: `FIX-CSAR-HANDLE-EJECT-ARGUMENT` put a local replacement in it, on the recorded grounds
that upstream is `ahead=0` and untouched since August 2023, so a PR there would not land.

## The 18 calls, and what already exists to replace them

| MiST call | Uses | VEAF equivalent |
|---|---:|---|
| `mist.getLLString` | 2 | `veafGeo.toStringLL` ✅ |
| `mist.getMGRSString` | 1 | `veafGeo.toStringMGRS` ✅ |
| `mist.utils.zoneToVec` | 1 | `veafGeo.zoneToVec3` ✅ |
| `mist.getRandomPointInZone` | 1 | `veafGeo.getRandomPointInCircle` + `trigger.misc.getZone` ✅ |
| `mist.getNextUnitId` / `getNextGroupId` | 2 | `veafMissionDb.getNextUnitId` ✅ |
| `mist.getHeading` | 1 | `veafGeo.getHeading` ✅ |
| `mist.dynAdd` | 1 | `veafDcsSpawner.addGroup` ✅ |
| `mist.vec.mag` | 1 | `veafMath.vecMag` ✅ |
| `mist.vec.sub` | 1 | **missing** — trivial, and `vecAdd` is right beside it |
| `mist.vec.dp` | 2 | **missing** — a dot product |
| `mist.ground.buildWP` | 2 | **missing** — turns a point into a route waypoint, handling the vec2/vec3 `y`/`z` swap and default speed/formation |
| `mist.getBRString` | 2 | **missing** — bearing and range as text |
| `mist.DBs.unitsById` | 1 | **partial** — `veafMissionDb` indexes units by *name*, not by id |

**Eleven of the eighteen already have a home.** Four small functions and one index are what the lot
actually has to build, and none of them is CSAR-specific: `vecSub` and a dot product belong in
`veafMath`, `buildWP` and `getBRString` in `veafGeo`, and an id index next to the name one.

## David's constraint: no VEAF stubs

*"Sans utiliser les stub VEAF"* — do not shim `mist.*` inside CSAR to point at VEAF functions. Rewrite
the call sites. A shim would keep the MiST vocabulary alive inside a file we own, which is the state
`veaf.mist.*` is already in and which ticket 08 will have to clean up anyway.

## What this must not break

CSAR decides whether a downed pilot is findable and reachable. `FIX-CSAR-SPAWNS-ON-WATER` exists
because that area was wrong once already, and `resolveCsarSurvivorPoint` was written for it. Every
replacement keeps its current answer, asserted by a test **before** the call is switched.

Two are riskier than they look:

- **`mist.ground.buildWP`** does the mission-table `y` = easting conversion internally. Replacing it
  without reproducing that is the silent-misplacement failure this repository has met repeatedly.
- **`mist.DBs.unitsById`** is a lookup by runtime id. The snapshot is keyed by name; adding an id index
  is easy, but the two are not interchangeable — a dynamically spawned unit has an id and no editor
  record.

## Sequencing

Independent of `DROP-MIST` ticket 08 and can land before or after it. Landing it **first** is worth more:
it takes CSAR off the list of reasons MiST must be injected, leaving only Skynet.

## What the vendoring manifest had to say about it

`vendored.yaml` records CSAR as `source: VEAF/DCS-CSAR`, `upstream: ciribob/DCS-CSAR`,
**`vendoring: adapted`** — so adapting it is the declared process, not a liberty taken here.

Its `manual_steps` line is what makes the adaptation survive: it tells whoever next syncs from upstream
what to re-apply. It now names this change, because **a straight copy from ciribob would put MiST back
and make CSAR refuse to start** in a mission that no longer injects it. That is the silent regression
this lot would otherwise have planted for its own future.


## Checked in game, 2026-08-31

All four steps, in one session:

| step | result |
|---|---|
| **Downed pilot appears** | `Wounded Pilot #200084` — the id comes from VEAF's allocator, so `veaf.addGroup` and `getNextUnitId` really did replace `mist.dynAdd` and `mist.getNextGroupId` |
| **Radio message** | `Wounded Pilot #200084 requests SAR at bullseye 333 for 62, beacon at 300.00 KHz` — the format is intact, which is what the riskiest rewrite had to preserve |
| **Closing / departing** | "2 o'clock", confirmed against an independent bearing calculation (absolute 81°, heading 355°, relative 86°) |
| **Pickup** | *"I'm in! Get to the MASH ASAP!"*, one pilot aboard |

`mist` was `nil` throughout.

## The two defects it found, and why no test saw them

### The assertion ran at load time, where `veaf` cannot exist yet

CSAR refused to start in **every** mission: *"The VEAF framework has not been loaded!"*. A VEAF build
loads the community scripts before its own bundle — CSAR is fifth, `veaf-scripts.lua` seventh — so
`veaf` is legitimately nil when this file is read.

The script already knew, and said so two thousand lines further down:

```lua
-- initialize CSAR in 2 seconds, so other scripts (namely the veaf.lua script) are loaded
timer.scheduleFunction(csar.initialize, nil, timer.getTime() + 2)
```

The check moved into `csar.initialize`, where the dependency is actually needed. It keeps its value:
if `veaf` is missing *there*, something is genuinely wrong.

**Why the suite missed it:** every Lua test `dofile`s the VEAF modules before the script under test.
None reproduces the load order of a real mission, so the assertion always passed.

### A group the editor never placed has no country

Teleporting the downed pilot — a group CSAR had just created itself — failed with
`addGroup: country not found`. `getCurrentGroupData` builds its data from the editor record, and a
group spawned during the mission has none, so the country was missing along with everything else the
snapshot would have supplied.

MiST never met this: its database was refreshed every two seconds and held dynamic groups too. The
live unit knows its country, so it is asked now. This broke **any** teleport of a runtime-spawned
group, not just CSAR's — a regression from ticket 07, surfaced here by accident.

**Why the suite missed it:** the spawner tests teleport editor groups, which always have a record.

Both defects now have tests, and both tests fail when the fix is removed.

## One more thing the session turned up

The mission carried a **stale `build/veaf-scripts.lua`** — dated before this lot was merged — because
`veaf-tools mission build` embeds the built artefact rather than assembling the sources. So the first
attempt showed `attempt to call field 'toStringBR'` for a façade that had existed for days. Not a code
defect; worth remembering when preparing a session: rebuild the Lua bundle first.

## Definition of done

- [x] `grep 'mist\.' src/scripts/community/CSAR.lua` returns nothing outside comments — **and the
      MiST load assertion is gone too**, which would have made CSAR refuse to start in a mission that
      no longer injects MiST
- [x] The four missing helpers live in `veafMath` / `veafGeo`, with tests, not inside CSAR —
      `vecSub`, `vecDotProduct`, `buildWaypoint`, `toStringBR`
- [x] A unit lookup by id exists in `veafMissionDb`, and its difference from the name lookup is
      documented where a caller will read it: the index holds **editor** units, so a runtime spawn has
      an id and no entry — asserted by a test
- [x] The helpers carry the tests (20 of them); the call sites are mechanical substitutions onto
      equivalents already covered. `loadfile` confirms the file still parses
- [x] Checked in game 2026-08-31: ejection, radio message, closing/departing, pickup — see below
- [x] Lua suite green. `stylua` and `luacheck` scope `src/scripts/veaf/` only, so a community
      script is outside them by design
