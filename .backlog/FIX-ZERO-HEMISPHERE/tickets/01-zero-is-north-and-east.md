# 01 — Zero is north and east

Status: ✅ done — 2026-08-28
Type: fix

## The change

`veafGeo.toStringLL`: `> 0` becomes `>= 0` for both hemisphere letters.

```lua
local latHemisphere = lat >= 0 and "N" or "S"
local lonHemisphere = lon >= 0 and "E" or "W"
```

Nothing else in the function moves. `math.abs` already handles the sign of the numbers themselves, so
only the letter changes, and only for exactly zero.

## What the tests must say

`test_veafGeo.lua` pins the old behaviour in `test_zeroReadsAsSouthAndWest`, with a comment saying it
is MiST's and kept on purpose. Rename it and assert the corrected letters — a test whose name asserts
the defect outlives the defect otherwise.

Cases to cover:

- exactly zero on **both** axes: `N` and `E`;
- zero on **one** axis while the other is negative, both ways round — the two letters are chosen
  independently and a fix to one only would still pass a both-axes test;
- a value **just below** zero (`-0.0001`) still reads `S` / `W`, so the change cannot be read as "the
  negative side lost its letter".

## Definition of done

- [x] `>= 0` on both axes
- [x] `test_zeroReadsAsSouthAndWest` renamed and asserting `N` / `E`
- [x] The three cases above are covered
- [x] Every other literal-string test in the suite is untouched and still passes — the fix must be
      invisible to any coordinate that is not exactly zero
- [x] `veafGeo.lua`'s docstring no longer documents the quirk
- [x] `doc/developer/GUIDE.md` and `.en.md` no longer list it
- [x] `.backlog/DROP-MIST/tickets/03-coordinate-output.md` and
      `.backlog/FIX-DMS-MINUTE-CARRY/PRD.md` point here
