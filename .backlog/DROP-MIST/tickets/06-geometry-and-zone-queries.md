# 06 — Geometry and zone queries

Status: ⬜ ready
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

## `getRandPointInCircle` deserves care

Twenty call sites, and it is already wrapped by our own spawn-point logic:
`FEAT-SCENERY-AWARE-SPAWN` built `veaf.findSpawnPoint` as a three-tier search — `Disposition` first,
**validated random draws second** (which is where this function sits), explicit failure third
([ADR 0018](../../../docs/adr/0018-undocumented-dcs-api-dependency.md)). So before porting, check
whether some of the 20 call sites should route through `veaf.findSpawnPoint` instead of drawing a raw
point: a random point in a circle that lands in a building is the exact problem that lot solved.

That is a **behaviour change**, so it is a decision, not a refactor. Split it out if it turns out to
apply: this ticket's job is to remove the MiST dependency without changing where things spawn.

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

- [ ] Ported functions live in `veafGeo.lua` behind `veaf.*` façades
- [ ] 45 call sites migrated
- [ ] `mist.random`: what the 29 lines add is established and written down; native substitution only if
      nothing relies on the difference
- [ ] `marker.remove` and `marker.drawZone` go to the native `trigger.action.*` calls
- [ ] The `findSpawnPoint` question is answered: either no call site should route through it, or a
      separate ticket is opened — **not folded into this one**
- [ ] Lua tests including: a point on a zone boundary, a degenerate zero-radius circle, a polygon with
      three vertices, and a heading across 0°/360°
- [ ] `stylua --check` and `luacheck` clean
