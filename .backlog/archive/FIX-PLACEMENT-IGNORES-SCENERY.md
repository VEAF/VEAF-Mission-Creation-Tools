# FIX-PLACEMENT-IGNORES-SCENERY — ground units are placed without looking at the scenery, and a crowded FARP gives up silently

Status: ✅ done — ticket 12 verified in game 2026-10-03 (R16); ticket 04 (`-farp` refused when its escort fits nowhere) verified the same afternoon (R19, recorded in `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`) · archived 2026-11-24

Origin: found on 2026-08-27 while studying the 20 `mist.getRandPointInCircle` call sites for
[`DROP-MIST`](DROP-MIST.md) ticket 06. Kept out of that campaign
on purpose — a lot whose job is to remove a dependency must not also move where things spawn, or a
regression becomes indistinguishable from the port going wrong. David arbitrated the FARP question the
same day and asked for this lot to be opened.

## Two problems, one cause

`FEAT-SCENERY-AWARE-SPAWN` (2026-08-05, [ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md))
built `veaf.findSpawnPoint`: a three-tier search — the undocumented `Disposition` singleton first, which
genuinely avoids buildings and forests; validated random draws second; explicit failure third. It was
wired into *"the four dynamic ground spawners plus the generic `doSpawnGroup`"* —
`veafSpawnGround.lua` 387, 441, 483, 538 and `veafSpawnCore.lua:698`.

**Two ground-placement paths were not among them, and one whole family delegates the scenery criterion
to a tier it never calls.**

### Problem 1 — two spawners never got wired

| Site | What it places |
|---|---|
| [`veafSpawnGround.lua:594`](../../src/scripts/veaf/veafSpawnGround.lua) | a **"Full Combat Group"** — real ground combat units, on a raw `getRandPointInCircle` draw wrapped in `veaf.placePointOnLand` |
| [`veafCombatZone.lua:1466`](../../src/scripts/veaf/veafCombatZone.lua) | **every combat zone element** whose `getSpawnRadius() > 0`, DCS groups and statics included |

Both can drop a group in a building or a forest, silently. `veaf.placePointOnLand` does not save them:
it sets `y` to the ground height and returns — **no land-versus-water test, no building clearance**. Its
name reads like a guarantee it does not give, which is probably why these two paths look finished.

### Problem 2 — the FARP escort searches for clear ground but never looks at the scenery

`FIX-FARP-ESCORT-PLACEMENT` (6.15.33, verified in game 2026-08-24) built
[`veafGrass.findClearBearing`](../../src/scripts/veaf/veafGrass.lua): it walks the requested bearing
first at each of several distances, then alternates sides, and it correctly avoids **units, statics and
the FARP's own 259 m apron**.

It does not avoid scenery, and it says so —
[`veafGrass.lua:258`](../../src/scripts/veaf/veafGrass.lua): *"scenery is **deliberately left** to
`veaf.findSpawnPoint`'s Disposition tier"*. But the FARP layout path never calls `findSpawnPoint`. The
criterion was delegated to a tier that is not on this path, so nothing applies it.

## David's arbitration (2026-08-27)

1. **The FARP, the FOB and the CTLD beacon are placed exactly where the user asked.** No intelligent
   relocation. This **confirms the current code**: all three default to `local radius = radius or 0`, so
   `getRandPointInCircle(spot, 0)` returns the point unchanged. Nothing to fix — but worth locking in, so
   a later lot does not "improve" it.
2. **The FARP's escort must be placed intelligently, or the FARP is refused with a message.**
3. **Refusing applies to what a command spawns, never to what the Mission Editor placed** — *"c'est
   applicable au spawn (`-farp`) mais pas à ce qui est placé dans l'éditeur de mission (combat zone, farp
   statiques, etc.)"*.
4. Problems 1 and 2 above are to be fixed.

### Ruling 3 is the axis this lot is organised around

It is not a detail of ticket 04; it decides the failure path of **every** ticket here, and it has a
reason: a marker command has a **user standing there** who can read a message and put the marker
somewhere else. Editor content has nobody. Refusing at mission load either breaks the mission silently
or reports to an empty room, and in both cases the mission maker finds out in flight.

So, per path:

| Path | Origin | On "nothing acceptable" |
|---|---|---|
| `veafSpawnGround.lua:594` — `spawnFullCombatGroup` | `registerCommandHandler("fullCombatGroup", …)` on an `eventPos` → **a runtime marker** | **abort and report** |
| `veafSpawnGround.lua:47` — `spawnFarp`, and its escort via `veafGrass.buildFarpUnits` ([`veafSpawnGround.lua:105`](../../src/scripts/veaf/veafSpawnGround.lua)) | the `-farp` command | **refuse the FARP, with a message** |
| `veafCombatZone.lua:1466` — zone elements | **editor content** | **fall back to the declared position** |
| `veafGrass.buildFarpUnits` ← [`veafGrass.lua:586`](../../src/scripts/veaf/veafGrass.lua) | `buildFarpsUnits`, scheduled at startup, walking the units named `FARP …` → **the editor's static FARPs** | **keep today's fallback** |

The measurement that makes ruling 3 implementable rather than a judgement call at every call site:
**`veafGrass.buildFarpUnits` has exactly two callers**, and they are precisely the spawned FARP and the
editor's static FARPs. So the refusal is a parameter of that function, decided by its caller — not a
behaviour of the search.

### Ruling 2 reverses a documented decision, and that must be said out loud

[`veafGrass.lua:332`](../../src/scripts/veaf/veafGrass.lua), the docstring of `findClearBearing`, records
the opposite call:

> *"Falls back to the requested angle at scale 1 when nothing is clear anywhere — **a FARP that refuses
> to exist because it is crowded would be worse than one placed imperfectly** — but says so at info,
> because that fallback is exactly how a group ends up on an apron."*

That fallback is deliberate and it was tuned: `FIX-FARP-ESCORT-PLACEMENT` went through **five rounds of
changes, four of them adjusting how aggressively the placement refuses ground**, and its PRD says
plainly that *"a fix that quietly moved every FARP in every existing mission would have been a worse
outcome than the defect"*.

So ruling 2 is not filling a gap, it is **changing the answer**. The risk is concrete: a mission that
today gets a working-but-imperfect FARP would stop getting a FARP at all. David's call stands — a
decorative escort standing on an apron is the defect this is meant to end — but the lot must make the
refusal *narrow and loud* rather than *broad and silent*, and it must prove the non-regression the way
6.15.33 did.

## Scope

- wire `veafSpawnGround.lua:594` and `veafCombatZone.lua:1466` through `veaf.findSpawnPoint`
- add the scenery criterion to the FARP escort placement
- refuse the FARP, with a translated message, when the escort cannot be placed
- lock in the exact placement of the FARP, FOB and beacon themselves

**Not in scope:** merging the three spawn-point searches. The codebase holds `veaf.findSpawnPoint`,
`veaf.findPointInZone` ([`veaf.lua:1642`](../../src/scripts/veaf/veaf.lua) — draw, `land.getSurfaceType`,
widen the dispersion, up to 1000 tries) and `veafSpawnAircraft.lua:115`'s own 25-try loop, with three
different contracts. That is a real design smell and a separate lot; folding it in here would put a
refactor underneath a behaviour change.

**Also not in scope:** the air spawns (`veafSpawnAircraft.lua:1045`, `veafQraCore.lua:994`/`:1024`,
`veafAirWaves.lua:1067`) and the effects (`veafSpawnEffects.lua` × 6). Scenery clearance is meaningless
in the air, and `findSpawnPoint`'s own comment names the effects family as *"exactly here, the mission
maker means it"*. `veafAirWaves.lua:1037` hands its point to `veafInterpreter.execute`, which may spawn
ground units — noted, but the wave's command decides, so the fix is not local and does not belong here.

## Tickets

| # | Ticket | Risk | Status |
|---|---|---|---|
| 01 | Wire the Full Combat Group spawn through `findSpawnPoint` | low | ✅ |
| 02 | Wire the combat zone element spawn through `findSpawnPoint` | medium — touches every zone with a radius | ✅ |
| 03 | The FARP escort avoids the scenery too | medium | ✅ |
| 04 | Refuse the FARP when the escort cannot be placed | **high** — reverses a tuned decision |✅ |
| 05 | Lock in the exact placement of the FARP, FOB and beacon | low, tests and docs | ✅ |
| 06 | `findSpawnPoint` descending clearance steps + `noRandomFallback` | medium | ✅ |
| 07 | Editor content keeps declared position when tier 1 finds nothing | medium | ✅ |
| 08 | `settlePosition` recalculates each unit in a battery to avoid scenery — superseded by 10 | medium | 🚫 |
| 09 | `silent` propagated to `_createDcsUnits`, refused units no longer dropped silently | low | ✅ |
| 10 | Settle the group by rigid translation, not unit by unit — shipped, and measured inert in game on 2026-09-26; the translation works, the selection does not | medium | ✅ |
| 11 | `settleGroup` verifies the candidate it trusts, and draws more than once | medium | ✅ |
| 12 | `settleGroup` sweeps with the probe instead of asking for a clearing | medium | ✅ |

### Why this lot needed three rounds on the same defect

Tickets 08, 10 and 11 all fix *"the units end up in the trees"*, and the first two were each shipped
green and found inert in game. The pattern is the same every time: **a parameter was handed to
`Disposition` and its meaning was assumed rather than measured.**

- Ticket 08 assumed the **search radius** was honoured. Asked 50 m, DCS answers between 52 and 171 m,
  so the `dist <= r` test could never pass and nothing ever moved.
- Ticket 10 assumed the **clearance** (`posRadius`) was honoured, and wrote it into a comment — *"a
  candidate is scenery-free by construction"*. Measured on 2026-09-26, the point a group was
  translated to is blocked in 12 directions out of 12 at 10 m.
- Ticket 10 also assumed the call was **deterministic**. Five identical calls return nearest
  candidates at 1335, 1476, 1404, 1355 and 1293 m, and a sixth found one at 153 m.

`Disposition` is undocumented ([ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md)) and
the ADR's rule — it *"may improve quality, never decide correctness"* — was respected on the failure
path and quietly broken on the success path: the candidate it returns **was** deciding correctness.
Hence ticket 11's shape: the singleton proposes, this codebase tests.

### What 01, 02 and 05 delivered (2026-08-27)

