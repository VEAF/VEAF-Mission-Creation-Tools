# Lot FIX-MARKER-PARAM-CRASHES — six marker parameters that still took the command down

Status: ✅ done

**Goal**: a pilot omitting or mistyping a marker parameter's value lost the whole command, not just
the parameter. Six sites, proven before being fixed by a `pcall` probe over the real parsers under
Lua 5.1.

**Branch**: `fix/marker-param-crashes` → [#709](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/709) → `develop`

| Marker text | Raised at | Cause |
|---|---|---|
| `_cas, side` | `veafCasMission.lua:566` | `string.format("%s", nil)`, then `val:upper()` on the next line |
| `_move group, name` | `veafMove.lua:188` | `string.format("%s", nil)` |
| `_transport, size` (bare or `banana`) | `veafTransportMission.lua:193` | `tonumber(nil) <= 5` |
| `_transport, defense` | `veafTransportMission.lua:202` | same |
| `_transport, blocade` | `veafTransportMission.lua:211` | same |

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | Stop the six crashes | fix | ✅ |

**Why they survived VMR-019**: that lot fixed this exact crash shape and introduced
`veaf.safeNumber` for it, reaching four sites in `veafCasMission`. It left that module's `%s`-on-nil
log for `side`, never scoped `veafMove`, and **never touched `veafTransportMission` at all** — whose
`size` is the same parameter with the same 1..5 bounds and still carried the original
`tonumber(val) <= 5`. The argument for `REFACTOR-MARKER-PARSER`, stated as a bug.

**Behaviour decided**: a bad parameter costs that parameter only. Out-of-range values stay
*ignored* rather than clamped (VMR-019's decision, not revisited). A valueless `side` leaves the
side **unset** rather than falling through to RED — correcting only the log would have handed a
mistyping blue pilot a red group.

**On Sourcery's review**: the `safeNumber`-plus-bounds pattern the seven numeric keywords wrote out
inline became `veaf.safeNumberInRange(value, min, max)`, the *rejecting* twin of `veaf.safeNumber`
(which clamps). Applied to all seven sites, not just the three new ones — centralising only the new
copies would have left the divergence the helper exists to prevent.

> **The control worth remembering**: among the 12 new tests, `_cas, size` and `_cas, size banana`
> passed *before* the fix. That is what proves the suite measured the VMR-019 gap rather than the
> parsers in general.

**Recorded, not fixed here** (all carried into `REFACTOR-MARKER-PARSER`): `veafCasMission`'s
`disperse` never reaching its 15-second default because `veaf.breakString` returns nil and never
`""`; `veafRadio`'s unreachable duplicate `path` rule; `Group.getByName("")` on a valueless
`groupname`; `veafMove` overwriting its `-1` sentinel with nil.
