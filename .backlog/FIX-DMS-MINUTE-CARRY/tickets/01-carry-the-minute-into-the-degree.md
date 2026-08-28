# 01 — Carry the minute into the degree, in DMS as in decimal

Status: ✅ done — 2026-08-28
Type: fix

## The change

`veafGeo.toStringLL`, DMS branch: after the seconds carry into the minute, a minute reaching 60 must
carry into the degree, exactly as the decimal branch already does with its own rounded minutes.

```lua
if latSec == 60 then
  latSec = 0
  latMinWhole = latMinWhole + 1
end
if latMinWhole == 60 then   -- the missing half
  latMinWhole = 0
  latDeg = latDeg + 1
end
```

Both axes, both carries. The decimal branch is already correct and must not be touched.

## What the tests must say

`test_veafGeo.lua` currently pins the defect in `test_dmsMinutesDoNotCarryIntoTheDegree`, with a
comment explaining that it is MiST's and reproduced on purpose. **Rename it and assert the corrected
string** — a test whose name says "does not carry" and whose body asserts that it does is worse than
no test. The comment becomes the record of the fix, not of the reproduction.

Add the cases the old behaviour never had to answer:

- the carry cascading on **both** axes at once;
- a **longitude** carrying, not only a latitude — the two are separate code paths;
- the last second of the last minute at precision 0, rounding all the way to the next degree;
- a position that is *near* the boundary and must **not** carry (`41 59' 59.98"` at precision 2), so
  the fix does not start rounding things it should leave alone.

## One thing the fix taught

The obvious test case — *exactly* `59' 59.5"`, the rounding threshold — does not carry. The double
closest to `41 + 59/60 + 59.5/3600` falls just under the threshold, so the seconds round to 59 and the
assertion fails against correct code. Such a test measures floating-point representation, not the
carry; the suite uses `59.7"` and says why.

## Definition of done

- [x] The carry is applied to both latitude and longitude in the DMS branch
- [x] `test_dmsMinutesDoNotCarryIntoTheDegree` is renamed and asserts the corrected output
- [x] The four cases above are covered
- [x] The decimal branch's own tests are untouched and still pass
- [x] `veafGeo.lua`'s docstring no longer documents the defect
- [x] `doc/developer/GUIDE.md` and `.en.md` no longer list it among the deliberately reproduced quirks
- [x] `.backlog/DROP-MIST/tickets/03-coordinate-output.md` points at this lot
- [x] CHANGELOG entry under `[Unreleased]`, saying what a pilot will see change
