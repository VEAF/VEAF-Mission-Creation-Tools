# 03 — Coordinate output

Status: ✅ done — 2026-08-28
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

## Decided: separate functions, not a trio helper

The ticket suspected one `veaf.formatPosition(vec3)` returning all three strings, because three call
sites emit the same trio. They do — but **not as a block**. In `veafCasMission`, `veafCombatZone` and
`veafTransportMission` the MGRS string is built about fifteen lines before the two lat/lon ones, and
each of the three goes into a *different* i18n entry (`report_latlon_decimal`, `report_latlon_dms`,
`report_mgrs`). A trio helper would mean rewriting the three message blocks, which is a refactor this
ticket was not asked for. Two functions, `veaf.toStringLL` and `veaf.toStringMGRS`, mirroring what the
call sites already do.

## Two defects in MiST, reproduced on purpose

Both were found by generating the expected strings from MiST itself before writing the port, and both
are now pinned by a test that says why.

- **A position at exactly zero renders as `S` and `W`.** The hemisphere test is `> 0`, so the equator
  and the prime meridian fall on the southern and western side: `00 00.00'S⇥ 00 00.00'W`.
- **In DMS, a minute reaching 60 does not carry into the degree.** Seconds rounding up carry into the
  minute, and there it stops: `41.99999444` renders as `41 60' 00"N` where it should read `42 00' 00"N`.
  The **decimal branch, three lines away, does carry** (`41.99999` → `42 00.00'N`), which is what makes
  this an oversight rather than a convention. DMS at precision 0 is the format four of the six call
  sites use, so this is on the common path — it needs the rounding to land exactly on a whole minute,
  which is roughly one report in three thousand.

Reproducing them is the ticket's own rule: these strings go into F10 reports and briefings, and this
lot removes a dependency rather than changing what pilots read. **Fixing the DMS carry is worth its own
lot** — the test that pins it is the one that will have to be updated deliberately.

A third quirk is pinned the same way: MGRS rounding can print one digit more than the requested
precision (`acc = 3` with an easting of 99999 gives `1000`), because the format pads to a minimum width
and never truncates.

## Also found

`test/lua/dcs_mocks.lua` carried a `mist.tostringLL` stub returning `"0N 0E"`, added for
`infoOnAllConvoys`. With the call migrated, the real function runs in that test instead of a constant.
The stub is removed and the suite still passes.

## Definition of done

- [x] Output formatting lives in `veafGeo.lua`, behind `veaf.*` façades
- [x] 13 call sites migrated; `grep -E 'mist\.tostring' src/scripts/veaf/` returns nothing
- [x] Lua tests assert **literal strings** for each precision used in the codebase (0, 2, 3, 5), DMS and
      decimal, in both hemispheres, across the prime meridian, and with a three-digit longitude
- [x] Decided and recorded: separate functions, with the reason above
- [x] `stylua --check` and `luacheck` clean
