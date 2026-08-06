# 06 — The 24 medium findings

Status: ⬜ ready
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
