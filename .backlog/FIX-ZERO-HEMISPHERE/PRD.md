# FIX-ZERO-HEMISPHERE — the equator reads South, and Greenwich reads West

Status: ✅ done — 2026-08-28

Origin: found alongside the `42 60'` carry while porting the coordinate output off MiST (`DROP-MIST`
ticket 03, 2026-08-28). That lot pinned it rather than fixing it, and `FIX-DMS-MINUTE-CARRY` explicitly
left it alone as a measure-zero case. David, 2026-08-28: *"corrige aussi la position 0,0"* — so it gets
its own lot after all.

## The defect

`veafGeo.toStringLL` picks the hemisphere letter with `> 0`:

```lua
local latHemisphere = lat > 0 and "N" or "S"
local lonHemisphere = lon > 0 and "E" or "W"
```

A coordinate of exactly zero therefore falls on the negative side:

```lua
veaf.toStringLL(0, 0, 2)   --> "00 00.00'S⇥ 00 00.00'W"
```

The equator is neither north nor south and the prime meridian neither east nor west, so *some*
convention has to be picked; the point is that this one was not picked, it fell out of a comparison
that had to answer something. Zero is the positive side of both axes everywhere else in the code — the
sign is what carries the hemisphere — so `>= 0` is the reading that matches the rest.

## Why it is worth doing even though it is rare

The honest assessment written in `FIX-DMS-MINUTE-CARRY` still holds: a latitude or longitude of
*exactly* zero, in floating point, is a measure-zero case. No DCS theatre puts a mission on the
equator, and while **the Channel and Normandy do straddle the prime meridian**, a longitude that lands
on 0.000000 is a coincidence rather than a location.

What makes it worth a lot anyway is that it is two characters of comparison, the fix cannot affect any
other coordinate, and leaving a known-wrong branch in a function whose whole job is to be
byte-accurate invites someone to "discover" it again later. It also removes the last of MiST's quirks
this module was carrying.

## Definition of done

- [x] Zero reads `N` and `E`
- [x] Tests cover exactly zero on each axis and on both, and confirm that negative values — including a
      value just below zero — still read `S` and `W`
- [x] The tests and the module docstring stop describing this as a reproduced MiST quirk
- [x] The developer guide no longer lists it among the quirks kept on purpose
- [x] `DROP-MIST` ticket 03 and `FIX-DMS-MINUTE-CARRY` point at this lot rather than at a decision to
      leave it
- [x] CHANGELOG entry under `[Unreleased]`
