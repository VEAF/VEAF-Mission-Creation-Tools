# FIX-MARKER-PARAM-CRASHES — six marker parameters that still take the command down

Status: ✅ done

## What happens today

A pilot types a marker command and omits a parameter's value, or mistypes it. The whole command
dies. Measured 2026-08-11 with a `pcall` probe over the real parsers under Lua 5.1:

| Marker text | Raises at | Cause |
|---|---|---|
| `_cas, side` | `veafCasMission.lua:566` | `string.format("%s", nil)` in the log line, then `val:upper()` on line 567 |
| `_move group, name` | `veafMove.lua:188` | `string.format("%s", nil)` in the log line |
| `_transport, size` | `veafTransportMission.lua:193` | `tonumber(nil) <= 5` |
| `_transport, size banana` | `veafTransportMission.lua:193` | same, non-numeric value |
| `_transport, defense` | `veafTransportMission.lua:202` | `tonumber(nil) <= 5` |
| `_transport, blocade` | `veafTransportMission.lua:211` | `tonumber(nil) <= 5` |

## Why they survived VMR-019

`VMR-019` fixed exactly this crash shape — four times over, in `veafCasMission`, and it introduced
`veaf.safeNumber` for it. It did not reach these six:

- In `veafCasMission` it fixed the four `string.format("%d", val)` sites (`size`, `defense`,
  `armor`, `spacing`) and left the `%s` one on `side`, which raises just the same.
- `veafMove` has the same `%s`-on-nil shape on `name`, and was never in scope.
- `veafTransportMission` was **never touched at all**. Its `size` is the same parameter as
  `veafCasMission`'s — same name, same 1..5 bounds, same intent — and carries the original
  `tonumber(val) <= 5`.

That is the whole argument for `REFACTOR-MARKER-PARSER`: the code is copied, so a fix reaches one
copy. This lot closes the copies that are still broken; the refactor stops new ones appearing.

## What this lot is

Make a bad parameter cost the pilot that parameter, never the command. Nothing else: the value
each command *does* with its parameters is untouched, and out-of-range values keep being ignored
rather than clamped, exactly as `VMR-019` decided.

This lot runs **before** `REFACTOR-MARKER-PARSER` deliberately. That lot's first ticket writes
tests pinning today's behaviour so a reader can verify the refactor changed nothing — and six of
those behaviours are crashes. Pinning them, then unpinning them two tickets later, is precisely
what the pinning exists to avoid.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Stop the six crashes](tickets/01-nil-safe-params.md) | ✅ |

## Out of scope

None of these raises, so none belongs in a lot whose subject is "stop the six crashes". All are
recorded for `REFACTOR-MARKER-PARSER`, whose parameter declarations are where they get expressed
rather than patched.

- **`veafCasMission`'s `disperse` never becomes the flag it was written to be.** The code reads
  `if val ~= "" then tonumber(val) else 15 end`, so a bare `disperse` was meant to mean "disperse
  after 15 seconds". But `veaf.breakString` returns **nil** for a valueless keyword, never `""`,
  so the `else` is dead: `_cas, disperse` leaves `disperseOnAttack` at `false`. Proven with a
  probe. The declarative parser expresses this as a keyword with a *flag default*, which is the
  fix — a patch here would just move the dead branch.
- The `elseif`-chain duplicate of the `path` rule in `veafRadio` (unreachable, no crash).
- `Group.getByName("")` on a valueless `groupname` in `veafGroundAI` (returns nil, no crash).
- `veafMove` overwriting its `-1` sentinel with nil on an unreadable `speed`/`hdg`/`alt`/`dist`
  (no crash at parse time; a nil flows downstream).
