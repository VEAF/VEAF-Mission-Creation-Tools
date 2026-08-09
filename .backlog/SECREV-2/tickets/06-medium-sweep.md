# 06 — The 24 medium findings

Status: ✅ done — all 24 carry an outcome
Type: fix
Findings: VMR-009 … VMR-032 at 🟡 MEDIUM (see `findings-triage.json`)

## Shape of the work

Eleven are **untouched** since the review and almost certainly stand; thirteen are **review-needed**
because their file changed. Six belong to other tickets and should not be done twice:

| Finding | Goes to |
|---|---|
| VMR-009, VMR-011 | ticket 04 (fail-closed integrity) |
| VMR-010, VMR-012, VMR-013 | ticket 02 (unsafe interpolation) |
| VMR-026 | **already fixed** by TOOLING-REPO-LINK-GATE on 2026-08-05 — close it, do not redo it |

That leaves eighteen, and they fall into three natural groups.

## Group A — marker parameters that crash their handler

VMR-019, VMR-020, VMR-021, VMR-023, VMR-025, and siblings in the low tail. All the same shape: a
player omits or garbles a parameter, and `tonumber(nil)`, `string.format('%d', nonNumber)` or a bad
table iteration takes the whole handler down.

The review's recommendation is to **validate and default in the shared marker parser**, not at each
call site — same argument as ticket 03: fixing five call sites leaves the sixth. Worth doing that way
even though it is more work than five nil-guards.

- [ ] Find the shared parser and decide whether it can carry validation for the parameter kinds in use.
- [ ] Fix the named instances through it; a per-site guard only where the shared path genuinely cannot.

## Group B — Lua runtime nil-safety and logic

VMR-017, VMR-018, VMR-022, VMR-024. Independent bugs: an event handler aborting the remaining match
managers, an unguarded dereference, dead `type()` guards making a normalisation ineffective, a
point-defence lookup against an API that does not answer the way the caller assumes.

- [ ] One at a time, each with a test. They share no pattern, so batching them buys nothing.

## Group C — documentation that is wrong, not merely stale

VMR-014 is the one that matters: **the coalition ID mapping in `LUA_API_REFERENCE.en.md` is
backwards** — it says 1=blue/2=red where DCS uses RED=1, BLUE=2. A reader who trusts it writes code
that targets the wrong side. Fix it in both languages and check whether anything in the repo was
written from it.

VMR-027, VMR-028 (counts that have drifted: "31 test suites" when there are 34, "34 files" when there
are 41), VMR-029 (broken ToC slugs), VMR-030 (says a Klogg profile is planned when it ships),
VMR-031 (a config field named `enable` while the examples use something else), VMR-032 (FR and EN
diverge).

- [ ] VMR-014 first and separately — it is a correctness defect wearing documentation's clothes.
- [ ] The counts: consider whether a check can derive them, since they will drift again. `docs-check`
      now has the machinery for exactly this (TOOLING-DOC-AUTOGEN).

## Acceptance criteria

- [ ] Every one of the 24 has an outcome recorded in the triage: fixed, elsewhere, or disproved.
- [ ] Each fix carries a test, except the pure documentation ones.
- [ ] The three findings routed to other tickets are marked as such rather than silently skipped.


## Outcome, 2026-08-08

**All 24 mediums carry an outcome**, which was this ticket's acceptance criterion. 20 fixed
here or in tickets 04/05, 3 routed to ticket 02, 1 (VMR-026) closed as already-fixed after
verifying rather than assuming.

Two of the ticket's own premises were wrong, and finding that out was part of the work:

- **"Fix group A in the shared marker parser."** There is none. Ten modules carry their own
  `markTextAnalysis`, 641 lines between them. The conversion was shared instead
  (`veaf.safeNumber`), and the structural cure is filed as `REFACTOR-MARKER-PARSER`.
- **"Group A: all the same shape."** Only VMR-019 and VMR-025 were parameter-parsing crashes.
  VMR-020, 021 and 023 are independent nil-safety bugs and were done as group B.

Worth recording about group C: the drifting counters were **removed rather than corrected**.
The guide said 31 test suites and 34 files; the review said 34 and 41; the truth today is 36
and 42. A number that has been wrong three times will be wrong again, and a directory tree
does not need to count itself.

Three fixes ship without a test, each said out loud rather than left to be noticed: VMR-021
and VMR-018 (inside long methods needing broad mocking, both provable by reading the guard
two lines away) and VMR-024 (provable by reading Skynet's signature).
