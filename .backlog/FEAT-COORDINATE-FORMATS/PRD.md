# FEAT-COORDINATE-FORMATS — accept the coordinates a pilot can actually read off his screen

Status: ✅ done

Asked for on 2026-08-24, in game, while testing the artillery correction loop: *"pour l'artillerie, il faut
supporter plus de formats de coordonnées ; N42E041 c'est très peu précis"*. Three formats named: UTM/MGRS
with a variable number of digits (up to two groups of five), Lat/Lon DMS, and Lat/Lon decimal degrees.

## What already works, measured before building anything

`veaf.computeLLFromString` run against each candidate:

| Input | Meaning | Result today |
|---|---|---|
| `N42E041` | whole degrees | works — precision about **100 km** |
| `N42.5E041.75` | decimal degrees | **works** |
| `N42.50416E041.75833` | decimal degrees, five places | **works** |
| `N42:30:15E041:45:30` | DMS, colons | works, but **wrong by one arc-second** |
| `N42-30-15E041-45-30` | DMS, dashes | same |
| `N42 30 15E041 45 30` | DMS, spaces | **refused** |
| `N42°30'15"E041°45'30"` | DMS, symbols | **refused** |
| `u37TGG1234` … `u37TGG1234512345` | MGRS, 4 to 10 digits | parses; `u` prefix mandatory |
| `37TGG12345678` | MGRS without the prefix | **refused** |
| `37T GG 12345 12345` | **MGRS as DCS displays it** | **refused** |

So one of the three asks — decimal degrees — is already delivered. What is missing is narrower and more
interesting than "more formats".

## The defect this exposed

`_computeLLValueFromString` starts its accumulator at `local result = -1` and then adds each element, so
**every DMS coordinate in VEAF comes out one arc-second short**: about **31 metres** of northing. Measured:
`N42:30:15` returns `42.5038889` where the exact value is `42.5041667`.

Dated to 2021 (`git log -S`), and it is not an artillery problem: `computeLLFromString` is the single
coordinate reader for `veafAirWaves`, `veafGroundAI` (both the target and its validation), `veafNamedPoints`,
`veafQraCore` and `veafShortcuts` (twice). Every DMS coordinate a mission maker has ever written has landed
31 m north of where he meant.

## Scope

1. **The arc-second.** `-1` becomes `0`. This is the whole of the accuracy problem.
2. **MGRS as DCS shows it.** A pilot reads `37T GG 12345 12345` off his own screen; making him retype it as
   `u37TGG1234512345` is the kind of transcription that puts shells in the wrong village. Accept the spaced
   form, and the unprefixed one, keeping the `u` form working.
3. **DMS as a pilot writes it.** Spaces, and the `°`/`'`/`"` symbols, alongside the `:` and `-` that already
   work.
4. **An odd digit count must be refused, not guessed.** MGRS digits always come in pairs; today an odd
   count is silently mangled by `#digits / 2`.
5. **Decimal degrees stay working**, and get the tests they never had.

## Not in scope

Changing what the artillery does with a coordinate once read. This is the reader, and it is shared — which
is why it is worth doing once, here, rather than in `veafGroundAI`.

## Definition of done

- [x] The arc-second error is gone, and a test states the exact expected value — `42:30:15` is asserted at
      `42.5041667` to seven places
- [x] Every format in the table above either works or is refused **deliberately**, each with a test — 21
      tests, enumerated from the table rather than sampled
- [x] An odd MGRS digit count is refused rather than mangled
- [x] The accepted formats are documented where a mission maker will look — the `{#coordinate-formats}`
      table on the veafGroundAI page, both languages, with the precision of each form, and the `target`
      row links to it
- [x] Mutations on the arithmetic — nine, all of them killing

## How it was done

The arithmetic changed shape rather than being patched. Minutes and seconds are now **weighted directly**
(`1`, `1/60`, `1/3600`) instead of being accumulated in arc-seconds and divided at the end, which removes
the place where an off-by-one could live at all — the old `-1` had no business being there and no comment
explaining it.

The separators are **normalised before parsing** rather than matched: `°`, `'`, `"`, spaces, `:` and `-`
all become one colon, then the part is validated as digits and colons only. That is what makes the DCS
forms work without adding a syntax for anyone to remember, and it is why `"somewhere over there"` is still
refused despite starting with an `s`.

For MGRS the separators are stripped **only after the shape is confirmed**, so `37T GG 12345 12345` and
`u37TGG1234512345` are the same coordinate rather than two syntaxes.

`coord.MGRStoLL` is a DCS function and the mock returns `0, 0`, so the MGRS tests assert what is handed
**to** it. That is the right boundary: the parsing is ours, the projection is DCS's.

### Mutations

| Mutation | Result |
|---|---|
| the old arc-second offset restored | 10 tests fail |
| minutes and seconds weights swapped | 8 tests fail |
| the MGRS digit scale off by a decade | 6 tests fail |
| the `u` prefix made mandatory again | 4 tests fail |
| MGRS easting and northing swapped | 2 tests fail |
| south no longer negative | 2 tests fail |
| an odd digit count accepted | 1 test fails |
| the DCS symbols no longer accepted | 1 test fails |
| spaces no longer separators | 1 test fails |

Nine mutations, nine kills, and no round of "this one kills nothing" — the first time today. The
difference is that the tests were written from the **format table** before any code changed, so they
covered the family rather than the example that prompted it.

## One more thing the old reader did

It **accepted a transposed coordinate**. `E041N42` matched its pattern — the first hemisphere letter was
taken as the latitude's whatever it happened to be — and came back as latitude 41, longitude 42: the two
values the wrong way round, silently. The new reader requires north/south then east/west and refuses
anything else, which is the same principle as refusing an odd MGRS digit count.

## The test that legitimised the defect

`test_llDMS` carried the comment *"function has ~1 arcsec offset **by design**"* and widened its range to
`42.39 < lat < 42.40` so the offset would pass. Written on 2026-05-23 during a coverage push: the defect
was measured, and then documented instead of reported. Both that test and its neighbour
`test_llDMDecimal` — which asserted only "between 42 and 43", a range a reader off by half a degree would
also satisfy — now assert exact values.