Four red tests before the fix on ticket 01, three on ticket 02 — the failure messages are the
measurement: `expected: nil, actual: "[b]-Echo Brigade#10430"` for a combat group asked to spawn on an
all-water map, and `expected: 700, actual: 100` for a water candidate becoming the group centre.

Two things turned up while writing them, both recorded rather than smoothed over:

- **The `mist.getRandPointInCircle` stub in `test/lua/dcs_mocks.lua` does not honour the vec2 contract**
  — it returns `y = spot.y`, the altitude, where the real function returns the easting. That is why
  ticket 02's fallback test read `z == 12` before the fix. Routing through `veaf.findSpawnPoint`, which
  returns a proper vec3, removes the ambiguity at that call site; the stub itself is left alone, since
  fixing it is not this lot's business and would touch every suite that leans on it.
- **A FOB is two statics, not one** — the outpost, then a watchtower deliberately offset by
  `TOWER_DISTANCE` on the requested heading. Ticket 05's test now pins both, so the layout offset cannot
  later be mistaken for a jitter and "fixed".

Full Lua suite: **37 suites, all passing**. Coverage measured at 76.97 %, so the CI Lua floor moved
75 → 76 per the ratchet policy. `stylua --check` clean; `luacheck` is not installed on this workstation
and runs in the CI Lua gate.

Order matters between 03 and 04: adding the scenery criterion (03) makes the search *harder* to satisfy,
so it increases how often 04's refusal would fire. Land 03 first and measure how often nothing is clear
before choosing 04's threshold.

## Definition of done

- [ ] No ground-placement path draws a raw random point where scenery matters
- [ ] **Ruling 3 holds everywhere**: a command's spawn aborts or refuses when nothing is acceptable, and
      editor content falls back to its declared position instead. No path refuses editor content, and no
      path silently places a command's group on a rejected point
- [ ] A `-farp` whose escort cannot be placed is refused, with a translated message, and the refusal is
      narrow enough that a FARP in open ground never sees it
- [ ] The non-regression is proven the way 6.15.33 proved it: a FARP far from anything does not move
- [ ] `mypy` exclusions and the coverage ratchet respected per the repository's quality policy
- [ ] `CHANGELOG.md` entry under `[Unreleased]`, appended at the end of the section

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

Ticket 12 verified (R16), GermanyCW-v6 from `develop`, 26 zones activated: 8 vehicles under trees
before `settleGroup`, 2 after; 4 groups translated (20, 20, 60, 140 m); the worst group 0.317 s; one
group of two gave up after 761 probes. Ticket 04 is held by the R19 result in
`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**ground units are placed without looking at the scenery, and a crowded FARP gives up silently.** `FEAT-SCENERY-AWARE-SPAWN` wired `veaf.findSpawnPoint` into the four dynamic ground spawners plus the generic `doSpawnGroup`; **two paths were missed** — `veafSpawnGround.lua:594`, a *"Full Combat Group"* of real ground units, and `veafCombatZone.lua:1466`, which covers every combat zone element with a non-zero spawn radius. Both can drop a group inside a building, silently: `veaf.placePointOnLand`, which looks like a guard, only sets the ground height. Separately, the FARP escort search avoids units, statics and the FARP's own 259 m apron but **not the scenery** — `veafGrass.lua:258` says the criterion is *"deliberately left to `veaf.findSpawnPoint`'s Disposition tier"*, and that tier is never called on this path. David's arbitration (2026-08-27): the FARP, FOB and beacon are placed **exactly** where the user asked (which confirms the current `radius or 0`); the escort must be placed intelligently **or the FARP is refused with a message** — which **reverses** the tuned decision at `veafGrass.lua:332`, so ticket 04 owes a narrow-and-loud refusal and the 6.15.33 non-regression; and **refusing applies to what a command spawns, never to what the Mission Editor placed**, because a marker command has a user standing there to read the message and an editor-placed zone has nobody. That last ruling is the axis the whole lot is organised around and it decides every ticket's failure path: `spawnFullCombatGroup` is a marker command so it aborts, combat zone elements are editor content so they fall back to their declared position, and `veafGrass.buildFarpUnits`' **two** callers split exactly along it — the `-farp` command refuses, the startup sweep over the editor's static FARPs does not. Found while studying `getRandPointInCircle` for [DROP-MIST](DROP-MIST.md) ticket 06 and kept out of it on purpose. **Tickets 01, 02, 03 and 05 delivered 2026-08-27** — 37 Lua suites green, CI Lua coverage floor 75 → 76. Ticket 03 took David's design: `Disposition` cannot be asked whether a chosen spot is clear, it only *proposes* points, so the search was inverted — one cloud request per group, filtered to the accepted distance band, ordered by nearness to the spot actually wanted. That also neutralises the singleton's measured radius overshoot and costs one call to the undocumented API per group instead of 75 probes. **Only ticket 04 remains, and it is blocked on a number only DCS can give**: how often the search exhausts now that buildings and forests both count, which is what its refusal threshold must be chosen against. **Since then**: tickets 06-11 merged (11 in #1008: 17 → 4 vehicles under trees); **ticket 12**, `settleGroup` sweeping with the probe instead of asking `Disposition` for a clearing, implemented 2026-09-28 and waiting on its in-game measurement (R16); **ticket 04**, the `-farp` refused when its escort fits nowhere, implemented 2026-09-30 with MOVES-ON-CLEAR-GROUND ticket 03 and waiting on R19.

## Tickets, in full

## 01 — Wire the Full Combat Group spawn through findSpawnPoint

Status: ✅ done
Type: fix

### What exists

[`veafSpawnGround.lua:594`](../../src/scripts/veaf/veafSpawnGround.lua) places a *"Full Combat
Group"* — real ground combat units — like this:

```lua
local spawnSpot = veaf.placePointOnLand(mist.getRandPointInCircle(spawnSpot, radius))
```

A raw draw, then a vertical correction. `veaf.placePointOnLand` sets `y` to the ground height and returns:
it does **not** test land versus water and knows nothing about buildings. So a `radius` in wooded or
built-up terrain can drop the whole group inside scenery, with no error and no log.

The four sibling spawners in the same file — lines 387, 441, 483 and 538 — already call
`veaf.findSpawnPoint`, as does the generic `veafSpawnCore.lua:698`. `FEAT-SCENERY-AWARE-SPAWN` wired
*"the four dynamic ground spawners plus the generic `doSpawnGroup`"*; this one was simply not among them.

### What this ticket does

```lua
local spawnSpot = veaf.findSpawnPoint(spawnSpot, radius)
```

Match the four siblings exactly, including how they handle a `nil` return — tier 3 means *nothing
acceptable anywhere*, and the caller is expected to report it and abort the spawn rather than place the
group anyway. Read one of the four and copy its failure path; do not invent a second convention.

**Aborting is right here, and it is measured rather than assumed.** `spawnFullCombatGroup` has exactly
one caller, [`veafSpawnGround.lua:1274`](../../src/scripts/veaf/veafSpawnGround.lua), and it is
`veafSpawn.registerCommandHandler("fullCombatGroup", "KNOWN_PILOT", …)` acting on an `eventPos` — a
**runtime marker command**, with a user standing there who can read the report and move the marker. That
puts it on the spawn side of David's ruling 3, unlike ticket 02's combat zone elements, which are editor
content and must fall back instead. The `czName` option is only used to name the group; it does not make
this a combat-zone path.

**`radius == 0` must stay exact.** `findSpawnPoint` already guarantees this — its tier 1 is skipped when
`radius` is falsy or zero, with the comment *"A zero radius means 'exactly here, the mission maker means
it'"* — but assert it in a test, because this is the property a mission maker notices breaking.

### Definition of done

- [x] `veafSpawnGround.lua:594` calls `veaf.findSpawnPoint`, with the same nil-handling as lines 387,
      441, 483 and 538
- [x] A `nil` return aborts the spawn and reports it; the group is never placed on a rejected point
- [x] Lua tests: a clear spot is unchanged, `radius == 0` returns the exact point, a spot where every
      candidate is rejected aborts with a report
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and runs in the CI Lua gate

## 02 — Wire the combat zone element spawn through findSpawnPoint

Status: ✅ done
Type: fix

Higher blast radius than ticket 01: this path covers **every combat zone element with a non-zero spawn
radius**, in every mission that uses combat zones.

### What exists

[`veafCombatZone.lua:1466`](../../src/scripts/veaf/veafCombatZone.lua):

```lua
if zoneElement:getSpawnRadius() > 0 then
  local mistP = mist.getRandPointInCircle(position, zoneElement:getSpawnRadius())
  position = { x = mistP.x, y = position.y, z = mistP.y }
