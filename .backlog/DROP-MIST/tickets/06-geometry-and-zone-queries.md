# 06 — Geometry and zone queries

Status: ✅ done — 2026-08-28
Type: refactor

45 call sites. Mixed: two go to native calls (rule 1), the rest are ports of a used slice (rules 2 and 3).

## The list

| Function | Calls | MiST lines | Rule | Note |
|---|---:|---:|:--:|---|
| `mist.getRandPointInCircle` | 20 | 36 | 2 | the campaign's most-called geometry function |
| `mist.getHeading` | 6 | 17 | 3 | port the branch our callers take |
| `mist.pointInPolygon` | 4 | 38 | 3 | 2D only? measure before porting the 3D path |
| `mist.getNorthCorrection` | 4 | 14 | 2 | true-vs-grid north; **read the coordinates doc first** |
| `mist.random` | 4 | 29 | 1 | 29 lines over `math.random` — establish what it adds |
| `mist.getUnitsInZones` | 3 | 74 | 3 | |
| `mist.marker.drawZone` | 2 | 24 | 1 | builds on `trigger.action.*` |
| `mist.marker.remove` | 2 | 4 | 1 | native `trigger.action.removeMark` |

## `getRandPointInCircle` — studied 2026-08-27, on David's instruction

The open question was whether some call sites should route through `veaf.findSpawnPoint`
(`FEAT-SCENERY-AWARE-SPAWN`'s three-tier search: `Disposition` first, validated random draws second,
explicit failure third — [ADR 0018](../../../docs/adr/0018-undocumented-dcs-api-dependency.md)).
All 20 sites were read. **Answer: this ticket ports and changes nothing. The gaps found are not
MiST's doing and belong in their own lot.**

First correction: one of the 20 is not a caller. [`veaf.lua:1263`](../../../src/scripts/veaf/veaf.lua)
**is `findSpawnPoint`'s own tier 2** — the validated-random-draw tier. So there are 19 callers, and the
port must keep that one working before anything else.

Second correction, and it matters for reading the rest:
[`veaf.placePointOnLand`](../../../src/scripts/veaf/veaf.lua) — which wraps 13 of the 19 — **validates
nothing**. It sets `y` to the ground height and returns. It does not test land versus water, and it
knows nothing about buildings. The name reads like a guarantee and is not one.

### The 19 callers, in four families

**A — air spawns, correctly raw (4).** `veafSpawnAircraft.lua:1045`, `veafQraCore.lua:994` and `:1024`,
`veafAirWaves.lua:1067`. Scenery clearance is meaningless in the air; `:1045` even overwrites `y` with
the altitude right after. Port as-is.

**B — effects, correctly raw (6).** `veafSpawnEffects.lua` 56, 176, 254, 291, 313, 370 — smoke, bombs,
flares. `findSpawnPoint`'s own comment names this family: *"A zero radius means 'exactly here, the
mission maker means it' — veafSpawn passes it for farp, cargo, teleport, bomb, smoke and friends."*
Port as-is.

**C — parallel implementations of the same search (2).** This is a design smell the port should surface,
not fix:
- [`veaf.findPointInZone`](../../../src/scripts/veaf/veaf.lua) (`veaf.lua:1642`) draws a point, tests
  `land.getSurfaceType`, and **widens the dispersion on each failure, up to 1000 tries**. It is a second
  spawn-point search, living in the same file as `findSpawnPoint`, without the scenery tier.
- `veafSpawnAircraft.lua:115` carries its own `repeat … nbTries = 25` retry loop.

So the codebase holds **three** spawn-point searches with three different contracts. Worth naming in the
PRD; not this ticket's to merge.

**D — ground placement with a radius and no scenery check (7).** The interesting family:

| Site | What it places | Verdict |
|---|---|---|
| [`veafSpawnGround.lua:594`](../../../src/scripts/veaf/veafSpawnGround.lua) | a **"Full Combat Group"** — real ground combat units | **A genuine miss.** `FEAT-SCENERY-AWARE-SPAWN` wired *"the four dynamic ground spawners plus the generic `doSpawnGroup`"*; those are `veafSpawnGround.lua` 387, 441, 483, 538 and `veafSpawnCore.lua:698`. This one was not among them |
| [`veafCombatZone.lua:1466`](../../../src/scripts/veaf/veafCombatZone.lua) | zone elements when `getSpawnRadius() > 0`, **including DCS groups and statics** | **A gap.** Combat-zone spawn radii are not scenery-aware at all |
| `veafSpawnGround.lua:47` | a FARP | Needs David's call — `findSpawnPoint`'s comment names FARP as a "the mission maker means it" case, yet a non-zero `radius` is passed here |
| `veafSpawnGround.lua:146` | a CTLD FOB | Same question as the FARP |
| `veafSpawnGround.lua:258` | a CTLD beacon | Same family |
| `veafSpawnGround.lua:655` | a spawn carrying a `destination` | Probably correctly raw: `veafSpawnGround.lua:716` documents the deliberate exclusion — *"Deliberately NOT using veaf.findSpawnPoint here: spawnSpot is the convoy's departure"* |
| `veafAirWaves.lua:1037` | hands the point to `veafInterpreter.execute`, **which can spawn ground units** | Indirect; the wave's command decides, so the fix is not local |

