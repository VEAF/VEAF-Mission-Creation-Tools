# 03 — Migrate the remaining modules, one per commit

Status: ✅ done
Type: refactor

## Order

`veafSpawnParser` is not in this list: ticket 02 migrates it, because it supplies the machine. The
rest run smallest first, so the shared parser is exercised on easy cases before it meets the hard
ones:

| # | Target | Lines |
|---|---|---:|
| 1 | `veafRadio` | 66 |
| 2 | `veafTransportMission` | 78 |
| 3 | `veafGroundAI.markTextAnalysis` | 99 |
| 4 | `veafMove` | 117 |
| 5 | `veafCasMission` | 127 |
| 6 | the four group-B loops | ~87 |

`veafRadio` first is not only about size: its `elseif` chain (quirk 2) is the one structural
difference from the others, so proving the spec can express "at most one rule fires" early is
worth more than saving three lines.

The group-B loops go last because two of them are the same loop twice
(`veafShortcuts.lua:288` and `:394`) and should collapse into one call, which is a judgement about
`veafShortcuts` rather than about the parser.

## Tasks

- [x] One module per commit, each keeping ticket 01's tests for that module green **unchanged**. A
      characterisation test that has to be edited to pass is a behaviour change: stop and say so
      rather than editing it.
- [x] Delete the replaced parser in the same commit. A migration that leaves the old code behind
      has not reduced anything.
- [x] `veafGroundAI` needs care: the spatial fallback (quirk 10) reads the game world from inside
      the parser. Either the spec expresses a post-loop hook or that search moves to the caller —
      decide before migrating, not during.
- [x] The defects ticket 01 recorded get fixed **here**, each in its own commit, each named: the
      dead `disperse` flag branch, `veafRadio`'s unreachable second `path` rule, `Group.getByName("")`,
      and `veafMove`'s nil-over-sentinel. A declared parameter expresses all four; that is the
      argument for the lot, so it should be visible in its diff.

## Acceptance criteria

- [x] All of group A and group B migrated, all replaced parsers deleted, `test-lua` green across
      all suites.
- [x] The line count actually went down; record before and after.
- [x] Group C untouched, and still passing its own tests.

## Delivered

All of group A and group B migrated, every replaced parser deleted, `test-lua` green across 36
suites (2412 tests), and the 485-case sweep still raises nothing.

**Line count, `src/scripts/veaf/` only: 547 deleted against 497 added.** The honest reading is
that the win is not bulk — most added lines are declarations plus the comments recording *why* a
quirk survives — it is that the loop exists once. `veaf.lua` grew by 50 lines and six parsers
stopped carrying their own copy of them.

Nine dead conditions went with it: five `if switch.casmission and ...` and four
`if switch.transportmission and ...`, all always true because the flag is set before the loop.

### Order changed from the plan, with reason

`veafRadio` went first as scheduled, but not for the reason the ticket gave. Its `elseif` chain
was billed as the one structural difference worth proving early; ticket 01 had already measured it
as unobservable, so the migration confirmed a known result rather than probing an open question.

### The three veafShortcuts loops needed extracting first

As ticket 01 flagged. Two of them were identical but for one local's name (`missionName` versus
`zoneName`) — the clearest illustration in the repository of the lot's premise. They are one spec
and one function now. The spy-based characterisation tests are what made that safe, and they pass
unedited.

## The six recorded defects, each in its own named commit

1. **`disperse` never became the flag it was written to be** — the `else` giving 15 seconds was
   unreachable because a valueless keyword arrives as nil, never `""`.
2. **`veafRadio`'s unreachable second `path` rule** — deleted rather than translated.
3. **A mistyped radio keyword silenced the command** — `_radio transmit, freq` set `frequencies`
   to nil, which `executeCommand` requires, so the command did nothing and said nothing. An
   *unknown* keyword was harmless by comparison. `veaf.markerRules.textKeepingDefault` fixes it.
4. **`veafMove`'s nil over the `-1` sentinel** — and this one was mis-recorded. See below.
5. **`veafGroundAI` accepted a nameless handler** — `if not options.name` never fired, because
   values arrive as `""` and `""` is truthy in Lua. `SECREV-010`'s bug, in the copy nobody
   revisited.
6. **`Group.getByName("")`** — skipped now, which is also what lets the spatial fallback run.

### Defect 4 was described wrongly, and the tests caught it

It was recorded as "a nil travels downstream instead of the sentinel", which reads as harmless.
Two pre-existing `VMR-092` tests asserted exactly that outcome — *"an unparseable speed must end up
unset, not crash"* — and stopping to measure rather than editing them showed why they were wrong:

    moveGroup(speed=nil)    -> RAISE veafMove.lua:215: attempt to concatenate local 'speed'
    moveGroup(alt=nil)      -> RAISE veafMove.lua:215: attempt to concatenate local 'altitude'
    changeTanker(speed=nil) -> ok
    moveAfac(speed=nil)     -> ok
    moveTanker(speed=nil)   -> ok

Unset did not remove the crash, it moved it one call downstream. `_move group, name A, speed abc`
parsed cleanly and then took the command down. The other three consumers tolerate nil, which is
why it survived for years.

So this was a **twelfth crash in the family**, and it exposed a real gap in method: all 485 sweep
cases probed *parsers*, never the whole command path. An `executeCommand`-level assertion is in
place now.
