# Lot REFACTOR-MARKER-PARSER — one marker text parser instead of ten copies

Status: ✅ done

**Goal**: `SECREV-2` ticket 06 recommended fixing a family of crashes "in the shared marker parser".
There was none — the same `key value` loop was copied across the codebase, so a fix reached the copy
it was written against. Extract one parser the modules call, and delete what it replaces, with every
existing marker command behaving identically afterwards.

**Branches**: `test/marker-parser-characterisation` → [#711](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/711),
`feature/shared-marker-parser` → [#712](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/712),
`refactor/migrate-marker-parsers` → [#713](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/713) → `develop`

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | Characterise the parsers before touching them | test | ✅ |
| 02 | Lift veafSpawnParser's machine into veaf.lua | feat | ✅ |
| 03 | Migrate the remaining modules, one per commit | refactor | ✅ |

## The inventory was wrong on three counts

The original PRD claimed "ten modules parsing the same shape of input, 641 lines". Re-measured
2026-08-11 before any code moved:

- **Nine, not ten**: `veafRemote.markTextAnalysis` was deleted by `VMR-130`, and
  `test_veafRemote.lua` asserts its absence.
- **Three shapes, not one**: 6 parsers take comma-separated pairs (575 lines, the target); 4 more
  loops are the same code under other names (~87 lines, invisible to a search for
  `markTextAnalysis` — one in `ArtilleryUnitHandler` splitting on `;`, three inline in
  `veafShortcuts`, two of those identical but for one local's name); and 3 are positional or a
  single regex (77 lines) — `veafSecurity`, `veafNamedPoints`, `veafShortcuts.markTextAnalysis` —
  **deliberately excluded**, since a comma-splitting parser would truncate a password containing a
  comma or a point name at its first space.
- **`veafSpawnParser` was the source, not the seventh target**: already declarative, with the
  unknown-key reporting ticket 02 wanted *added*. The migration order inverted to put it first.

Also corrected: the claim that `veaf.safeNumber` and the per-site fixes "have taken the sharp edges
off the known instances" was **false when written** — `veafTransportMission` had three untouched
copies (see `FIX-MARKER-PARAM-CRASHES`).

## What shipped

`veaf.parseMarkerText(text, spec)` and `veaf.prepareMarkerSpec(spec)`, with `veaf.markerRules.{number,
nonNegativeNumber, plainNumber, boundedNumber, text, textKeepingDefault, flag, requireText}` and
`veaf.isBlank`. A module declares its parameters; the loop lives in one place.

The specification expresses every load-bearing quirk ticket 01 measured: `valueWhenAbsent` (nil vs
`""`), `separator` (`,` vs `;`), first-match-wins command descriptors seeding per-sub-verb defaults,
all-matching-rules-run with `when` gating, values kept **untrimmed** (so `side  BLUE` with two
spaces still resolves to RED), opt-in unknown-key reporting with a suggestion, and a post-loop
`validate`.

**547 lines deleted against 497 added** under `src/scripts/veaf/`. The win is not bulk — most added
lines are declarations plus comments recording *why* a quirk survives — it is that the loop exists
once. Nine always-true conditions went with it (five `if switch.casmission and …`, four
`if switch.transportmission and …`). 36 suites, 2412 tests.

**`veafGroundAI`'s design question, answered**: the nearest-allied-group search stays *out* of the
specification — it needs the marker's position and coalition and it reads the game world. The shared
parser handles text; `markTextAnalysis` handles the world.

## Ticket 01's inventory: 10 quirks read, 19 measured

Nine were invisible from reading, and each could have been silently broken: a value keeps everything
after the **first** space untrimmed; flags discard any value handed to them (`teleport false`
teleports); sub-verb chains are decided by the chain's order and not the text's (`_move group tanker`
is a group move, `fire aim` is an aim); `ArtilleryUnitHandler`'s `target` is the codebase's only
parameter rule that validates its own input; a repeated keyword ends on its last occurrence;
decimals are accepted everywhere; `veaf.trim` runs before the split so a trailing space is never a
value.

Two findings changed the plan rather than informing it: **`veafRadio`'s `elseif` chain is not
observable** (no key is claimed by two live branches, so the permissive shared loop is
behaviour-preserving — pinned by a test instead of argued), and **the three `veafShortcuts` loops are
not functions** but steps inside `execute`, characterised through spies on what they hand downstream,
so ticket 03 had to extract before it could migrate.

## The six recorded defects, each fixed in its own named commit

| Defect | Fix |
|---|---|
| `disperse` never reached the 15 s its `else` promised — a valueless keyword arrives as nil, never `""` | both empty forms reach `veafCasMission.DEFAULT_DISPERSE_DELAY` |
| `veafRadio`'s duplicate second `path` rule | unreachable, deleted rather than translated |
| a **recognised** radio keyword with no value destroyed its default, so `_radio transmit, freq` did nothing at all and said nothing — an **unknown** keyword was harmless by comparison | `veaf.markerRules.textKeepingDefault` |
| `veafMove` assigned nil over the `-1` sentinel | `plainNumber` keeps the field — and see below |
| `veafGroundAI` accepted a nameless handler: `if not options.name` cannot catch `""`, truthy in Lua — `SECREV-010`'s bug in the copy nobody revisited | `veaf.markerRules.requireText` |
| `Group.getByName("")` on a valueless `groupname` | skipped, which is also what lets the spatial fallback run |

## The premise was demonstrated four times while doing the work

Three of them in code already believed fixed:

| Where | What |
|---|---|
| `veafTransportMission` ×3, `veafCasMission`, `veafMove` | six live crashes `VMR-019` had missed |
| `veafSpawnParser` ×4, `veafTransportMission` | three more the first probe missed by sampling |
| `veaf.getRandomizableNumeric` | `VMR-025` described the crash in a comment, then guarded its **caller** — so its sibling walked in |
| `veafMove.moveGroup` | a twelfth: "unset, not crash" only moved the crash downstream |

### The last one is the most useful

Defect 4 was recorded as *"a nil travels downstream instead of the sentinel"* — which reads as
harmless. Two **pre-existing** `VMR-092` tests asserted exactly that outcome: *"an unparseable speed
must end up unset, not crash"*. Measuring instead of editing them:

    moveGroup(speed=nil)    -> RAISE veafMove.lua:215: attempt to concatenate local 'speed'
    moveGroup(alt=nil)      -> RAISE veafMove.lua:215: attempt to concatenate local 'altitude'
    changeTanker(speed=nil) -> ok
    moveAfac(speed=nil)     -> ok
    moveTanker(speed=nil)   -> ok

Unset did not remove the crash, it moved it one call downstream. `_move group, name A, speed abc`
parsed cleanly and then took the command down on a log line. The other three consumers tolerate nil
(`moveTanker` tests `speed == nil or speed < 0`), which is why it survived for years.

**The gap it exposed matters more than the fix**: all 485 sweep cases probed *parsers*, never the
whole command path. An `executeCommand`-level assertion now covers it.

## On Sourcery's reviews

Ticket 02: keys are stored lower-cased (a spec declaring `"Size"` would not only fail to match, it
would be reported to the pilot as an unknown parameter); the keyword loop walks with `ipairs`, since
order is load-bearing and Lua guarantees nothing about `pairs` on a sequence — every copied parser
used `pairs` and got away with it; and a duplicate derivation of `KnownParameterKeys` became aliases
of the prepared spec.

Ticket 03: `veaf.isBlank` and `veaf.markerRules.requireText` replaced the `x ~= nil and x ~= ""`
check three modules were each spelling out, and `parseAliasParameters` seeds its fallback from the
spec's own `defaults`. Both remarks were duplication — this lot's subject surfacing inside its own
PRs, twice.

## Process notes, for honesty

One commit went out on a red suite: an `&&` chain tested `tail`'s exit code rather than `test-lua`'s.
Caught and corrected in the following commit — which is also the one that found the mis-recorded
defect above. Exit codes are checked explicitly since.
