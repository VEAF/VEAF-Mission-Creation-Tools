# 03 — Coordinate output

Status: ⬜ ready
Type: refactor

13 call sites: `mist.tostringLL` (9) and `mist.tostringMGRS` (4), 127 MiST lines between them.

## Why this one is nearly free

`FEAT-COORDINATE-FORMATS` already delivered the **input** half on the native API:
[`veaf.lua:1043`](../../../src/scripts/veaf/veaf.lua) calls `coord.MGRStoLL` to parse what a mission
maker types, and the module documents the exact formats DCS displays. Only the **output** half is still
MiST's.

The geodesy is already native everywhere: every call site pairs the MiST call with `coord.LLtoMGRS`,
which is DCS's own. What MiST contributes is **string formatting** — degrees/minutes/seconds versus
decimal, digit precision, spacing — not coordinate conversion. So this is text assembly, and it belongs
next to the parser that already reads the same formats back.

## The call sites

| File | Calls |
|---|---|
| [`veafCasMission.lua:1119-1135`](../../../src/scripts/veaf/veafCasMission.lua) | MGRS + LL decimal + LL DMS |
| [`veafCombatZone.lua:1390-1407`](../../../src/scripts/veaf/veafCombatZone.lua) | same three |
| [`veafNamedPoints.lua:224-227`](../../../src/scripts/veaf/veafNamedPoints.lua) | LL 3-digit + MGRS 5-digit |
| [`veafTransportMission.lua:494-504`](../../../src/scripts/veaf/veafTransportMission.lua) | same three |
| [`veafSpawnGround.lua:1088`](../../../src/scripts/veaf/veafSpawnGround.lua) | LL DMS |
| [`veafWeather.lua:905`](../../../src/scripts/veaf/veafWeather.lua) | LL DMS |

Three of the four multi-call sites emit the **same trio** — MGRS, decimal LL, DMS LL — which suggests
one `veaf.formatPosition(vec3)` helper returning all three, rather than three separate ports called
three times each. Confirm from the surrounding message-building code before deciding.

## Watch for

The output must stay **byte-identical** to what pilots read today, because these strings go into F10
reports and briefings that mission makers have been reading for years. Assert against literal expected
strings, not against a re-derivation.

Precision arguments differ per call site (`2`, `3`, `5`, `0` with the DMS flag). Port the precision
semantics exactly — `tostringMGRS(mgrs, 5)` and `tostringMGRS(mgrs, 3)` do not round the same way.

## Definition of done

- [ ] Output formatting lives in `veafGeo.lua`, behind `veaf.*` façades
- [ ] 13 call sites migrated; `grep -E 'mist\.tostring' src/scripts/veaf/` returns nothing
- [ ] Lua tests assert **literal strings** for each precision used in the codebase, DMS and decimal, in
      both hemispheres and across the prime meridian
- [ ] Decided and recorded: one `formatPosition` trio helper, or separate functions
- [ ] `stylua --check` and `luacheck` clean
