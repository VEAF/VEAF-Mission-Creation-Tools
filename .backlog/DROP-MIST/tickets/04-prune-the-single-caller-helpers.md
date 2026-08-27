# 04 — Prune the single-caller helpers

Status: ⬜ ready
Type: refactor

Rule 3 in its purest form: **314 MiST lines reached by 11 calls**, eight of them exactly once. Each is
replaced by the slice we actually use, not by a port of the function.

## The list

| Function | MiST lines | Calls | What we use it for |
|---|---:|---:|---|
| `mist.utils.converter` | **131** | **1** | one unit conversion — find which, port that line |
| `mist.utils.dostring` | 29 | 1 | evaluating a Lua string |
| `mist.utils.zoneToVec3` | 25 | 1 | a trigger zone's centre as a vec3 |
| `mist.getAvgPos` | 24 | 1 | average position of a unit list |
| `mist.getUnitsInPolygon` | 23 | 1 | units inside an arbitrary polygon |
| `mist.getDeadMapObjsInZones` | 20 | 1 | destroyed scenery in a zone |
| `mist.getAvgGroupPos` | 16 | 1 | average position of a group |
| `mist.utils.getHeadingPoints` | 13 | 1 | heading between two points |
| `mist.getNextUnitId` | 10 | 1 | the next free unit id |
| `mist.utils.getQFE` | 23 | 2 | QFE from QNH and altitude |

## Method, per function

1. Read the **one** call site and write down the exact inputs it passes and the shape it expects back.
2. Read the MiST implementation and identify the branch that call takes.
3. Port **that branch**. Delete the rest without reimplementing it.
4. Write the test from the call site's real inputs, not from the function's full contract.

`mist.utils.converter` is the case worth doing first — 131 lines for one call means we are almost
certainly using one conversion pair out of a generic table of them.

## Two that need a second look, not a mechanical port

- **`mist.getNextUnitId`** is not a helper, it is **shared mutable state**: MiST keeps a counter and
  skips the 6900–30000 band. If VEAF and MiST both allocate ids from the same space while both are
  loaded, our replacement must not hand out an id MiST has already used — during the campaign both run
  side by side. Establish who else allocates unit ids (the MCP and the builder assign them at design
  time too) before choosing a scheme, and record it.
- **`mist.utils.dostring`** evaluates a Lua string. Check what our single call site feeds it and whether
  it crosses a security boundary — `veafSecurity` exists, and `REVIEW-SECURITY-LAYER` closed findings in
  this area. If the input is anything other than our own literal, this becomes a security ticket rather
  than a port, and it stops being a rule 3 prune.

## Definition of done

- [ ] Each of the 10 functions is replaced by the slice its call site uses, in `veafMath.lua` or
      `veafGeo.lua` as appropriate
- [ ] 11 call sites migrated
- [ ] One test per function, written from the real call site's inputs
- [ ] `getNextUnitId`: the id-allocation scheme is decided, written down, and cannot collide with MiST's
      counter while both are loaded
- [ ] `dostring`: the input's origin is established; if it is not our own literal, a note is filed and
      the security implication is stated rather than ported silently
- [ ] `stylua --check` and `luacheck` clean