end
if zoneElement:isDcsStatic() or zoneElement:isDcsGroup() then
```

A raw draw, applied to DCS groups and statics alike. No land test, no scenery test — and unlike ticket
01's path, not even a `placePointOnLand` afterwards: the original `position.y` is kept.

### The coordinate shape, which must survive unchanged

`position = { x = mistP.x, y = position.y, z = mistP.y }` reads MiST's **vec2** `y` as the horizontal
`z`, and keeps the original vertical `y`. That is correct, and it is exactly the confusion
[`docs/agents/dcs-coordinates.md`](../../docs/agents/dcs-coordinates.md) warns about: the two shapes
both look like plausible coordinates and swapping them raises no error, only a wrong position.

`veaf.findSpawnPoint` returns a **vec3** (its tier 2 runs the draw through `acceptableGroundPoint`), so
the substitution is not textual. Establish what shape `findSpawnPoint` returns for this caller and
convert deliberately, with the convention named in a comment.

Note the difference from ticket 01: that path replaced the vertical with the ground height, this one
keeps `position.y`. Decide which is right **for a zone element** rather than assuming the sibling's
answer transfers — a static and a group may not want the same thing.

### What this ticket does

Route the draw through `veaf.findSpawnPoint`, and keep the resulting shape identical to what the code
below line 1470 expects.

`getSpawnRadius() == 0` already bypasses the block entirely, so exact placement is untouched by
construction — but assert it, since this is the property missions depend on.

#### A `nil` return must fall back, not refuse (David, 2026-08-27)

**This is editor content, so it is never refused** — *"c'est applicable au spawn (`-farp`) mais pas à ce
qui est placé dans l'éditeur de mission (combat zone, farp statiques, etc.)"*. A combat zone element is
declared by a mission maker who is not in the room when the mission loads; skipping it would remove
part of a zone with nobody to read the reason.

So when `findSpawnPoint` returns `nil` — its tier 3, *nothing acceptable anywhere* — this path
**keeps the element's declared position** and spawns there, logging that it could not improve on it.
The scenery criterion is a **quality** improvement here, exactly as
[ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md) requires of the `Disposition`
dependency: never correctness, never a reason for something to stop existing.

**Note the deliberate asymmetry with ticket 01.** That path is
`registerCommandHandler("fullCombatGroup", …)` on an `eventPos` — a runtime marker, with a user standing
there — so it aborts and reports. Same search, opposite failure path, because the origin differs. Do not
"harmonise" the two: the difference is the arbitration.

### Definition of done

- [x] The draw goes through `veaf.findSpawnPoint`; the vec3 handed to the spawn below is the same shape
      as today, with the convention named in a comment
- [x] A `nil` return **falls back to the element's declared position** and logs it — the element is never
      skipped and the zone is never partially built
- [x] The vertical-coordinate decision (`position.y` versus ground height) is made explicitly and its
      reason recorded
- [x] Lua tests: a zero radius bypasses the search and returns the exact point, a non-zero radius on
      clear ground behaves as before, an **unplaceable element still spawns at its declared position**,
      and the resulting vec3's `x`/`y`/`z` are asserted individually — not compared as a whole table
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and runs in the CI Lua gate

## 03 — The FARP escort avoids the scenery too

Status: ✅ done — 2026-08-27
Type: fix

### Delivered

Two criteria, composed, because neither covers the other:

- **Buildings** — `Object.Category.SCENERY` joins `isSpotOccupied`'s existing category loop. One element
  in an `ipairs`, same volume, same callback, same `pcall` guard: an escort clear of every unit, static
  and apron could still stand through a house.
- **Forests** — a new **tier 1** in `findClearBearing`, on David's design: ask `Disposition` **once** for
  a cloud of scenery-clear points, keep those inside the accepted distance band, order them by how near
  they are to the spot actually wanted, and take the first whose whole arc passes the occupancy probe.
  Falls through to the bearing walk when the singleton is absent, raises, or answers nothing usable.

**David's design is what made the forest half possible at all.** The ticket as written assumed the
criterion would come from `findSpawnPoint`'s tier 1, which cannot work — see the measurement below.
Inverting the search (select from a cloud instead of testing our own candidates) also turns the
singleton's radius overshoot from a blocker into a non-issue, because the distance filter becomes ours,
and it costs **one** call to the undocumented API per group instead of one per candidate position.

`veaf.doNotAvoidScenery` silences the new tier as it silences `findSpawnPoint`'s, and ADR 0018 holds:
absent, raising or nonsensical, `Disposition` degrades and never aborts a FARP.

#### Two bugs found by the tests, both real

- **A candidate at exactly the requested distance was discarded.** Trigonometry turns 150 m into
  0.9999999999999998 × 150, so a bare `scale >= 1` dropped the *best available* point in silence. The
  failure surfaced as "the nearest candidate did not win", which is how it would have looked in game
  too. Fixed with a named one-metre tolerance (`PLACEMENT_DISTANCE_TOLERANCE`) — noise against a 150 m
  escort distance and a 12 m clearance — and pinned by its own test.
- **`math.atan2` answers in (-180, 180],** so a bearing of 270° came back as −90°. Harmless to the
  geometry (`cos`/`sin` do not care) but wrong in the log a mission maker reads, and wrong as a returned
  bearing. Normalised to 0-360, with its own test.

Also worth recording: the `lua` on this workstation's PATH is **lua55.exe**, where `math.atan2` does not
exist at all — it is the test shim that supplies it. A standalone script written to reproduce the
arithmetic died on that before it could say anything useful.

### What exists

[`veafGrass.findClearBearing`](../../src/scripts/veaf/veafGrass.lua) is a real clear-ground search,
built by `FIX-FARP-ESCORT-PLACEMENT` and verified in game on 2026-08-24. It tries the requested bearing
first at each distance in `PLACEMENT_DISTANCE_STEPS`, then alternates sides in
`PLACEMENT_BEARING_STEP` increments, so a group with clear ground does not move at all and a nearer
bearing beats a further one. It is used for the escort, the tents, the props and the windsock
(`veafGrass.lua` 1478, 1568, 1631, 1728).

What it tests, through `veafGrass.isSpotOccupied`, is **units and statics** within a clearance, plus
**landing-platform footprints** — the FARP's own 259 m apron included, measured via
`Airbase:getDesc().box`.

What it does not test is the scenery, and the code says so:

> [`veafGrass.lua:258`](../../src/scripts/veaf/veafGrass.lua): *"`world.searchObjects` is right for
> that, and scenery is **deliberately left** to `veaf.findSpawnPoint`'s Disposition tier."*

**But the FARP layout path never calls `veaf.findSpawnPoint`.** The criterion was delegated to a tier
that is not on this path, so nothing applies it. An escort clear of every unit, static and apron can
still be standing in a forest or through a building.

### What this ticket does

Add the scenery criterion to `allClear` inside `findClearBearing`, so a candidate bearing is rejected
when its positions are not on usable ground.

The mechanism is already available and must be **reused, not reinvented** — `veaf.lua` holds
`acceptableGroundPoint`, which is what `findSpawnPoint`'s own tiers validate with, and the `Disposition`
singleton behind tier 1. Two things to settle before coding, by reading `findSpawnPoint`:

- **Which check to reuse.** `acceptableGroundPoint` is a local in `veaf.lua`; exposing it, or a thin
  `veaf.isAcceptableGroundPoint`, is preferable to a second copy of the same rule. A duplicated
  ground-acceptability rule is how this family of defect got here in the first place.
- **`Disposition` is quality-only, never correctness** ([ADR 0018](../../docs/adr/0018-undocumented-dcs-api-dependency.md)).
  The guard and the `pcall` are mandatory: a singleton absent on another DCS version or map must degrade,
  never abort a FARP.

### MEASURED 2026-08-27 — the cost is fine, but the mechanism the ticket assumed is wrong

David asked for the cost first. Both answers came out of the same measurement, and the second one
matters more.

#### The probe budget is bounded, and smaller than the ticket feared

Counted by instrumenting `isSpotOccupied` around `findClearBearing` for a three-object group
(`test_the_probe_budget_stays_bounded` now pins these):

| Case | Probes per group |
|---|---:|
| Clear ground — the nominal case | **3** |
| Nothing clear anywhere | **75** |
| Theoretical ceiling | 225 |

The abstract product is 3 distances × 25 bearing evaluations × 3 positions = 225, but `allClear`
returns on its **first** occupied position, so a crowded bearing costs one probe rather than three.
The expensive case is not "everything is blocked", it is "almost everything is clear".

Each probe already performs up to **two** `world.searchObjects` calls (`UNIT`, `STATIC`). Adding one
category makes it three — **+50 % on the searches, not a new order of magnitude** — and this runs once
when a FARP is built, not on a tick. Nominal cost of the whole change: 3 extra searches per group, four
groups per FARP. That is nothing.

#### `Disposition` cannot do this job at all

The ticket assumed the scenery criterion would come from `veaf.findSpawnPoint`'s tier 1. It cannot:
**`Disposition.getSimpleZones` *proposes* candidate points, it does not test a point you hand it.**
Testing 75 specific positions with a proposal API would mean 75 calls plus matching returned points
against the one asked about — and its radius argument is measured **not** to bound its answers (asked
800 m, returned points 2035-2258 m out), so a tiny-radius probe cannot distinguish "clear" from
"here is somewhere else entirely".

#### So the three mechanisms split by what they can see, sourced not assumed

| Mechanism | Buildings | Forests | Can test a given point? |
|---|---|---|---|
| `land.getSurfaceType` | no | **no** — [`FEAT-SCENERY-AWARE-SPAWN`](FEAT-SCENERY-AWARE-SPAWN.md) measured that it *"answers LAND for a forest exactly as for a meadow"* | yes, cheap |
| `world.searchObjects(Object.Category.SCENERY, …)` | **yes** | no — trees are not scenery objects | yes, cheap, and `isSpotOccupied` already runs this exact loop for two other categories |
| `Disposition.getSimpleZones` | yes | **yes** — the same probe found *"gaps beside the trees"* and **0 points** in a dense forest | **no** |

`world.searchObjects(Object.Category.SCENERY, …)` is not speculative: two vendored community scripts
already call it (`AIEN.lua`), so the API works.

#### The open decision this leaves — buildings now, forests not point-testable

Adding `Object.Category.SCENERY` to `isSpotOccupied`'s existing category loop gives the escort
**building** clearance for a one-element change. It does **not** give forest clearance, and no API we
have can answer "is this spot in a wood?" for a point we choose.

Getting forests in would mean inverting the search: ask `Disposition` **once** per group for clear
candidates and pick the bearing nearest one. That is one call instead of 75 — but its radius overshoot
means the candidates land well outside the escort distance, which fights #232's arbitration that the
escort stays close to the FARP it serves. **Not resolved here; it is David's call.**

#### Still not measurable without DCS — and it is ticket 04's gate

How **often** the search exhausts once buildings count. That number is what ticket 04 needs to choose
its refusal threshold, and it cannot come from mocks: it depends on real terrain. Either the smoke
harness answers it or it goes to [`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md).

#### The cost, which is why this needed measuring and not just adding

`findClearBearing`'s own comment warns about the call volume: *"a full turn tries 24 bearings at each
distance, and each bearing tests every position the group would occupy"*. That is why the airbase list
is read once, outside the probe. Adding a per-position scenery test multiplies the same product, and the
per-call cost of `Disposition.getSimpleZones` is recorded as **still unmeasured**.

So: measure it before shipping. If the cost is real, the scenery test belongs at the *bearing* level
rather than per position, or only on the bearings that already passed the cheap tests.

### It applies to both kinds of FARP — unlike the refusal

`findClearBearing` serves both callers of `veafGrass.buildFarpUnits`: the `-farp` command
([`veafSpawnGround.lua:105`](../../src/scripts/veaf/veafSpawnGround.lua)) and the editor's static FARPs
([`veafGrass.lua:586`](../../src/scripts/veaf/veafGrass.lua), scheduled at startup). The scenery
criterion applies to **both** — moving an escort out of a forest is an improvement wherever the FARP came
from. David's ruling 3 restricts the **refusal** to the spawned path, not the search.

That said, this ticket **does** change the placement of furniture on editor-placed FARPs in missions that
already work. That is precisely what `FIX-FARP-ESCORT-PLACEMENT`'s PRD warns about — *"a fix that quietly
moved every FARP in every existing mission would have been a worse outcome than the defect"*. So the
non-regression below is not a formality: a FARP whose escort already stands on clear ground must not move
by a metre.

