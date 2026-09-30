# FIX-DMS-MINUTE-CARRY — a coordinate can read `42 60'` instead of `43 00'`

Status: ✅ done — 2026-08-28 · archived 2026-09-28

Origin: found while porting the coordinate output off MiST (`DROP-MIST` ticket 03, 2026-08-28). The
port reproduced it byte for byte on purpose, because that lot removes a dependency and must not change
what pilots read. David, same day: *"gère le 42 60, il faut corriger"* — so it gets a lot.

## The defect

In degrees/minutes/seconds, `veaf.toStringLL` carries rounded-up seconds into the minute and stops
there. A minute reaching 60 is printed as `60`:

```lua
veaf.toStringLL(41.99999444, 43.0, 0, true)
--> "41 60' 00\"N⇥ 43 00' 00\"E"        -- should read 42 00' 00"N
```

**The decimal branch, three lines away in the same function, does carry**:

```lua
veaf.toStringLL(41.99999, 43.0, 2)
--> "42 00.00'N⇥ 43 00.00'E"           -- correct
```

That asymmetry is what makes this an oversight rather than a convention. It came in with the code:
the behaviour is MiST's, unchanged since the library was vendored.

## Why it matters, measured rather than asserted

- **DMS at precision 0 is the format four of the six call sites use** — `veafCasMission`,
  `veafCombatZone`, `veafTransportMission` and `veafWeather` all render it into a pilot-facing report,
  and `veafSpawnGround` into a spawn confirmation.
- **How often**: at precision 0 the seconds round up to 60 whenever the fractional minute is at or
  past 59.5 seconds — 1 in 120. The minute then has to be 59 for the degree to be wrong — 1 in 60. So
  roughly **1 coordinate in 7 200**, per axis, or about **1 report in 3 600**. Rare, and it lands in
  the one place a pilot cannot check: a grid reference read off an F10 report.
- It is also **wrong in a way that reads as plausible**: `42 60'` looks like a coordinate, so it is
  copied into a kneeboard rather than questioned.

## What to fix, and what deliberately not to

**In scope:** the minute-to-degree carry in the DMS branch.

**Out of scope, and stated so it is not mistaken for an oversight in turn:** the hemisphere test in
the same function is `> 0`, so a coordinate at exactly zero renders as `S` / `W`
(`00 00.00'S⇥ 00 00.00'W`). It is a real inconsistency, but a latitude or longitude of *exactly* zero
is a measure-zero case on every DCS theatre, and changing it moves a string no one has ever seen. Left
alone here; recorded so the next reader knows it was a decision.

**Reopened the same day** — David asked for it too, and he was right: it is two characters of
comparison and it removes the last of MiST's quirks from that function. Fixed in
[`FIX-ZERO-HEMISPHERE`](FIX-ZERO-HEMISPHERE.md).

## Definition of done

- [x] A minute reaching 60 carries into the degree in DMS, as it already does in decimal
- [x] The test that pinned the defect now asserts the corrected string, and says it was corrected
      rather than simply changing the literal
- [x] The developer guide no longer describes the defect as reproduced-on-purpose
- [x] `DROP-MIST` ticket 03 points at this lot
- [x] `stylua --check`, `luacheck`, and the Lua suite clean

---

## Tickets, in full

## 01 — Carry the minute into the degree, in DMS as in decimal

Status: ✅ done — 2026-08-28
Type: fix

### The change

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

### What the tests must say

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

### One thing the fix taught

The obvious test case — *exactly* `59' 59.5"`, the rounding threshold — does not carry. The double
closest to `41 + 59/60 + 59.5/3600` falls just under the threshold, so the seconds round to 59 and the
assertion fails against correct code. Such a test measures floating-point representation, not the
carry; the suite uses `59.7"` and says why.

### Definition of done

- [x] The carry is applied to both latitude and longitude in the DMS branch
- [x] `test_dmsMinutesDoNotCarryIntoTheDegree` is renamed and asserts the corrected output
- [x] The four cases above are covered
- [x] The decimal branch's own tests are untouched and still pass
- [x] `veafGeo.lua`'s docstring no longer documents the defect
- [x] `doc/developer/GUIDE.md` and `.en.md` no longer list it among the deliberately reproduced quirks
- [x] `.backlog/archive/DROP-MIST.md` points at this lot
- [x] CHANGELOG entry under `[Unreleased]`, saying what a pilot will see change

---
