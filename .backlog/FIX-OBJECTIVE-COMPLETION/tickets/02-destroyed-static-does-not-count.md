# 02 — a destroyed static no longer counts in a combat zone

Status: ✅ done

Files: `src/scripts/veaf/veafCombatZone.lua`, `test/lua/test_veafCombatZone.lua`,
`veaf_libs/data/known-limitations.yaml` (+ regenerated `docs/agents/dcs-runtime-traps.md`).

`StaticObject.getByName` returns a destroyed static (`isExist()` false, `getLife()` 0), and both the
completion watchdog and the F10 report counted whatever it returned: a zone holding a static never
completed. The other `StaticObject.getByName` calls of the runtime (22) destroy or locate an object —
a wreck is fine there — so they are left alone.

## Done when

- `veafCombatZone.getStandingStatic(name)` returns the static only if `isExist()` is not false and
  `getLife()` is not ≤ 0 (a method missing or raising reads as standing); the watchdog and the report
  use it; `describeForDiag` says "destroyed static".
- Tests: a static with no life left, or no longer existing, lets the zone complete; a standing one keeps
  it open; the report does not list a destroyed static.
- `known-limitations.yaml` records the DCS behaviour, with the measurement.
