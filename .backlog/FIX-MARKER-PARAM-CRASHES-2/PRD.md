# FIX-MARKER-PARAM-CRASHES-2 — the three the first sweep missed, because it sampled

Status: ✅ done

## Why there is a second lot

`FIX-MARKER-PARAM-CRASHES` closed six crashes and reported the family closed. It was not: the
probe behind that claim was **thirteen hand-picked cases**, not a sweep. Numeric keywords and
`side`/`name` were tried; string keywords and most of `veafSpawn`'s 53 parameters were not.

Re-run properly — every keyword of every parser, enumerated **from the source** (`veafSpawn`'s
from `ParameterRules`), each tried bare, with `banana`, with `-1` and with `999999`, plus
degenerate inputs — the sweep covers **485 cases** and finds **9 raising, at 3 sites**:

| Marker text | Raises at | Cause |
|---|---|---|
| `_transport, from` | `veafTransportMission.lua:221` | `string.format("%s", nil)` |
| `_spawn …, defense` \| `armor` \| `disperse` (bare or non-numeric) | `veafSpawnParser.lua:56` | `getRandomizableNumeric(val)` then `nVal >= 0`, no nil guard |
| `_spawn …, delayed` (bare or non-numeric) | `veafSpawnParser.lua:225` | same |

Groups B and C are **clean**: 37 and 38 cases, nothing raises, degenerate inputs included
(`""`, `","`, `",,,"`, `"-"`, `"--"`, `"-#"`, `"-!"`).

## The finding that matters more than the three fixes

Four of the nine are in `veafSpawnParser` — the module `REFACTOR-MARKER-PARSER` designates as the
**source** of the shared parser, on the grounds that it is already declarative and proven in
production. Look at what is actually there:

```lua
local function _num(field)              -- fixed by VMR-025, with a comment explaining the nil crash
local function _numNonNegative(field)   -- line 53, the same defect, never fixed
```

`VMR-025` fixed `_num` and left its sibling immediately below it, plus the inline function for
`delayed`. That is `VMR-019`'s pattern for the third time: **a fix reaches the copy it was written
against.** The lot's own argument, now demonstrated inside the module held up as the healthy one.

"Proven in production" was an assumption, not a measurement. `veafSpawnParser` keeps its role —
its loop and rule table are still the right machine — but the PRD says so on measured grounds now.

## What this lot is

Three sites. A bad parameter costs the pilot that parameter, never the command.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Fix the three, and make the sweep a test](tickets/01-tail-crashes.md) | ✅ |

## Method, as a deliverable

The sweep script becomes a test, not a scratch file. A reviewer should be able to see that
coverage is **enumerated from the source** rather than sampled by hand — that is the whole
difference between this lot and the previous one's closing claim.
