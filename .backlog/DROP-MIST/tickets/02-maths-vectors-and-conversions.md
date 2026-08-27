# 02 — Maths, vectors and conversions

Status: ⬜ ready
Type: refactor

176 call sites, 20 functions, **7 to 23 MiST lines each**. The largest single bloc of the campaign and
the least risky.

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

## Definition of done

- [ ] `veafMath.lua` exists; every function above has a `veaf.*` façade
- [ ] 176 call sites migrated; only one name survives for the `scalarMult` alias pair
- [ ] Lua tests per function, including the degenerate cases: a zero vector for `mag`, a negative
      distance, `round` at `.5`, `deepCopy` on a nested table
- [ ] `makeVec3` / `makeVec2` asserted against a known coordinate triplet, with the convention named in
      a comment
- [ ] `stylua --check` and `luacheck` clean