### Definition of done

- [x] Buildings are rejected, by adding one category to the **existing** probe rather than a second copy
      of the rule
- [x] Forests are handled by a cloud tier above the walk, since no API can test a chosen point for them
- [x] `Disposition` stays guarded and `pcall`-wrapped; absent, raising or nonsensical it degrades to the
      bearing walk — three tests, one per failure mode
- [x] `veaf.doNotAvoidScenery` silences the new tier too
- [x] The added call cost is **measured** and recorded above: one `Disposition` call per group, and the
      probe budget is 3 in the nominal case and 75 when nothing is clear — so the per-position test was
      never needed at bearing level
- [x] The probe budget is pinned by a test, so a later change cannot quietly multiply it
- [x] Lua tests: an escort in open ground does not move, a cloud point sets bearing **and** scale, the
      nearest candidate wins, an out-of-band or too-near candidate is ignored, an occupied candidate is
      skipped for the next, and the singleton is asked exactly once
- [x] The 2026-08-24 non-regression still holds — `test_clear_ground_keeps_the_original_bearing` and
      `test_the_probe_budget_stays_bounded` both assert that a FARP with clear ground does not move
- [x] `stylua --check` clean (formatting applied); `luacheck` is not installed on this workstation and
      runs in the CI Lua gate

### Still owed, and it is ticket 04's gate

**How often the search now exhausts on real terrain.** Buildings and forests both counting makes the
search strictly harder to satisfy, and that frequency is what ticket 04 needs to choose its refusal
threshold. It cannot come from mocks. Either the smoke harness answers it or it goes to
[`DCS-SESSION-TODO.md`](../../DCS-SESSION-TODO.md) — **ticket 04 must not pick a threshold before
that number exists.**

## 04 — Refuse the FARP when the escort cannot be placed

Status: ✅ done — verified in game 2026-10-03 (R19): in a dense wood the `-farp` is refused with "no clear ground for its escort"; on open ground the escort stays beside the FARP's props

David, 2026-08-27: *"les escortes (farp) doivent être placées intelligemment, ou le farp est refusé si
c'est pas possible (avec un message)"*.

### This reverses a written decision, deliberately

[`veafGrass.lua:332`](../../src/scripts/veaf/veafGrass.lua), the docstring of `findClearBearing`:

> *"Falls back to the requested angle at scale 1 when nothing is clear anywhere — **a FARP that refuses
> to exist because it is crowded would be worse than one placed imperfectly** — but says so at info,
> because that fallback is exactly how a group ends up on an apron."*

That fallback is not an oversight. `FIX-FARP-ESCORT-PLACEMENT` went through **five rounds of changes,
four of them adjusting how aggressively the placement refuses ground**, and its PRD states that *"a fix
that quietly moved every FARP in every existing mission would have been a worse outcome than the
defect"*. The 2026-08-24 in-game session verified both halves, and the non-regression half — *"c'est bon,
rien n'a bougé"* — mattered more than the reported case.

David's ruling stands: the sentence the fallback protects against is the wrong trade, because a group
standing on an apron is a decorative escort. But the lot inherits that history, so the refusal must be
**narrow and loud**, not broad and silent, and the non-regression must be proven the same way.

### What this ticket does

`findClearBearing` currently returns `baseAngle, 1` when nothing is clear anywhere. It gains a way to
say *"nothing is clear"* distinctly from *"here is a bearing"*, and the FARP path acts on it by refusing
the FARP with a translated message.

Three design points to settle before coding:

- **Who refuses — on two axes, not one.**

  *Axis 1, which piece.* `findClearBearing` serves four callers inside the layout — escort, tents, props,
  windsock (`veafGrass.lua` 1478, 1568, 1631, 1728) — and only the **escort** is meant to abort a FARP.
  The windsock's bearing is explicitly free (David's earlier call: nothing reads its position).

  *Axis 2, which FARP.* **`veafGrass.buildFarpUnits` has exactly two callers**, and David's ruling 3
  splits them:

  | Caller | What it builds | On an unplaceable escort |
  |---|---|---|
  | [`veafSpawnGround.lua:105`](../../src/scripts/veaf/veafSpawnGround.lua), inside `spawnFarp` | the `-farp` command's FARP | **refuse, with a message** |
  | [`veafGrass.lua:586`](../../src/scripts/veaf/veafGrass.lua), inside `buildFarpsUnits` — scheduled at startup, walking the units named `FARP …` | **the editor's static FARPs** | **keep today's fallback** |

  *"c'est applicable au spawn (`-farp`) mais pas à ce qui est placé dans l'éditeur de mission (combat
  zone, farp statiques, etc.)"* — a marker command has a user standing there who can read the message and
  re-place the marker; a static FARP in the editor has nobody, and refusing it at mission load would
  remove furniture from a mission that has always worked.

  So the refusal is a **parameter of `buildFarpUnits`, set by its caller** — not a behaviour of
  `findClearBearing`, which only reports that nothing was clear. That the two callers map exactly onto the
  two sides of the ruling is what makes this implementable rather than a judgement call per call site.
- **What "refused" means for a FARP that is already half built.** The layout code places several things
  in sequence. Establish whether the escort is decided **before** anything is created; if not, the
  refusal has to either move earlier or clean up what it already spawned. A half-built refused FARP would
  be worse than either behaviour.
- **The message.** Translated through `veaf.t` with a new i18n key in both locales, saying *why* — no
  clear ground for the escort — and naming the FARP, so a mission maker can act on it. Do not emit a
  bare failure: this message is the only thing standing between the mission maker and a silently missing
  FARP.

### The measurement, run in game 2026-08-28 — the number this ticket was waiting for

Four `-farp` markers on `VEAF-session-2026-08-27` (Caucasus), one per case, ticket 03's scenery
criterion in force. Read off `dcs.log`, filtered on `findClearBearing` and `FARP escort`:

| Marker | Case | Tier that answered | Escort placed at |
|---|---|---|---|
| `T1-DEGAGE` | open ground, nothing within a kilometre | scenery cloud | bearing 0 → **25**, 1.12x |
| `T2-PRES-STATIQUE` | ~150 m from a static FARP | scenery cloud | bearing 0 → **219**, 1.155x |
| `T3-VILLAGE` | inside a village | scenery cloud | bearing 0 → **54**, 1.16x |
| `T4-FORET` | dense woods | bearing walk | bearing 0 → **-15**, 1x |

**`nothing clear at any bearing or distance` fired 0 times out of 4** — including in dense woods, the
case built to break it. `Disposition.getSimpleZones unusable` never appeared either, so the forest half
of the criterion was live throughout and the figure is not an artefact of an inert check.

**So the refusal is a rare path, not the common one, and this ticket is a fix rather than a
mission-breaker.** It can fire on the first exhaustion; no widened search is needed to keep the
refusal narrow, because exhaustion is already narrow.

Two caveats worth carrying, neither of which changes that conclusion:

- The run happened on a mission that loaded **two** VEAF configurations at once (a leftover v5
  `missionConfig.lua` beside the generated `veaf-config.lua`), so the terrain was *more* crowded than a
  normal mission, not less. Zero exhaustions is therefore a conservative reading.
- `no usable point in Disposition's cloud, walking the bearings instead` is emitted at **debug**
  ([`veafGrass.lua:439`](../../src/scripts/veaf/veafGrass.lua)), so it is invisible in a normal
  `info`-level log. `T4-FORET` fell through to the bearing walk with no line saying why. Anyone
  re-running this needs `veafGrass.LogLevel = "debug"`, or that line has to move to info.
  **Done 2026-09-01 by `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`: it logs at info, no debug level needed.**

**What `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` changes for this ticket** (opened out of the `T1-DEGAGE`
finding below, delivered 2026-09-01): the exhaustion figure above still stands and does not need
re-running — the new guard only adds an earlier way to *accept* a bearing, so a case that did not exhaust
before cannot start exhausting now. What it does change is the `T1-DEGAGE` row: that escort should no
longer move at all, which is the half of this ticket's definition of done that was unprovable.

### What the measurement also revealed, and what it does to this ticket's non-regression

**`T1-DEGAGE` was the non-regression case: nothing should have moved. Something did** — the escort went
from bearing 0 to bearing 25 at 1.12x, on open ground with nothing within a kilometre.

Reading [`findClearBearing`](../../src/scripts/veaf/veafGrass.lua) explains it: tier 1 consults the
scenery cloud **before** testing the requested bearing at all. It sorts the cloud's points by distance
to the wanted spot and takes the nearest one that passes — but the wanted spot itself is never a
candidate, so the escort moves *every time the cloud answers*, clear ground or not. Tier 2's comment
states the opposite intent — *"The original bearing first at every distance, so the group stays where it
was aimed when it can"* — and tier 1 short-circuits it.

This matters here because this ticket's definition of done says *"a FARP far from anything is never
refused and nothing moves"*. **That half is already untrue on `develop`**, independently of any refusal
this ticket adds, so it cannot be proven as written until the tier-1 behaviour is settled.

The fix is not to test the requested bearing first: `allClear` cannot see forests, so that would put
escorts back in the trees. The tenable route is the `gap` tier 1 already computes — if the closest cloud
candidate is within `PLACEMENT_CLEARANCE` of the wanted spot, keep the wanted spot. ~~**Not decided, and
not in scope here**~~ — David's call the same day: **a lot of its own**,
[`FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND`](FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND.md), which
implemented exactly that route on 2026-09-01 and is waiting on its own in-game proof.

### The threshold question ticket 03 must answer first

Ticket 03 adds the scenery criterion, which makes the search **harder** to satisfy and therefore makes
this refusal fire more often. Land 03, measure how often nothing is clear at any bearing or distance on
real terrain, and only then choose whether the refusal fires on the first exhaustion or after a widened
search.

If 03's measurement shows the search exhausts often, this ticket is a mission-breaker rather than a fix,
and it goes back to David with the number rather than shipping.

### What was built, 2026-09-30 — and the one departure from the design above

**The refusal is not a parameter of `buildFarpUnits`.** The second design point settled it: `spawnFarp`
creates the FARP **static** before it calls `buildFarpUnits`, so a refusal decided inside would leave
the platform standing — a half-built refused FARP, the outcome the point warned against. So the
question moved in front of everything: `veafGrass.canPlaceFarpEscort(farp)` lays the escort out exactly
as `buildFarpUnits` does (`veafGrass.farpEscortLayout`, extracted for that) and reports whether the
search found a bearing; `spawnFarp` asks it before `veaf.addStatic` and returns `nil` with the message.
Ruling 3 holds by the same construction the design relied on: `buildFarpsUnits`, the editor's path,
never asks.

