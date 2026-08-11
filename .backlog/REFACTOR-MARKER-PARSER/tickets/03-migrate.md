# 03 — Migrate the remaining modules, one per commit

Status: ⬜ ready
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

- [ ] One module per commit, each keeping ticket 01's tests for that module green **unchanged**. A
      characterisation test that has to be edited to pass is a behaviour change: stop and say so
      rather than editing it.
- [ ] Delete the replaced parser in the same commit. A migration that leaves the old code behind
      has not reduced anything.
- [ ] `veafGroundAI` needs care: the spatial fallback (quirk 10) reads the game world from inside
      the parser. Either the spec expresses a post-loop hook or that search moves to the caller —
      decide before migrating, not during.
- [ ] The defects ticket 01 recorded get fixed **here**, each in its own commit, each named: the
      dead `disperse` flag branch, `veafRadio`'s unreachable second `path` rule, `Group.getByName("")`,
      and `veafMove`'s nil-over-sentinel. A declared parameter expresses all four; that is the
      argument for the lot, so it should be visible in its diff.

## Acceptance criteria

- [ ] All of group A and group B migrated, all replaced parsers deleted, `test-lua` green across
      all suites.
- [ ] The line count actually went down; record before and after.
- [ ] Group C untouched, and still passing its own tests.
