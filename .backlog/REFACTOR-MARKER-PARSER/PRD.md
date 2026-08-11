# REFACTOR-MARKER-PARSER — one marker text parser instead of six

Status: 🔄 in-progress

## Why this exists

`SECREV-2` ticket 06 recommended fixing a family of crashes "in the shared marker parser".
**There is no shared marker parser.** Several modules carry their own copy of the same
keyword loop, and a fix therefore reaches the copy it was written against.

That is not a tidiness complaint — it is measured. `FIX-MARKER-PARAM-CRASHES` (2026-08-11) found
**six live crashes** left standing by `VMR-019`, which had fixed this exact crash shape a month
earlier: it corrected four sites in `veafCasMission`, missed a fifth in the same function, never
scoped `veafMove`, and never touched `veafTransportMission` at all — whose `size` is the same
parameter, with the same 1..5 bounds, still carrying the original `tonumber(val) <= 5`.

## The inventory, measured 2026-08-11

The first version of this PRD listed "ten modules parsing the same shape of input, 641 lines". It
was wrong on three counts, and the corrected picture changes what this lot does.

### Group A — genuinely the same shape, and the target

A keyphrase, then comma-separated `key value` pairs. Six functions named `markTextAnalysis`,
**575 lines**.

| Module | Lines | Valueless `val` | Unknown key | Rule chaining |
|---|---:|---|---|---|
| `veafCasMission` | 127 | `nil` | ignored | separate `if`s |
| `veafMove` | 117 | `nil` | ignored | separate `if`s |
| `veafGroundAI` | 99 | `""` | ignored | separate `if`s |
| `veafSpawnParser` | 88 | `""` | **reported, with a suggestion** | data-driven, all matching rules |
| `veafTransportMission` | 78 | `nil` | ignored | separate `if`s |
| `veafRadio` | 66 | `nil` | ignored | **`elseif`** — only the first rule runs |

### Group B — the same loop under another name, which the first inventory missed

Not called `markTextAnalysis`, so a search for that name did not find them. Same
`split` → `breakString` → `key`/`val` loop, **~87 lines**.

| Site | Lines | Notes |
|---|---:|---|
| `veafGroundAI.lua:385` | ~32 | `ArtilleryUnitHandler:executeCommand` — separator is `;`, not `,` |
| `veafShortcuts.lua:288` | ~22 | `silent` / `name` / `password` |
| `veafShortcuts.lua:394` | ~22 | identical to the above **but for one local's name** (`zoneName` vs `missionName`) |
| `veafShortcuts.lua:509` | ~11 | `password` only |

### Group C — not this shape at all, and deliberately out of scope

Named `markTextAnalysis`, which is the only thing they share with group A. **77 lines, left alone.**

| Function | Lines | Shape |
|---|---:|---|
| `veafSecurity.markTextAnalysis` | 34 | positional: the text after the keyphrase is `logout`, `elevate`, or the password |
| `veafShortcuts.markTextAnalysis` | 22 | one regex: `(-[^#!, ]+)#?([^!,%s]*)!?(%d*)(.*)` |
| `veafNamedPoints.markTextAnalysis` | 21 | positional: the text after the keyphrase is the name |

Forcing these through a comma-splitting parser would **change behaviour**, not share code: a
password containing a comma would be truncated, and a point name would stop at its first space.
Absorbing them would also mean inventing a "take the rest of the text" mode and a "run this
regex" mode for three functions with no known defect between them.

### Group D — already gone

`veafRemote.markTextAnalysis`, credited 11 lines by the first inventory, was deleted by `VMR-130`.
`test_veafRemote.lua` asserts its absence. Nine functions existed, not ten.

## What this lot is

Extract one parser that group A and group B call, and delete what it replaces.

**Not** a rewrite of what each command *does* with its parameters — only how they are read,
converted and defaulted. Every existing marker command must behave identically afterwards, which
is what makes this reviewable at all.

## veafSpawnParser is the source, not a target

`veafSpawnParser` has already been rewritten into the shape ticket 02 asks for. Instead of twenty
copied `if`s it carries a **list of parameters**:

```lua
veafSpawn.ParameterRules = {
  { keys = { "radius" },         apply = _num("radius") },
  { keys = { "hdg", "heading" }, apply = _num("heading") },
  { keys = { "patrol" },         apply = _flag("patrol") },
  ...
}
```