`findClearBearing` now returns `angle, scale, found`; the fallback angle is unchanged, so tents, props
and windsock need no change. `buildFarpUnits` searches again once the tents and props stand, so the
escort avoids them too. If that second search exhausts — the tents having taken the only clear
bearing — the escort keeps the placement the `-farp` was accepted on, which `canPlaceFarpEscort` hands
over, rather than falling back to the requested bearing in silence (found by the pre-PR review).

### Definition of done

- [x] `findClearBearing` can report *"nothing clear"* distinguishably from a bearing, and refuses nothing
      itself
- [x] Only the escort caller turns that into a refusal; tents, props and the windsock keep today's
      fallback
- [x] **Only the `-farp` path refuses** — asked in `spawnFarp` before anything exists rather than as a
      `buildFarpUnits` parameter (see above); the editor's static FARPs never ask
- [x] A refused FARP creates **nothing** — the test counts the statics: 0, platform included
- [x] The message is translated in both locales, names the FARP and gives the reason
- [x] 03's exhaustion measurement is recorded here and the threshold justified by it — 0/4, so the
      refusal fires on the first exhaustion
- [x] Lua tests: a placeable escort still places, an unplaceable one on the **`-farp` path** refuses with
      the message and creates nothing, a silent one refuses without a message, and an unplaceable
      **windsock** or set of props never refuses anything. The startup path is pinned by a test calling
      `buildFarpUnits` with nowhere to go: it never asks `canPlaceFarpEscort`, and builds the escort on
      the requested bearing
- [ ] Non-regression proven as in 6.15.33: a FARP far from anything is never refused and nothing moves —
      in the unit tests yes; **in game, R19**. The "nothing moves" half is what
      `FIX-PLACEMENT-MOVES-ON-CLEAR-GROUND` ticket 03 settles, on the same branch
- [x] `CHANGELOG.md` entry under `[Unreleased]` calling this out as a behaviour change
- [x] `stylua --check` clean; `luacheck` runs in the CI Lua gate

## 05 — Lock in the exact placement of the FARP, the FOB and the beacon

Status: ✅ done
Type: test

No behaviour change. This ticket writes down and asserts a decision, so a future lot cannot "improve" it
by accident.

### The decision

David, 2026-08-27: **the FARP, the FOB and the CTLD beacon are placed exactly where the user asked.** No
intelligent relocation, no scenery-driven jitter. The user pointed at a spot; that is the spot.

This is the deliberate counterpart to tickets 01 to 04. Those add scenery awareness to things the tooling
*chooses* to place — a combat group inside a radius, an escort on a bearing. A FARP is not chosen by the
tooling; it is placed by a person who is looking at the map.

### Why it needs asserting rather than just documenting

The current behaviour is already correct, by a single line repeated in each of the three functions:

```lua
local radius = radius or 0
```

With `radius == 0`, `mist.getRandPointInCircle(spot, 0)` returns the point unchanged. So exactness is not
enforced by an intent expressed in the code — it is a **side effect of a default**. Nothing says "this
must not move", and nothing fails if someone changes the default or routes these three through
`veaf.findSpawnPoint` while wiring up its siblings.

That is exactly what happened in the other direction: `veafSpawnGround.lua:594` and
`veafCombatZone.lua:1466` were *missed* when `findSpawnPoint` was wired in, because nothing marked them
as needing it. This ticket puts the opposite marker on the three that must **not** get it.

### Call sites

| Site | What |
|---|---|
| [`veafSpawnGround.lua:47`](../../src/scripts/veaf/veafSpawnGround.lua) | `veafSpawn.spawnFarp` |
| [`veafSpawnGround.lua:146`](../../src/scripts/veaf/veafSpawnGround.lua) | `veafSpawn.spawnFob` |
| [`veafSpawnGround.lua:258`](../../src/scripts/veaf/veafSpawnGround.lua) | the CTLD beacon |

Note the distinction this ticket must not blur: the **FARP itself** is exact; its **escort** is not, and
is the subject of tickets 03 and 04. Both statements are true at once and the comment must say so, or the
next reader will take one for the other.

### What this ticket does

- a comment at each of the three sites stating the rule and naming David's arbitration, in the style of
  the existing `veafSpawnGround.lua:716` marker (*"Deliberately NOT using veaf.findSpawnPoint here…"*),
  which is the precedent for exactly this kind of note
- a Lua test per site asserting the returned position **equals** the requested one when no radius is
  given
- one test asserting that a caller-supplied non-zero radius still jitters, since that is the user asking
  for it — the rule is "exactly where the user asked", not "never move"

### Definition of done

- [x] The three sites carry a comment stating the rule, its author and its date, and distinguishing the
      FARP from its escort
- [x] A test per site: no radius given → the exact requested position
- [x] A test: a non-zero radius still jitters
- [x] `stylua --check` clean locally; `luacheck` is not installed on this workstation and runs in the CI Lua gate

## 06 — `findSpawnPoint`: descending clearance steps and closest candidate

Status: ✅ done
Type: fix

### Problem

`findSpawnPoint` tier 1 requests `DEFAULT_SPAWN_CLEARANCE = 100 m` of clearance and immediately falls
through to the blind random tier when nothing qualifies. On Germany-CW-v6 (2026-09-25), 100 m bubbles
are rarely available in wooded terrain: the Disposition singleton returned **no usable point 38 times
out of 106 commands**, including on open-ground zones such as Letzlingen, because the `_spawn`
commands default to `radius = 1` — a 1 m search radius with a 100 m clearance request will always
fail. The group centre therefore stays wherever tier 2's random draw lands it, often under trees.

Additionally, when tier 1 did find a candidate, it returned the **first acceptable one**, not the
closest. Measured 2026-08-06: Disposition asked for 800 m returned points 2035-2258 m out, so the
group could appear kilometres from the marker.

### What this ticket does

1. **Descending clearance steps.** After failing at `safeRadius`, retry at each step in
   `veaf.SPAWN_CLEARANCE_STEPS = { 50, 25, 10 }` that is strictly smaller. The search stops at the
   first step that produces a usable candidate; only then falls through to the random tier.
2. **Closest candidate wins.** Within each Disposition call, iterate all candidates and keep the one
   whose distance to the centre is smallest (and still <= radius). The distance guard was already
   there; this makes it a minimiser rather than a pass/fail.
3. **`noRandomFallback` parameter (5th, optional).** When `true`, the random tier (tier 2) is
   skipped and `nil` is returned instead. Used by ticket 07 so editor-placed elements never get
   a random placement as a consolation prize.

### Definition of done

- [ ] `veaf.SPAWN_CLEARANCE_STEPS` constant defined and documented
- [ ] `findSpawnPoint` retries at each step < safeRadius before dropping to tier 2
- [ ] The closest candidate within the radius wins, not the first
- [ ] `noRandomFallback = true` skips tier 2 and returns nil
- [ ] Debug log on each clearance step failure; trace log names the winning clearance
- [ ] Tests: all tier-1-exhausted-at-100m-but-found-at-50m, closest-wins,
      noRandomFallback-returns-nil, existing tests still green
- [ ] `stylua --check` and `luacheck` clean

## 07 — Zone elements fall back to their declared position, not a random draw

Status: ✅ done
Type: fix

### David's ruling (2026-08-27, rule 3)

"C'est applicable au spawn (`-farp`) mais pas a ce qui est place dans l'editeur de mission (combat
zone, farp statiques, etc.)". Editor content has no user standing there to receive a refusal. A
partial or randomly-relocated zone is worse than a zone that spawns exactly where the mission maker
put it.

### Current behaviour (ticket 02 fixed this partially)

`VeafCombatZone:spawnElement` already falls back to the declared position when `findSpawnPoint`
returns nil -- but `findSpawnPoint` only returns nil after both tier 1 and tier 2 have exhausted. So
when tier 1 finds nothing (38/106 commands on GermanyCW-v6), the element is placed by a **blind
random draw** within its spawn radius, not kept at the declared position.

Observed result: 53 of 184 zone groups had at least one unit in trees or water, even though the
editor anchor was placed on clear ground.

### What this ticket does

Use ticket 06's `noRandomFallback = true` parameter: when tier 1 finds nothing, `findSpawnPoint`
returns nil immediately without running the random tier. `spawnElement` then:

- **Checks the declared position's terrain.** If admissible (`veaf.DEFAULT_SPAWN_TERRAIN` or the
  element's naval surface), it keeps the declared position and logs at trace.
- **If not admissible** (the declared position is in water, or otherwise invalid), it emits a
  **warning** at mission load time and re-runs `findSpawnPoint` with the random tier enabled as a
  last resort -- because a zone element in the sea is worse than one moved a few metres onto dry land.

The arbitration from David, 2026-09-25: **warn + random if declared terrain is invalid (option b)**.

### Definition of done

- [ ] `spawnElement` passes `noRandomFallback = true` to `findSpawnPoint`
- [ ] If nil returned and declared position is on admissible terrain -> keep it (trace log)
- [ ] If nil returned and declared position is NOT on admissible terrain -> warn + run random tier
- [ ] Tests: tier-1-succeeds keeps the found point; tier-1-fails-valid-declared keeps declared;
      tier-1-fails-invalid-declared warns and runs random tier
- [ ] `stylua --check` and `luacheck` clean

## 08 — Settle each ground unit to the nearest scenery-free point

Status: 🚫 superseded by [ticket 10](FIX-PLACEMENT-IGNORES-SCENERY.md)

> **Measured inert in DCS, 2026-09-25.** The function this ticket delivered never displaced a
> single unit: it kept a candidate only when `dist <= r`, and DCS answers a 50 m request at
> 52-171 m. Ticket 10 replaces it with a rigid translation of the whole group. Kept as written so
> the reasoning that led here is not lost.
Type: fix

### Problem

`findSpawnPoint` places the **group centre** clear of scenery, but `veafUnits.placeGroup` then
spreads individual units around that centre without consulting the scenery. Measured 2026-09-25:
53/184 zone groups had at least one unit in trees or water -- including batteries where the group
centre was on clear ground but a single offset vehicle landed inside a forest.