### What this means for this ticket

**Nothing changes here.** Every one of the 19 sites is ported to `veaf.getRandPointInCircle` with
identical behaviour, including the two that duplicate `findSpawnPoint` and the seven that skip it. A
ticket whose job is to remove a dependency must not also move where things spawn — a regression in
family D would be indistinguishable from the port going wrong.

**The gaps got their own lot**, opened 2026-08-27:
[`FIX-PLACEMENT-IGNORES-SCENERY`](../../FIX-PLACEMENT-IGNORES-SCENERY/PRD.md). David arbitrated the
family-D questions the same day — the FARP, FOB and beacon are placed **exactly** where the user asked
(confirming the current `radius or 0`), while the FARP's **escort** must become scenery-aware, and the
FARP is **refused with a message** when the escort cannot be placed. The classification above is kept
here so the study is not lost and so nobody folds it in mid-port.

### One coordinate trap to preserve exactly

`veafCombatZone.lua:1466` writes `position = { x = mistP.x, y = position.y, z = mistP.y }` — it reads
MiST's **vec2** `y` as the horizontal `z`. That is correct and it is exactly the confusion
[`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) warns about. Whatever the
port returns must keep the same shape, and the test must assert the resulting vec3, not the draw.

## `mist.random` — 29 lines over `math.random`

Establish what those 29 lines add before assuming the native call is equivalent. Candidates: a seeding
strategy, a uniformity fix for Lua 5.1's `math.random` on some platforms, or an integer-versus-float
signature. If it is a seeding concern, it matters — `dcs_smoke.py` already notes that
`mist.getRandPointInCircle` is random, and two of our in-game checks depend on being able to reason
about draws.

If the 29 lines add nothing our callers rely on, this is a one-line native substitution. Say which,
with the reason, rather than substituting silently.

## `getNorthCorrection` and the coordinate convention

Read [`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) before touching this
one and `getHeading`. True north, grid north and the mission table's own axes do not agree, and a wrong
correction produces a plausible heading that is simply wrong — no error, no crash.

## Definition of done

- [x] Ported functions live in `veafGeo.lua` behind `veaf.*` façades
- [x] Call sites migrated — **37, not 45**: re-counted before starting, as the PRD asks. `pointInPolygon`
      was already at **0** (it went with ticket 04) and `getNorthCorrection` at 2 rather than 4
- [x] `mist.random`: established and written down — see below. Native substitution
- [x] `marker.remove` and `marker.drawZone` go to the native `trigger.action.*` calls
- [x] The `findSpawnPoint` question is **answered** (2026-08-27, see the study above)
- [x] `veaf.lua:1263` — `findSpawnPoint`'s own tier 2 — still works after the port, asserted by the
      existing `TestVeafFindSpawnPoint` suite, which drives the draw end to end (its helper now steers
      `veaf.getRandomPointInCircle` instead of MiST's)
- [x] `veafCombatZone.lua:1466`'s vec2-to-vec3 shape — **moot**: that site no longer calls this function
      at all. `FEAT-SCENERY-AWARE-SPAWN` routed it through `veaf.findSpawnPoint` after this ticket was
      written, and `grep getRandPointInCircle src/scripts/veaf/veafCombatZone.lua` returns nothing
- [x] Lua tests: a point on a zone boundary, a degenerate zero-radius circle, a heading across 0°/360°.
      A three-vertex polygon is moot — `pointInPolygon` is not in this ticket's scope any more
- [x] `stylua --check` clean; `luacheck` left to the CI gate (not installed on this workstation)

## What `mist.random` turned out to be

Above 50 values it calls `math.random` directly. Below, it copies the range until the table holds more
than 50 entries, then draws **eleven times** and keeps the last one — the author's own comment on the
ten extra draws reads *"for giggles"*.

Neither step changes anything. Replicating a range uniformly and drawing uniformly from the copies is
the same distribution as drawing from the range; and ten discarded draws do not change the law of the
eleventh. It is a superstition, not a correction.

Both call sites (`veafSpawnEffects.lua:141` and `:218`, four occurrences) pass `(10, 20)` — integers,
a range of 11. `math.random(10, 20)` is equivalent, and that is the substitution made.

## What the port had to fix in the tests, and what that uncovered

The draw and the heading were **stubbed** in `dcs_mocks`: `mist.getRandPointInCircle` handed back the
centre and ignored the radius, and `mist.getHeading` answered a constant `pi/2` without looking at the
unit. Seven suites went red the moment real code ran under them.

Rather than stubbing VEAF's own functions — which would put the tests back to asserting a mock — the
randomness underneath is now deterministic (`dcs_mocks.setRandomSequence`, `math.random` answering 0 by
default, so a drawn point lands exactly on the centre as the old stub did). Unit fakes gained the
orientation `getPosition` really carries.

**One of those red tests was a real defect**, not a test artefact: the stub answered a **vec3** where
MiST answers a vec2, and `veafAirWaves.lua:1012` relies on that difference. Opened as
[`FIX-AIRWAVES-COMMAND-EASTING`](../../FIX-AIRWAVES-COMMAND-EASTING/PRD.md); not fixed here, because
this ticket removes a dependency and must not also move where things spawn.
