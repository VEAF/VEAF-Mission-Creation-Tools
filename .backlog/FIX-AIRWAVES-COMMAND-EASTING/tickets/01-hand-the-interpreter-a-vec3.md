# 01 — A command element is handed a vec3, in both modules that run one

Status: ✅ done
Type: fix

## What was wrong

`veaf.getRandomPointInCircle` answers the **mission-table** shape — `{ x, y }`, easting in `y`, no
`z` at all — because most of its call sites hand the result straight to
`veaf.placePointOnLand`, which takes exactly that. `veafInterpreter.execute` takes the other shape: a
runtime vec3 whose easting is `z` and whose `y` is the altitude. `veafSpawnGround.lua:89` writes
`["y"] = spawnPosition.z` into the spawned table, which is where the easting has to be.

Handing the draw across untouched therefore left the easting **absent** and put it in the altitude.
A command-driven wave spawned on the theatre's central meridian — hundreds of kilometres from its
zone — at an altitude equal to its easting. No error is raised on either side; both shapes are three
plausible numbers under plausible names. See `docs/agents/dcs-coordinates.md`.

## Two sites, not one

The PRD named `veafAirWaves.lua:1012`. Enumerating the three callers of `veafInterpreter.execute`
rather than trusting the list found a second, identical one:

| Caller | Position it hands over | Verdict |
|---|---|---|
| `veafAirWaves.lua:1012` — `AirWaveZone:deployWaves` | the raw draw | **defective**, the PRD's case |
| `veafQraCore.lua:994` — `VeafQRACore:deploy` | the raw draw | **defective**, same three lines, not in the PRD |
| `veafCombatZone.lua:1608` — `VeafCombatZone:spawnElement` | a vec3 built by hand from `findSpawnPoint` | correct |

The two defective branches are textual twins — same variable names, same comment, same offset
arithmetic — which is why the slip is in both. Fixing one and leaving the other would have left the
family half-closed.

## The fix

At both sites, the conversion the PRD prescribes:

```lua
local randomPosition = veaf.getRandomPointInCircle(position, self.respawnRadius)
randomPosition.z = randomPosition.y
randomPosition.y = position.y
```

The altitude comes from the zone centre, which is the same one the DCS-group branch below already
uses for its spawn spot — so a command element and a group element now start from the same point.

### The vec3 variant the PRD asked us to consider — declined, and the PRD's tally was wrong

`veafGeo.getRandomPointInCircle` is **not** given a vec3-returning sibling.

First, the numbers, because the PRD's are wrong in both directions and the real ones are what decide
this. Enumerated from `src/scripts/veaf/` — **18 call sites**, which the PRD had right:

| What the site does with the draw | Count | Where |
|---|---|---|
| Hands it straight to `veaf.placePointOnLand` | **11** | `veafSpawnGround` ×4, `veafSpawnEffects` ×6, `veafSpawnAircraft:115` |
| Reads the vec2 itself, correctly | **4** | `veaf.lua:1267` (→ `acceptableGroundPoint`), `veaf.lua:1646` (→ `land.getSurfaceType`), `veafDcsSpawner:919` and `:1021` (both write mission-table `x`/`y`) |
| Converts to a vec3 by hand | **3** | `veafSpawnAircraft:1037`, plus the two this ticket fixes |

The PRD said *"sixteen hand the vec2 to `veaf.placePointOnLand`"* — it is eleven; and *"two of them
convert"* — it is **three**, `veafSpawnAircraft:1037` having done it all along.

That third converter is what settles the question rather than the count: it does
`position.z = position.y; position.y = altitude`, where `altitude` is a **computed** value (a base
altitude plus a random delta), not the centre's `y`. So the three converting sites do not share an
altitude source, and no single vec3-returning helper could serve them — it would need the altitude
passed in, at which point it saves nothing over the two lines it replaces.

Add to that: fifteen of the eighteen want the vec2 exactly as it comes, and a second function would
put a third shape in front of every future caller, in a code base whose recorded failure mode is
precisely that choice being made wrong in silence. Two hand conversions, each carrying its reason
above it, are cheaper to read than a name whose difference a caller has to remember.

## The tests, and the proof they can fail

New suites `TestAirWavesCommandEasting` (`test/lua/test_veafAirWaves.lua`) and
`TestVeafQraCommandEasting` (`test/lua/test_veafQraManager.lua`), plus the two flipped assertions in
`TestSecrev2AirWavesZoneCenter.test_an_existing_trigger_zone_is_still_preferred` — the ones the PRD
left deliberately asserting the defect, comment and all, now removed.

Each suite asserts **absent**, **zero** and **correct** apart, because a missing easting reads as
`nil` in Lua and as `0` once anything has defaulted it, and a single loose assertion would accept one
of the two. Values are chosen so no two are equal: northing 77 / easting 88 for the trigger-zone
path, and 1000 / 1500 (altitude) / 2000 (easting) for the zone-centre path.

**Red before the fix** — the failures name the real defect, not a stale expectation:

```
TestAirWavesCommandEasting.test_the_easting_reaches_the_interpreter_in_z
  the easting is absent — the interpreter was handed a vec2: expected: not nil, actual: nil
TestAirWavesCommandEasting.test_the_altitude_reaches_the_interpreter_in_y
  the altitude is the easting — the two shapes were confused: received the not expected value: 2000
```

**Green after**, all 45 suites.

**Sabotage A — the two conversion lines swapped**, a plausible ordering slip that produces a *zero*
easting rather than an absent one:

```lua
randomPosition.y = position.y
randomPosition.z = randomPosition.y   -- z now holds the altitude; the easting is lost
```

Red in both modules, and precisely on the assertion written for that case:
`the easting is zero — that is the central meridian, not the zone: received the not expected value: 0`.
The flipped legacy assertion also caught it (`expected: 88, actual: 0`). This is the check that the
absent/zero distinction is load-bearing and not decoration.

**Sabotage B — the altitude hardcoded**, `randomPosition.y = 0` instead of `position.y`. Red in both
modules: `the altitude must come from the zone centre: expected: 1500, actual: 0`, while the easting
assertions stay green — so the altitude assertion carries its own weight rather than riding on the
easting one.

Both sabotages reverted; the full suite is green.

## Definition of done

- [x] `veafAirWaves.lua` hands `veafInterpreter.execute` a vec3
- [x] `veafQraCore.lua` too — found by enumeration, outside the PRD's stated scope
- [x] The two assertions in `test_veafAirWaves.lua` flipped, and the comment naming this lot removed
- [x] A test that would have caught it, distinguishing correct / zero / absent, in both modules
- [x] Each new test proven able to fail, by two different sabotages
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and **passed on
      the CI Lua gate** (PR #884)
