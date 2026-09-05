# 01 — Does it already exist? Answer that first

Status: ⬜ ready

Type: feat

## What to build

Before anything is drafted, the agent sweeps four corpora and reports what it found:

| Source | Verdict it can return |
|---|---|
| `doc/` | it exists and is documented — here is the page |
| the sources | it exists but is undocumented — which is a documentation ticket, not a feature |
| `.backlog/` | a lot already covers it, at this status |
| `ROADMAP.md` | it is parked, ordered, or explicitly cancelled with its reasons |

Each verdict produces a different answer in the thread, and three of the four open no issue at all.

## The verdict worth calling out

*"It exists but is undocumented"* is the most useful outcome of the whole flow. It converts a
feature request into a documentation gap — the cheapest possible fix, and one that prevents the same
request arriving again. It should be reported as such rather than folded into "it already exists".

## The failure mode to guard

A wrong *"it already exists"* silences a real idea, and the user will not argue with a bot. The
match is always shown with its evidence — the page, the function, the lot — and the user can say
*that is not what I meant* and continue to a real suggestion.

## Cost

This sweep runs before any paid call, and a suggestion resolved by an existing page should cost close
to nothing. Reuse the agent runtime and the budget accounting from
[`FEAT-SUPPORT-BUG-INTAKE` ticket 01](../../FEAT-SUPPORT-BUG-INTAKE/tickets/01-agent-runtime.md).

## Definition of done

- [ ] Sweep across `doc/`, the sources, `.backlog/` and `ROADMAP.md`
- [ ] Four distinct verdicts implemented, each with its own answer in the thread
- [ ] "Exists but undocumented" reported separately from "exists"
- [ ] Every match shows its evidence and can be rejected, after which the flow continues
- [ ] No paid call before the sweep has run
- [ ] Unit tests with a fixture repository, one per verdict, plus the rejection path
- [ ] Quality gate clean
