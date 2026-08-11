# 01 — Stop the six crashes

Status: ✅ done
Type: fix

## Tasks

- [x] A failing test per crashing input, before the fix, in the module's own suite:
      `_cas, side` · `_move group, name` · `_transport, size` · `_transport, size banana` ·
      `_transport, defense` · `_transport, blocade`.
- [x] `veafCasMission` `side`: log through `veaf.p(val)` like the four sites `VMR-019` already
      fixed, and ignore the keyword when it has no value — do **not** fall through to RED, which
      is what `val:upper() ~= "BLUE"` would do if the log were the only thing fixed. A missing
      `side` leaves `switch.side` nil, and `executeCommand` then derives it from the marker's own
      coalition, which is the intended path.
- [x] `veafMove` `name`: log through `veaf.p(val)`. The parser already refuses the command when
      `groupName` is empty, so there is nothing else to decide — only the log raises.
- [x] `veafTransportMission` `size`, `defense`, `blocade`: `veaf.safeNumber(val)` and an
      `if nVal and …` guard, character for character what `veafCasMission` carries since
      `VMR-019`. Bounds unchanged: `size` 1..5, `defense` and `blocade` 0..5.

## Acceptance criteria

- [x] The six inputs return an options table with the parameter left at its default.
- [x] No unguarded `tonumber` left in these parsers' **bounded** numeric paths. `veafCasMission`'s
      `disperse` keeps its `tonumber`: it is already guarded by `if nVal then`, has no bounds, and
      never raised — touching it would be adjacent code, not this fix.
- [x] `poetry run test-lua` green across all suites.

## What the tests measured on the way

The red run failed **9 assertions across exactly 3 suites** and nothing else — and among the new
tests, `_cas, size` and `_cas, size banana` passed *before* the fix. That is the useful control:
it confirms the tests measure the VMR-019 difference rather than the parser in general, since
those two sites are the ones VMR-019 did reach.
