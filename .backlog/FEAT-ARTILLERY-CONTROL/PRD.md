# FEAT-ARTILLERY-CONTROL — fire adjustment, the missing half of artillery

Status: ✅ done

Origin: [#198](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/198), plus
[#57](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/57), closed into it on 2026-08-17.

## What exists, and what does not

**Exists**: `-arty` spawns an M-109 battery (`veafShortcuts.lua:1084`), and `veafGroundAI` aims a
**named group** at a position with DCS's `FireAtPoint` (order spec at `:364-372`, task at `:568`).

**Missing**: any verb for **adjusting** fire. Grepped `veafGroundAI` for `correct` and `adjust`:
nothing. #198 describes the whole loop — fire for adjustment, a correction (`correct 09050` = 50 m
east), fire again.

## Scope

The adjustment loop, built on the order spec the module already parses. Two things the issue implies
without stating:

- a fire mission needs an **identity** (its `Sierra23`) so a correction knows what it corrects — state
  the module does not keep today
- a correction is a **bearing/distance offset** applied to the previous aim point, not a fresh
  coordinate

Mind the separator: `veafGroundAI` splits its orders on **semicolons**, not on the marker's commas.

## Definition of done

- [x] A fire mission can be corrected by offset and fires again — the `correct` verb, its
      `correction` parameter, and `ArtilleryUnitHandler:correct`
- [x] The mission is addressable by a name the player is told — **already true, nothing built**: an
      order names its battery (`_ground order, name Sierra23, …`) and a battery holds one aim point, so
      the battery's name *is* the mission's identity. A second registry would give the player two names
      for one thing
- [x] Tests on the offset arithmetic — a wrong bearing is a shell in the wrong village — 24 tests, and
      the mutations below
- [x] Documented on the veafGroundAI page, both languages — the `{#fire-adjustment}` section

## What the work actually found

The scope held: the correction was genuinely missing. But two things came out that the PRD did not ask
about, and both were pre-existing.

**The module kept two competing notions of "the last target".** `_lastTarget` was set in `handleOrder`,
once the rounds actually went out; the correction needed the same idea and I first added a second field
beside it. Two definitions of one concept in one class is a divergence waiting to happen, so they are now
**one** field, `lastAimPoint`, set at the single place where a target has been resolved to a point —
whichever form it arrived in. The queue-time point is the right one: it is what makes two corrections of
50 m east land 100 m east rather than 50.

**And the behaviour the doc has promised for years was untested.** "`fire` with no target re-engages the
last target aimed at" had exactly one test — the *empty* case. Nothing pinned the populated path at all.
It does now.

### Mutations

| Mutation | Result |
|---|---|
| x and z swapped in the offset | 6 tests fail |
| degrees fed to `math.cos` as radians | 6 tests fail |
| the aim point never stored | 5 tests fail |
| a two-digit bearing accepted | 5 tests fail |
| bearing 360 accepted | 3 tests fail |
| the bare-`fire` fallback removed | 1 test fails |
| the aim point aliased instead of copied | 1 test fails |
| a correction sent straight to `fireAtCoordinates` | 1 test fails |

Four mutations killed nothing at first, and each one was a real defect rather than a missing test:

* A `#sDigits < 4` guard **could not fail** — every input it rejected was already rejected by the
  bearing-range or the distance check. Removed, with the reasoning kept as a comment.
* My own test for the bare-`fire` fallback read only the *last* queued order, so when the fallback was
  removed the last order was still the ranging order at the very same coordinates and the test passed. It
  asserted that a refusal looks like a success. It now asserts the order count and which order it is.
* The defensive copy of the aim point was pinned by nothing. Kept and tested, rather than removed: a
  caller that reuses a vec3 would otherwise move a fire mission after the fact.
* `correct` passed `shells` and `radius` straight through to `fireAtCoordinates`, while both firing verbs
  apply their defaults first — so `order correct; correction 09050`, which is the ordinary case and gives
  neither, queued an order with **no round count at all**. Every test I had written passed both values
  explicitly, so nothing saw it. A correction now goes through `fireForAim`, which is also what it is: a
  ranging shot.

**And the three tests closing the first of those were appended after `os.exit(luaunit.LuaUnit.run())`**,
so they were never defined and never run — the suite reported the same 111 successes as before. Moved
above the runner, and all 37 Lua suites were swept for the same hole. None had it.