Three per-unit loops exist in the codebase; none of them recalculate scenery:
- `veafSpawnGround._createDcsUnits` (~l.333)
- `veafSpawnCore.doSpawnGroup` (~l.738)
- `veafCasMission.placeGroup` (~l.1095)

### What this ticket does

New function `veafUnits.settlePosition(spawnPosition, unit)`:
- No-op for air and naval units.
- If `Disposition` is unavailable, returns `spawnPosition` unchanged.
- Tries anneaux of 10, 25, 50 m with 5 m clearance, one `Disposition.getSimpleZones` call each.
- Returns the **closest acceptable candidate within the anneau** (on `veaf.DRIVABLE_TERRAIN`).
- If nothing found, returns `spawnPosition` unchanged (existing behaviour, logged at trace).

David's arbitration 2026-09-25: **recalculate all units (option a)**, not just those that would
fail the probe.

The function is called in all three per-unit loops, immediately before the
`checkPositionForUnit` / `validateSpawnPosition` test. The existing test still runs on the settled
position, catching naval placements on dry land etc.

### Definition of done

- [ ] `veafUnits.settlePosition` defined, documented, no-op for air/naval/no-Disposition
- [ ] Called in `_createDcsUnits`, `doSpawnGroup` and `veafCasMission.placeGroup` before the
      terrain check
- [ ] Tests: ground unit near trees -> nudged; air/naval unit -> unchanged; Disposition unavailable ->
      unchanged; no candidate in range -> unchanged
- [ ] `stylua --check` and `luacheck` clean

## 09 — Propagate `silent` and displace refused units rather than dropping them

Status: ✅ done
Type: fix

### Two defects, one ticket

**Defect A -- `silent` ignored in `_createDcsUnits`.** `validateSpawnPosition` is called with
`silent = false` hard-coded, so a scripted (silent) spawn that drops a unit in water still broadcasts
the error message to all players. Observed in the log: `_spawn samgroup, defense 4` (silent combat
zone activation) emitted player-visible messages for each Strela that fell in the Elbe.

**Defect B -- refused units are silently dropped.** When `validateSpawnPosition` fails (unit on
water), the unit is skipped without attempting a recovery. A 14-unit battery spawned as 11 units with
no indication that three were lost.

### What this ticket does

- **Defect A**: `_createDcsUnits` gains a `silent` parameter (6th, optional, default nil/false).
  All 6 callers in `veafSpawnGround.lua` are updated to pass their own `silent`.
  `validateSpawnPosition` is called with that value instead of `false`.
- **Defect B**: ticket 08's `settlePosition` is called before `validateSpawnPosition` in
  `_createDcsUnits`. If after settling `checkPositionForUnit` still fails, the unit is logged at
  info and skipped (same as today but after best-effort displacement).

Note: `doSpawnGroup` and `veafCasMission.placeGroup` already handle `settlePosition` in ticket 08.

### Definition of done

- [ ] `_createDcsUnits(country, units, groupName, hiddenOnMFD, hasDest, silent)` -- 6 callers updated
- [ ] `validateSpawnPosition` called with the propagated `silent`
- [ ] `settlePosition` called before `validateSpawnPosition` in `_createDcsUnits`
- [ ] Tests: silent spawn emits no player message on unit refusal; non-silent spawn still does
- [ ] `stylua --check` and `luacheck` clean

## 10 — Settle the group by rigid translation, not unit by unit

