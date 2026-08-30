# REFACTOR-CSAR-WITHOUT-MIST — cut CSAR's 18 calls to MiST

Status: 🧑 waiting-human — code done 2026-08-28; the in-game check is the only thing left

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
- [ ] Checked in game: a CSAR mission, an ejection, a pilot found and picked up
- [x] Lua suite green. `stylua` and `luacheck` scope `src/scripts/veaf/` only, so a community
      script is outside them by design
