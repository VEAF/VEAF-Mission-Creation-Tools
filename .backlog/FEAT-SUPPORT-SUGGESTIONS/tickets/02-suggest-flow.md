# 02 — `/suggest` files a feature request worth reading

Status: ⬜ ready

Type: feat

## What to build

The command itself, on top of what [ticket 01](01-prior-art-first.md) established and what the bug
lot already provides.

- `/suggest` opens a public thread, like `/ask` and `/bug`.
- The agent asks for what the template needs and the user rarely volunteers: **the problem behind
  the request**, not only the solution he imagined. `feature_request.yml` asks for problem,
  solution, alternatives and context — the first field is the one that makes a request decidable.
- The draft is shown, the user validates, the issue is filed under the same GitHub App with the
  `enhancement` label, in the user's language.
- The prior-art result is recorded in the issue: what was checked, and what was found. A reader
  three months later should not have to redo the search.

## What it stops short of

No design sketch. The session weighed it and turned it down: a wrong sketch in a public issue
steers the discussion into a wall, durably, and it is expensive to unwind. The agent states the
problem, the request and the prior art. Where it would fit and what it would touch is the work of
whoever opens the lot.

## Reuse, not reinvention

Draft and consent, GitHub App, relay and quotas all come from
[`FEAT-SUPPORT-BUG-INTAKE`](../../FEAT-SUPPORT-BUG-INTAKE/PRD.md). If any of it has to be rewritten
here, that is a defect in the bug lot's factoring, not a task for this one.

## Definition of done

- [ ] `/suggest` registered, answering in a public thread
- [ ] The exchange elicits the underlying problem, not only the proposed solution
- [ ] Draft, consent and publication reusing the bug lot's components unchanged
- [ ] Issue filed with `enhancement`, in the template's shape, in the user's language
- [ ] Prior-art findings recorded in the issue body
- [ ] No design sketch produced
- [ ] Unit tests: full flow, a suggestion resolved by prior art, a rejected match continuing
- [ ] Quality gate clean
