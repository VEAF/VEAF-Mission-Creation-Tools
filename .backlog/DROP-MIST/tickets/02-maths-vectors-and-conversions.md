# 02 — Maths, vectors and conversions

Status: ✅ done — 2026-08-28
Type: refactor

**170** call sites — re-counted; the 176 above counted four helpers that belong to tickets 04 and 06.
20 functions, **7 to 23 MiST lines each**. The largest single bloc of the campaign and the least risky.

## Why this is rule 2 and not rule 1

DCS provides no `toRadian`, no `metersToNM`, no `deepCopy`. Searching for a native equivalent here is
wasted effort — these are plain Lua arithmetic that MiST happens to host. Rule 2 applies in its trivial
form: copy the behaviour, modernise the code, keep the semantics identical.

## The list

| Function | Calls | MiST lines |
|---|---:|---:|
| `mist.utils.toRadian` | 61 | 7 |
| `mist.utils.round` | 27 | 8 |
| `mist.utils.deepCopy` | 17 | 23 |
| `mist.utils.toDegree` | 12 | 7 |
| `mist.vec.add` | 8 | 8 |
| `mist.utils.get2DDist` | 7 | 16 |
| `mist.vec.scalarMult` (+ `scalar_mult`, 2) | 6 | 10 |
| `mist.utils.metersToNM` | 6 | 7 |
| `mist.utils.metersToFeet` | 5 | 7 |
| `mist.vec.mag` | 4 | 7 |
| `mist.utils.getDir` | 4 | 15 |
| `mist.utils.makeVec3` | 3 | 19 |
| `mist.utils.mpsToKnots` | 3 | 7 |
| `mist.utils.feetToMeters` | 3 | 7 |
| `mist.utils.makeVec2` | 1 | 11 |
| `mist.utils.NMToMeters` | 1 | 7 |

`mist.vec.scalar_mult` (2 calls) is an alias of `scalarMult` — the port exposes **one** name.

## Two traps

- **`makeVec3` / `makeVec2` and the `y`/`z` convention.** Read
  [`docs/agents/dcs-coordinates.md`](../../../docs/agents/dcs-coordinates.md) before touching these:
  `y` means different things in a mission table and in the scripting API, and getting it wrong raises
  no error — only a wrong position. Port the behaviour exactly, and assert it in tests against a known
  triplet.
- **`deepCopy` and cycles.** Check whether MiST's version handles a table that references itself and
  whether any VEAF caller relies on that. If none does, say so in the port's docstring rather than
  carrying machinery nobody needs (rule 3 applies inside a rule 2 port).

## What this ticket does

A `veafMath.lua` module with the ported functions, exposed through `veaf.*` façades, and all 176 call
sites migrated.

## What the port actually found

- **100 of the 170 sites needed no new code.** `mist.utils.round` is `veaf.round` (`veaf.lua:934`)
  *line for line* — 27 calls just moved. And `mist.utils.toRadian` / `toDegree` are `math.rad` /
  `math.deg`: the ticket's own premise said DCS offers no equivalent, which is true and beside the
  point, because **Lua's standard library does**, and always did. That is 73 more calls with nothing
  to maintain behind them. Worst numerical difference over ±720°, measured: 1.8e-15 rad.
- **`getDir` dragged `getNorthCorrection` out of ticket 06.** Three of its four call sites pass a
  reference point, so the correction is on the live path; porting `getDir` without it would have left
  a MiST call inside a VEAF expression. `getNorthCorrection` (10 lines, over the native `coord.*`) is
  therefore ported here, and ticket 06 no longer owns it.
- **`mist.vec.scalar_mult` was an alias** (`mist.lua:6144`), as the ticket said; both spellings now
  land on `veaf.vecScalarMult`.
- **`veaf.compute2dAzimuth` and `veaf.compute2dMagnitude` already exist** in `veaf.lua` and overlap
  `getDir` / `vecMag` in part — different contracts (degrees, 2D, a nil guard), so they are left alone.
  Noted so a later ticket does not rediscover them as duplicates.
- **The ported functions are asserted by mutation, not only by example.** Swapping `y` and `z` in
  `makeVec3` fails 6 tests, dropping `deepCopy`'s cycle guard overflows the stack, and making `getDir`
  ignore its reference point fails 1 — each checked by actually making the change.

## Definition of done

- [x] `veafMath.lua` exists; every function above has a `veaf.*` façade
- [x] 170 call sites migrated; only one name survives for the `scalarMult` alias pair
- [x] Lua tests per function, including the degenerate cases: a zero vector for `mag`, a symmetric and
      a zero distance, `deepCopy` on a nested table, on a cycle, on shared references and on metatables
- [x] `makeVec3` / `makeVec2` asserted against a known coordinate triplet, with the convention named in
      a comment and in the test
- [x] `stylua --check` and `luacheck` clean
