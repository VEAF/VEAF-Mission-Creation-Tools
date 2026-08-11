# Lot FIX-MARKER-PARAM-CRASHES-2 — the three the first sweep missed, because it sampled

Status: ✅ done

**Goal**: `FIX-MARKER-PARAM-CRASHES` closed six crashes and reported the family closed. **It was
not.** The probe behind that claim was thirteen hand-picked cases — numeric keywords plus
`side`/`name`. String keywords and most of `veafSpawn`'s 53 parameters were never tried.

**Branch**: `fix/marker-param-crashes-2` → [#710](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/710) → `develop`

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | Fix the three, and make the sweep a test | fix | ✅ |

**Re-run properly** — every keyword enumerated **from the source** (`veafSpawn`'s from
`ParameterRules`), each tried bare, with `banana`, with `-1` and with `999999`, plus degenerate
inputs — **485 cases**, of which 9 raised at 3 sites:

| Marker text | Raised at | Cause |
|---|---|---|
| `_transport, from` | `veafTransportMission.lua:221` | `string.format("%s", nil)` |
| `_spawn …, defense` \| `armor` \| `disperse` | `veafSpawnParser.lua:56` | `getRandomizableNumeric` returns nil, then `nil >= 0` |
| `_spawn …, delayed` | `veafSpawnParser.lua:225` | same |

Groups B and C were clean across 75 further cases, degenerate inputs included.

**The finding that outlived the fix**: four of the nine were in `veafSpawnParser` — the module
`REFACTOR-MARKER-PARSER` designated as the *source* of the shared parser for being already
declarative and "proven in production". `VMR-025` fixed `_num` and left its sibling
`_numNonNegative` **immediately below it**, plus the inline `delayed`. `VMR-019`'s pattern for the
third time, inside the module held up as the healthy one. "Proven in production" was an assumption,
not a measurement, and the PRD was corrected to say so.

**Method as a deliverable**: the sweep ships as a **test that reads `ParameterRules`** rather than a
list of keys, so a parameter added later with an unguarded conversion fails in CI. Verified by
injecting one and watching the suite fail by name (`canaryparam`), then pass once removed. A guard
asserts the enumeration is non-empty so it cannot silently degrade into checking nothing.

**On Sourcery's review**: the `> 40` threshold guarding that enumeration was replaced by the actual
invariant — **every declared rule must contribute at least one key** — which cannot go stale when
parameters are added or removed. Proven by degrading `everyDeclaredKey` to skip rule #1 and watching
the guard name it; a `> 0` check would have stayed green. The three near-identical loops became one
`assertNoDeclaredKeywordRaises(shape, description)` helper, which made a fourth hostile shape
(out-of-range `999999`) cheap enough to add — it had been in the scratch probe but not in the suite.

> **The lesson, kept as an agent memory**: a sample that passes is indistinguishable from a closed
> family. Coverage gets enumerated from the code, never sampled by hand.
