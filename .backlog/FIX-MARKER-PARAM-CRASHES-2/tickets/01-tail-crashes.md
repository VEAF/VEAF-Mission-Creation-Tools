# 01 — Fix the three, and make the sweep a test

Status: ✅ done
Type: fix

## Tasks

- [x] A failing test per raising input before the fix.
- [x] `veafTransportMission` `from`: log through `veaf.p(val)`. The field is already allowed to be
      nil, so only the log raises. Its stale `-- Set armor.` comment is a copy-paste on the very
      line being changed; correct it.
- [x] `veafSpawnParser` `_numNonNegative`: guard with `if nVal and nVal >= 0`, matching what
      `VMR-025` did to `_num` — keep the existing value when the parameter is unusable.
- [x] `veafSpawnParser` `delayed`: guard the same comparison. A nil then falls into the existing
      `else`, so an unreadable `delayed` means `MIN_REPEAT_DELAY` (5s) — consistent with how that
      branch already treats a negative value, and with what a pilot typing a bare `delayed` means.
- [x] **A sweep test**, enumerating `veafSpawn.ParameterRules` from the source rather than listing
      keys by hand, asserting no keyword raises when bare or non-numeric. This is what makes the
      coverage claim checkable instead of assertable.

## Acceptance criteria

- [x] The 9 raising cases return an options table.
- [x] The sweep test fails if a **new** parameter is added with an unguarded conversion — verified
      by adding one temporarily and watching it fail.
- [x] `poetry run test-lua` green across all suites.

## Verified

The sweep is a safety net, not a decoration: a parameter with an unguarded conversion was injected
into `ParameterRules`, and the suite failed naming it — `keywords raising with no value:
canaryparam (veafSpawnParser.lua:245: attempt to compare number with nil)` — then passed again
once removed. 485 sweep cases now raise nothing across all three groups.