A generic loop — already written, already tested, already in production — applies that list. It
also already does what ticket 02 wants *added*: an unrecognised key is reported to the pilot with
a "did you mean" suggestion (`spawn.unknown_parameters`, `spawn.did_you_mean`).

So the migration order inverts. The first version put `veafSpawnParser` seventh of ten, smallest
first; it goes **first**, because it supplies the machine. Rewriting a generic loop from scratch
and only meeting the hardest case at the end is how you discover too late that it does not fit.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Characterise the parsers before touching them](tickets/01-characterise.md) | ✅ |
| 02 | [Lift veafSpawnParser's machine into veaf.lua](tickets/02-shared-parser.md) | ✅ |
| 03 | [Migrate the remaining modules, one per commit](tickets/03-migrate.md) | ⬜ |

## Why it is worth doing, and why it is no longer urgent

Worth doing: ~660 lines collapse, and the crash family stops recurring by construction rather
than by remembering. Every marker command in the product goes through this code, so the same
defect keeps arriving through a different door — twice now, measurably.

No longer urgent, and for a better reason than the first version gave. That version claimed
`veaf.safeNumber` and the per-site fixes "have taken the sharp edges off the known instances";
that was **false when written** — `veafTransportMission` had three untouched copies. It is true
now that `FIX-MARKER-PARAM-CRASHES` has closed all six and named the rule as
`veaf.safeNumberInRange`. This is the structural cure, and it wants a quiet moment and a full
`test-lua` run.

## What ticket 01 measured

The characterisation is done: every group A and group B parser has a suite pinning today's
behaviour, and the quirk inventory grew from 10 items read out of the code to **19 measured**.
Nine additions were invisible from reading — that a value keeps everything after the *first*
space (so `side  BLUE` with two spaces silently means RED), that flags discard any value given
to them, that sub-verb chains are decided by the chain's order rather than the text's, and that
`ArtilleryUnitHandler`'s `target` is the codebase's only parameter rule which validates its own
input.

Two findings change the plan rather than just informing it:

- **`veafRadio`'s `elseif` is not observable.** The plan called it the one structural difference
  and put the module first to prove the spec could express "at most one rule fires". Testing it
  showed no key is claimed by two live branches, so the permissive form is behaviour-preserving
  here. That is now pinned by a test instead of argued in a document.
- **The three `veafShortcuts` group-B loops are not functions.** The loop is a step inside
  `execute`, which then runs the mission or zone, so they are characterised through spies on
  what the parsing hands downstream. Ticket 03 has to *extract* before it can migrate.

Two new defects joined the recorded list, both wrong-input-accepted rather than crashes:
`veafGroundAI` accepts an empty handler name (the same `""`-is-truthy guard bug `SECREV-010`
fixed in `veafMove`, and which the `veafShortcuts` loops get right), and `veafRadio` destroys a
default when a *recognised* keyword has no value — `_radio transmit, freq` leaves `frequencies`
nil, and `executeCommand` requires it, so the command does nothing at all without telling the
pilot.

## What ticket 02 delivered

`veaf.parseMarkerText(text, spec)` exists, `veafSpawnParser` is its first client with its 71 tests
**unedited**, and the four `apply` kinds are shared as `veaf.markerRules`. Ticket 03 migrates the
rest against a differential harness that is already written.

One root cause fixed on the way, and it is the lot's own thesis for the fourth time:
`veaf.getRandomizableNumeric_random(nil)` raised on `string.find(nil, "%-")`. `VMR-025` described
that crash **in a comment** and then guarded against it **in its caller** — which is precisely why
`_numNonNegative`, one function below, walked into it, and why `FIX-MARKER-PARAM-CRASHES-2` was
needed. It returns nil at the source now. Found because sharing the helper made the old hole
reachable again, and a new test caught it before the merge rather than a pilot after it.

## Risks

- **Behaviour drift.** Ten parsers have ten sets of quirks, and some are load-bearing. Ticket 01
  exists to pin those *before* anything moves.
- **Wide blast radius by definition.** Every marker command depends on it. `test-lua` covers 36
  suites and is the gate; Lua 5.1.5 is installed on `DAVID-BUREAU`, so a local red/green is
  reachable.