Status: ✅ done — merged 2026-09-26 (PR #1005)
Type: fix

### Problem — ticket 08 never moved anything

`veafUnits.settlePosition`, delivered by ticket 08, has **never displaced a single unit**. Measured
in DCS on GermanyCW-v6, 2026-09-25:

- called on units genuinely stuck under trees, with a free spot 50 m away and 10 candidates offered
  by DCS: **0.0 m of displacement, every time**;
- over 20 stuck units: **25 candidates returned by `Disposition.getSimpleZones`, 25 valid on terrain,
  0 accepted**;
- actual distance of those candidates: **min 52 m, median 130 m, max 171 m**.

The cause is arithmetic. The function loops over the radii `{ 10, 25, 50 }` and keeps a candidate
only when `dist <= r`. **DCS does not honour the radius it is asked for**: asked 50 m, it answers at
130 m. The closest point it has ever returned is 52 m — just above the widest ring. The test can
never pass, and the function falls back to `return spawnPosition` every time.

Consequence: on the whole mission the scenery probe still reports **51 alerts over 183 objects**,
exactly as before the lot existed (53/184). Ticket 08 bought nothing on the metric that motivated it.

### Why a per-unit nudge cannot work at all

Measured over the same mission:

- **Per unit**: a group's natural spacing is 20 to 27 m for a SAM battery, and the closest point DCS
  can propose is 52 m. Any per-unit displacement therefore breaks the formation by a factor of 2 to 5.
  No threshold is both effective and safe. Ticket 08's own comment already suspected this — *"the ring
  radii must stay below the group spacing so we do not accidentally merge two vehicles into the same
  clearing"*.
- **Per group, as a rigid translation**: over 31 offending groups, **30 are fully resolved** and stuck
  units drop from **132 to 2**, with the formation preserved to the metre. The translations needed run
  from 100 to 800 m. The six worst (the S-300s of Wittstock and Borkenberge, three other S-300s and an
  SA-11) go from 8-13 units under trees to zero.

The formation must also be settled **after** it is built, because `veafUnits.placeGroup` draws it at
random on every spawn (`math.random` at veafUnits.lua ~569, ~688, ~728). No amount of editing the
positions declared in a mission can substitute: the next draw puts units back in the trees.

### What this ticket does

Replace `veafUnits.settlePosition(spawnPosition, unit)` with
**`veafUnits.settleGroup(units)`**, which translates the whole group rigidly:

- computes the group's footprint radius — the largest distance from the barycentre to a unit;
- asks `Disposition.getSimpleZones` **once**, for a clearance of `footprint + SETTLE_MARGIN`, so any
  candidate it returns is the centre of a clearing that fits the **entire** group;
- keeps the closest candidate whose translation puts **every** unit on `veaf.DRIVABLE_TERRAIN`;
- applies that translation to every unit, so all inter-unit distances are unchanged by construction;
- leaves the group untouched when nothing acceptable is found, or when the best candidate is farther
  than `SETTLE_MAX_TRANSLATION`.

Exemptions are unchanged in substance: an air, naval or naval-static unit anywhere in the group makes
the **whole** group exempt, because a rigid translation is a property of the group and translating
half of it would break the very invariant this function exists to protect.

#### The two constants, and why those values

| Constant | Value | Why |
|---|---|---|
| `veafUnits.SETTLE_MAX_TRANSLATION` | 1000 m | The acceptance bound, **not** the radius asked of DCS — the radius asked means nothing, which is the whole defect above. Measured translations needed run to 800 m, so the bound must clear that; 1000 m keeps the group inside the scale of its own combat zone. |
| `veafUnits.SETTLE_MARGIN` | 50 m | Breathing room asked around the footprint, **and** the radius within which a candidate proves the group already stands in that clearing (geometry: a candidate at `d` from the centre has `footprint + margin` clear around it, so every unit is clear as soon as `d <= margin`). The closest candidate DCS was ever measured to return is 52 m, so a tighter margin could never fire that proof. |

### Definition of done

- [ ] A failing test first: a group whose several units stand on refused scenery ends up entirely
      clear **with every inter-unit distance unchanged**
- [ ] `veafUnits.settleGroup` defined and documented; `settlePosition` removed along with its tests
- [ ] Called in `_createDcsUnits`, `doSpawnGroup` and `veafCasMission.generateCasMission`, before the
      terrain check
- [ ] The exemption rests on the **explicit flag** `honourDeclaredPosition`, never on a zero radius:
      zero is this codebase's default, and measured on GermanyCW-v6 on 2026-09-25, **100 of the 118
      spawn commands of one launch pass `radius 0`** — `sa10`, `sa11`, `sa15_squad`, `ewr`,
      `patriot`, `msta`, i.e. every battery this lot exists for. A gate keyed on the radius makes the
      lot a no-op on the real mission while every unit test stays green. Same distinction ticket 07
      drew for `VeafGroupSpawn:honouringDeclaredPosition`, reused rather than duplicated.
- [ ] Two tests pin that gate: a zone spawn at the default radius **is** moved, and a caller that
      honours its declared position is **not**
- [ ] `poetry run test-lua` green, `stylua --check` and `luacheck` clean
- [ ] `CHANGELOG.md` entry under `[Unreleased]`

## 11 — `settleGroup` verifies the candidate it trusts, and draws more than once

Status: ✅ done (PR #1008), **with its limit stated rather than smoothed over**. The per-unit
verification was built first and measured inert twice; the cause was a **parameter**, not an
architecture — the clearance `settleGroup` asked for was large enough to silence `Disposition`
entirely, so the verification never had a candidate to judge. Two constants carry the fix, and it
works: probed before the spawn, where no vehicle of the group exists, vehicles genuinely under
trees go from **17 to 4** after `settleGroup`, with 4 of 31 groups translated against 1 and
formations preserved to 0.0000 m. **The figures first published here — 19 alerts / 76 units → 15 /
69 — were counted after the spawn and are wrong**: `getSimpleZones` counts vehicles as obstacles,
so a tight battery fails its own test wherever it stands. See *Measured in game*. What remains is
real but small, and part of it belongs to groups `settleGroup` is never given — editor content, not
dynamic spawns. The pre-computation phase this ticket planned is **dropped**: the spawn flow was measured not
to affect `Disposition` at all.
Type: fix

### Problem — ticket 10 translates groups, and the metric does not move

Ticket 10 shipped and merged (PR #1005, released in 6.25.0). Measured in game on GermanyCW-v6,
2026-09-26, with the released build actually loaded — `veafUnits.settleGroup` present,
`settlePosition` gone:

| measure | before ticket 10 | ticket 10's target | **measured after** |
|---|---|---|---|
| alerts on groups | 16-18 | ~0 | **19** |
| units standing in scenery | ~81 | a handful | **66** |
| inter-unit spacing | intact | intact | **intact** |

The one promise ticket 10 kept is the formation: spacing stays at its natural 20 m and no group is
pulled apart. Everything else is unchanged.

**The caveat on the comparison, and how it was removed.** The 2026-09-25 reference figures were
taken without pinning the park, so 19-versus-16 was not a regression measurement. It is now: the
2026-09-26 evening run, on 6.25.0.2 with the deferral removed, probed **102 ground groups and 593
units** — the same park as the reference, unit for unit — and found **19 groups in alert, 76 units
blocked**. Ticket 10 and the per-unit verification both leave the number where it was. What the runs
establish without reservation is that it is **not near zero**.

### The function works. What it stands on does not.

Each step was measured separately, because the interesting part is that none of the obvious suspects
is guilty.

1. **The fix runs.** 55 groups translated in one activation of the 25 zones (118 to 278 m), 11
   reported `no clearing wide enough within 1000m`. `no candidate clears every unit` never fired.

2. **DCS obeys to the metre.** `settleGroup` was wrapped to record the barycentre it commands, one
   zone was cycled, and the units' real positions were read back: **0 m of error** between the
   commanded centre and the actual one. Nothing downstream loses the decision — not the caller, not
   `_createDcsUnits`, not the spawn itself.

3. **The group lands in the trees anyway.** That same group — the Wittstock S-300, translated 217 m —
   has **6 of its 14 units blocked**. Probing the arrival point in a ring: blocked in **12 directions
   out of 12 at 10 m**, and only fully clear at 183 m. The group was moved into the middle of a wood
   that happens to have a clearing 183 m further out.

4. **`Disposition.getSimpleZones` is not deterministic.** Five consecutive calls, same point, same
   parameters (`searchRadius 1000`, `posRadius 180`, 10 attempts), nearest candidate:
   **1335, 1476, 1404, 1355, 1293 m**. And a call moments earlier, from inside `settleGroup` on the
   same centre, retained a candidate at **153 m** while an identical call made right after it saw
   nothing closer than **212 m**.

   The scatter is not noise around a value, it is the difference between "a clearing exists 150 m
   away" and "nothing within 1200 m". It also ignores its own search radius: asked 1000 m, it returns
   candidates at 2769 m.

This is the same mistake ticket 10 was written to correct, moved one parameter across. Ticket 10's
finding was *"DCS does not honour the radius it is asked for"*. Ticket 10's own code then assumed DCS
honours the **clearance** it is asked for, and says so in a comment that is simply not true:

> *"A candidate is scenery-free by construction, so nothing here has to test a forest."*

It was never verified. The arrival point measured above is the counter-example.

### What this ticket built first — the verification

**The function proposes, we test.** Two changes, both of them on the selection, none on the rigid
translation — that part works and is not touched.

1. **Verify every candidate before retaining it.** Today a candidate is accepted when every
   translated unit sits on `veaf.DRIVABLE_TERRAIN`, which says nothing about vegetation. Add the
   scenery test, per unit, using the same criterion the acceptance probe uses — is there a free spot
   within a short radius of where this unit would stand. Aligning the acceptance criterion with the
   measurement criterion is the point: the two disagreeing is exactly how ticket 10 came out green
   and inert.

2. **Draw more than once.** A single draw misses clearings that a second draw finds 150 m away. Ask
   `getSimpleZones` a few times and merge the candidates before sorting by distance, so one unlucky
   draw no longer decides that a group stays under trees.

Bound the cost: candidates are tested closest-first and the search stops at the first one that clears
every unit, so the common case — a group already in the open, or one clearing nearby — pays for one
candidate.

Also delete the "scenery-free by construction" claim from the docstring and put the measurement in
its place. A comment asserting something nobody measured is what made this lot cost three rounds.

### Why it stayed inert: the clearance it asks for silences `Disposition`

Everything above is built and green, and it moved nothing. (The counts that said so — 19 group
alerts and 76 blocked units against 19 and 66 — were taken after the spawn and overstate the
problem badly; the correct measurement is under *Measured in game*. The conclusion holds either
way: on the right criterion it moved 22 to 22.) The cause was found on the evening of 2026-09-26,
and it is not the one this ticket carried all day.

**It is the clearance argument.** `settleGroup` asked `Disposition.getSimpleZones` for the group's
own footprint plus 50 m, which is the obvious thing to ask for and is exactly what makes the
singleton answer nothing. Same point, same everything, varying only that one argument:

| clearance asked | 5 | 10 | 20 | 40 | 80 | 120 | 200 | 300 |
|---|---|---|---|---|---|---|---|---|
| candidates over 3 draws | 30 | 30 | 30 | 30 | 30 | 30 | 21 | **0** |

Real groups carry footprints of 8 to 436 m, so the call asked for 58 to 486 m and landed in the
zero column. Instrumented over one activation of the 25 combat zones: **31 calls, one group
translated, 30 giving up** — and the one that moved was repaired correctly (1 of 8 vehicles
blocked, 0 after, 266 m). The verification this ticket built was never wrong; it was never given
anything to verify.

**Second bound, measured the same evening.** `SETTLE_MAX_CANDIDATES_VERIFIED = 10` cuts the list
before the answer. On the five groups that actually held blocked units, asking for a constant 40 m:
verifying the 10 nearest solved **1 of 5**, verifying all of them solved **3 of 5**, the working
candidates coming back at ranks 15 and 22. At 80 m they came back **first** in all three cases —
same outcome, a fraction of the probing — which is why the constant is 80 and the bound is 30.

The two remaining groups are out of reach and no setting will save them: `Disposition` returns
**zero candidates at every clearance, down to 5 m**, for those locations.

### The blindness of the call stack is not reproducible

This ticket spent a day on a different explanation — that `Disposition` goes blind inside
`settleGroup`'s call stack — and it does not survive remeasurement. Witness points at fixed
coordinates, truth 10 blocked out of 15, probed across one reactivation of all 25 zones:

| probed from | answer |
|---|---|
| a quiet frame (reference) | 10 / 15 |
| `ActivateZone`, one second before the spawn | 10 / 15 |
| the top of `activate()`, 25 zones in the same frame | 10 / 15 |
| **inside `settleGroup`**, before and after its own large draws | **10 / 15** |

And the control that settles it: over 20 groups, `getSimpleZones` returned candidates **in flight**
in 17 cases, and replaying the identical queries from a quiet frame recovered **none** — two cases
returned *fewer* when quiet. For the five genuinely faulty groups, in flight and quiet both return
zero.

**So computing the clearings outside the spawn flow buys nothing**, and the pre-computation phase
this ticket planned is dropped. What was measured on 2026-09-26 in the afternoon — 9 of 16 groups
solved from a quiet frame — was a difference of parameters, not of timing.

#### Deferring the spawn was tried, and must not be retried as such

Delaying the whole spawn by one second does make the probe truthful, and it breaks the mission: the
group name a spawn returns feeds `Group.getByName`, and with it `veaf.readyForCombat`, convoy
routing and **`veafSkynet.declareSpawn`**
([`veafSpawnCore.lua:417-460`](../../src/scripts/veaf/veafSpawnCore.lua)). Defer the creation and
that whole block runs on nothing — which is precisely the regression that removed all nine SAM
batteries on the morning of the same day. Four tests in `test_veafSpawn.lua` catch it, since they
assert on the returned group name. This stays closed whatever the reason for wanting it.

### What this ticket now does

Two constants, and the query that uses them.

1. **`SETTLE_CLEARANCE_ASKED = 80`** replaces `footprint + SETTLE_MARGIN`. What is asked for is a
   **coarse filter**, not a guarantee — a candidate does not have the clearance it was asked for,
   which is the whole reason `isPointClearOfScenery` exists. The guarantee comes afterwards, unit
   by unit. `SETTLE_MARGIN` and the footprint computation are gone with it.
2. **`SETTLE_MAX_CANDIDATES_VERIFIED` goes from 10 to 30**, covering the ranks measured while still
   bounding the group that has no solution at all.


#### The footprint varies between draws, and by how much — measured 2026-09-26

Kept because it closes the question this ticket carried, and because it argues *against* the idea it
was measured to support. The open question was whether a clearing could be sized from the group's
footprint before the spawn draws its layout. It could — the margin is bounded — but the fix no longer
needs it: what is asked for is a constant, and the footprint is not asked for at all. What the table
adds now is a second reason never to ask for it, since it moves by up to 38.8 m from one draw to the
next.

Thirty draws per group from a quiet frame, through the real chain `findGroup` → `processGroup` →
`placeGroup`, with **the alias and spacing the combat zones actually pass** (`veafShortcuts`, not a
guess: `-sa15` means `name sa15_squad, spacing 1, radius 0`). `Disposition` is not consulted at all
here, so nothing in this table is exposed to the blindness above. The radius is half the diagonal of
the units' bounding box.

| alias | spacing | radius, min – max | spread | units |
|---|---|---|---|---|
| `sa10` | 1 | 114.0 – 146.7 m | **32.6 m** (+29 %) | 14 – 15 |
| `sa11` | 1 | 69.4 – 108.1 m | **38.8 m** (+56 %) | 11 – 13 |
| `ewr` | 1 | 15.3 – 32.6 m | 17.3 m (+113 %) | 3 |
| `sa22_squad` | 1 | 5.3 – 22.3 m | 17.0 m (+320 %) | 2 |
| `sa15_squad` | 1 | 4.9 – 18.9 m | 13.9 m (+283 %) | 2 |
| `sa18_squad` | default | 11.0 – 18.7 m | 7.7 m (+70 %) | 4 – 7 |
| `smerchhe` | default | 14.1 – 20.2 m | 6.0 m (+43 %) | 7 |
| `msta` | default | 9.3 – 15.4 m | 6.1 m (+66 %) | 5 |
| `sa19_squad` | default | 2.5 – 11.3 m | 8.8 m (+353 %) | 2 |

Two readings, and the second is the one that matters:

- **In absolute terms the spread is bounded and small**: 38.8 m at worst, against translations of
  131 to 470 m. A clearing sized with a fixed margin of ~40 m absorbs every case measured.
- **In relative terms it is brutal for small groups** — `sa15_squad` holds two vehicles in every
  draw and its radius still varies by a factor of 3.9. So the variation is **not** driven by the
  unit count: it is the per-cell jitter (`veafUnits.placeGroup` picks each unit's offset inside its
  cell at random). Sizing a clearing on one observed draw would therefore be wrong even for a group
  whose composition never changes.

**The design rule this fixes:** size the clearing on the group's **worst-case** footprint, never on
a drawn one. The worst case is computable without any randomness — the maximum unit count times the
cell geometry — and a forfait margin of 40 m covers the measured residue.

### Measured in game, 6.25.0.3, 2026-09-26 evening

> **The figures this section first carried were counted with a broken criterion**, and they are
> corrected below rather than deleted, because the correction is the more useful finding.
> `Disposition.getSimpleZones` answers "is there room here", so it counts **vehicles** as well as
> trees. The same points read **12 of 14** blocked with the group standing on them and **0 of 14**
> once it was destroyed; `combatZone_Brocken`'s EWR read 3 of 3 and then 0 of 3. Every count of
> "units in scenery" taken after a spawn — 81, then 76, then 69 — was largely a tally of tight
> batteries failing their own test, which a SAM battery does wherever it stands.

Measured where no vehicle of the group exists yet, which is where `settleGroup` probes anyway, over
one activation of the 25 combat zones:

| measure, probed before the spawn | before this ticket | **after** |
|---|---|---|
| vehicles genuinely under trees on arrival | 22 | **10** |
| still under trees after `settleGroup` | 17 | **4** |
| groups holding them, after `settleGroup` | — | 3 of 31 |
| groups `settleGroup` translates | 1 of 31 | **4 of 31** |

Part of the improvement from 22 to 10 on arrival is not this ticket's: eleven ground groups of the
GermanyCW mission were moved onto clear ground the same evening. What belongs to this code is the
second row, 17 to 4.

**The formation is untouched, measured rather than asserted:** 209 pairwise distances across the
translated groups, largest change **0.0000 m**.

#### What the broken criterion also explains

The "blindness" this ticket spent a day on. Witness points probed from inside `settleGroup`
answered "clear", and answered "blocked" one second later — because `settleGroup` runs **before the
group's units exist** and the control ran after they had spawned. Two different questions, not a
singleton that lies. The pre-computation phase it called for stays dropped, for the separate reason
that the spawn flow was measured not to affect `Disposition` at all.

#### The remaining ceiling

`settleGroup` is called 31 times for 102 ground groups, and **not one call is turned away** — no
declared position honoured, no exempt unit. The other 71 never reach it: they are editor content
respawned as-is, and `veafCommand` is nil for 170 of the 234 zone elements. Whether the tools should
place that content on clear ground is [`FEAT-CLEAR-GROUND-AT-AUTHORING`](FEAT-CLEAR-GROUND-AT-AUTHORING.md);
whether `settleGroup` should stop asking `getSimpleZones` for candidates at all is ticket 12.


### Definition of done

- [x] A failing test first: a candidate that is clear on terrain but stands in scenery is **rejected**,
      and a further candidate that is genuinely clear is retained instead
- [x] A test pinning that several draws are merged: a clearing only the second draw returns is found
- [x] The clearance asked of `Disposition` no longer grows with the group, and a failing test pins it:
      a 200 m group and a 5 m group ask for the same constant. Verified red against the old code —
      it asked 250 m and 50 m
- [x] `SETTLE_MAX_CANDIDATES_VERIFIED` covers the ranks the working candidates actually come back at
- [x] Measured, and it removes the planned phase: the spawn flow does not affect `Disposition`
      (17 of 20 groups get candidates in flight, and a quiet replay recovers none)
- [x] Measured: the footprint moves by up to 38.8 m between draws, so it could not be asked for
      safely even if the singleton answered — see *The footprint varies between draws*
- [x] The rigid translation is unchanged — measured in game: 209 pairwise distances, largest
      change 0.0000 m
- [x] The docstring no longer claims a candidate is scenery-free by construction, and records the
      2026-09-26 measurements instead
- [x] Verified **in game** on GermanyCW-v6, not only in tests: probed before the spawn, vehicles
      under trees go from **17 to 4** after `settleGroup`. **Not** near zero — 71 of the 102 ground
      groups never reach this code at all, see *The remaining ceiling*
- [x] `poetry run test-lua` green (49 suites), `stylua --check` clean. `luacheck` is not installed on
      this workstation and runs in CI
- [x] `CHANGELOG.md` entry under `[Unreleased]` updated to describe the parameter fix

## 12 — `settleGroup` sweeps with the probe instead of asking for a clearing

Status: ✅ done — verified in game 2026-10-03
suites green; what is left is the in-game measurement, item R16 of `DCS-SESSION-TODO.md`. David's
call, 2026-09-26 evening: *"si la sonde marche mais pas getSimpleZone, pourquoi on n'utilise pas le même
concept que la sonde en jeu avant de spawner des trucs ?"*
Type: fix

### The question, and why it is the right one

Ticket 11 fixed the clearance `settleGroup` asks for, and the numbers moved — probed before the
spawn, vehicles under trees fall from 17 to 4 after `settleGroup`. But it kept
`Disposition.getSimpleZones` as the thing that
*proposes* candidates, and that is still a lottery: it returns **zero candidates at every clearance,
down to 5 m**, for the places a group most needs moved out of.

The two calls are not the same animal, and the difference was measured on the running mission on
2026-09-26:

| call | cost each | behaviour |
|---|---|---|
| the small probe — 5 m free within 20 m | **0.38 ms** (2 600/s) | **deterministic**: 12 repetitions on the same points gave 0/12 against 12/12, identical counts |
| the large query — a whole clearing at once | **12.0 ms** (32× more) | a lottery, ignores its search radius, and returns nothing where it matters |

So `settleGroup` currently spends **3 large queries per group, 36 ms, to obtain nothing** in 30 calls
out of 31 — 1.1 s of computation per activation of the 25 combat zones, entirely wasted.

### What replaces it

**Sweep the neighbourhood with the probe.** Rings of growing radius around the group's barycentre;
for each offset, translate the group rigidly and test it; stop at the first offset that clears every
unit. `Disposition` is then only ever used the way it is dependable — asked about one point at a
time — and never asked to propose anything.

Two things make the cost acceptable, both measured:

- **Test the extremes first.** Probing the two units that carry the footprint before probing all of
  them rejects a bad offset for 2 probes instead of 15. On the Wittstock S-300 this brought a full
  sweep to **836 probes, 0.32 s**.
- **Groups already in the open never sweep at all.** They leave on the existing `alreadyClear` check,
  one probe per vehicle.

**A halo, not just a point.** Each candidate position is accepted only when every vehicle is clear
**and** the four cardinals at 40 m around it are clear too, because `veafUnits` redraws the internal
layout at every spawn and the footprint moves by **up to 38.8 m** between draws (ticket 11, *The
footprint varies between draws*). Without the halo, a solution validated once is not a solution.

### The measurement that pointed here — and why it has to be redone

> **Measured with the criterion that was later found broken.** The sweep looked for points where
> `getSimpleZones` reported room, and it counts **vehicles** as well as trees, so the sweep was
> fleeing neighbouring vehicles as much as vegetation. The numbers below are what convinced us the
> approach works; **none of them should be quoted until the sweep is rerun probing where no vehicle
> of the group exists yet.** The design is unaffected — a sweep with the small probe is still 32×
> cheaper per call and still deterministic — but its yield is unknown.

Run on the live mission, 6.25.0.3, on the 14 groups holding blocked vehicles:

- **13 of 14 solved**, translations of 40 to 200 m. **Including `combatZone_Wittstock`'s S-300**,
  which ticket 11 recorded as having *no way out at any clearance*: the sweep finds a clearing at
  **200 m**. The dead end was a property of the query, not of the terrain.
- **1 genuinely unsolvable**: `combatZone_Wittstock [r] SA15`. Nothing within 720 m **even with the
  halo removed entirely** — so it is the wood that is closed, not the criterion that is too strict.
- Every solution was revalidated independently afterwards: 0 blocked vehicles, 0 without halo.

### What was built, 2026-09-28

Three decisions, two of them David's, taken before the code:

1. **No halo** (David, 2026-09-28). The halo was justified by the layout being redrawn at every
   spawn, but `settleGroup` runs **after** `placeGroup`, on the layout actually drawn, and runs
   again on every respawn: what it validates is exactly what spawns. The halo came from the live
   trial, which looked for one position valid across draws. One probe per vehicle, the acceptance
   probe's own criterion.
2. **`SETTLE_MAX_TRANSLATION` = 300 m, `SETTLE_SWEEP_PROBE_BUDGET` = 1000** (David, 2026-09-28).
   300 rather than the 240 first proposed, because ticket 10 translated groups by 118 to 278 m and
   ticket 11 moved one by 266 m: a tighter bound would give up on groups the previous code moved.
   At a 20 m step a full sweep is 761 offsets, so a group with no way out costs about 761 probes,
   inside the budget; the budget is a safety bound for tuned values, not the operative limit.
3. **One frame.** Spreading the sweep over frames means deferring the spawn, which empties
   `veafSkynet.declareSpawn` (ticket 11, *Deferring the spawn was tried*). Not an open choice.

The public name `SETTLE_MAX_TRANSLATION` is kept, since `LUA_API_REFERENCE` documents it as a
setting; `SETTLE_CLEARANCE_ASKED`, `SETTLE_DRAWS` and `SETTLE_MAX_CANDIDATES_VERIFIED` are gone, and
`SETTLE_SWEEP_STEP` (20 m) and `SETTLE_SWEEP_PROBE_BUDGET` are new.

### Definition of done

- [x] A failing test first: a group whose neighbourhood `getSimpleZones` refuses to describe is still
      moved to a clear spot found by sweeping
- [x] ~~A test pinning the halo~~ — **dropped** with the halo, decision 1 above. Pinned instead: the outermost units are probed first: an offset clear at the vehicles' own points but not at 40 m around
      them is **rejected**
- [x] `settleGroup` no longer calls `Disposition.getSimpleZones` with a clearance argument at all;
      `SETTLE_CLEARANCE_ASKED` and `SETTLE_MAX_CANDIDATES_VERIFIED` go with it, or are restated as
      sweep bounds
- [x] The sweep is **bounded** — probe budget and maximum radius — and the bound is a measurement
      rather than a hunch. A 600-probe budget is 0.23 s, against the 36 ms currently spent for
      nothing; decide whether that is spent in one frame or spread over several
- [x] The rigid translation is unchanged — inter-unit distances preserved to the metre
- [ ] The sweep's yield is **remeasured** with the corrected criterion — probing before the
      group's units exist — since the figures above were taken with the broken one
- [ ] Verified **in game** on GermanyCW-v6: blocked vehicles and the cost of one activation of the
      25 zones measured, not estimated
- [x] `poetry run test-lua` green (49 suites), `stylua --check` clean; `luacheck` runs in CI
- [x] `CHANGELOG.md` entry under `[Unreleased]`
- [x] `known-limitations.yaml` records that the probe is the usable half of the singleton and the
      large query should not be used to find a clearing at all
