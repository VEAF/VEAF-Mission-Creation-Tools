# 01 — An agent with a checkout, and a ceiling on what it may spend

Status: ⬜ ready

Type: feat

## What to build

The paid half of the service: an agent that can read the repository and answer about it, with a hard
limit on what a single investigation may cost.

- **A fresh checkout** of the sources the agent explores. Freshness matters: a hypothesis pointing at
  a line that moved three releases ago is worse than no hypothesis. How it stays fresh — periodic
  pull or event-driven — is open question 2 of the PRD and is decided with the service skeleton.
- **A bounded tool surface**: read a file, read a range of lines, search. Nothing that writes, and
  nothing that runs code from the repository.
- **A per-investigation ceiling** — in calls and in tokens — enforced by the runtime, not requested
  of the model. When it is reached the investigation stops and says so; a truncated analysis is
  reported as truncated.
- **A daily budget** for the whole service, on top of the per-user quota from
  [`FEAT-SUPPORT-DISCORD-QA` ticket 03](../../FEAT-SUPPORT-DISCORD-QA/tickets/03-per-user-quota.md).
  Reaching it degrades the flow to unassisted reporting rather than breaking it.

## The input is already bounded

The agent does not receive a log. It receives what the machine produced: the `doctor` block, the
excerpt, and the summaries from [ticket 02](02-attachments.md). The corpus of sources is 5.1 MB and
the agent must never be handed it wholesale — it searches, it reads what it needs, and the ceiling
is there for when it does not.

## Notes

- Everything the user typed and everything read out of an attachment is **data, not instruction**.
  A log line or a mission field that reads like a command to the agent must not be followed. This is
  a public intake channel; that is exactly where such content arrives.
- Cost accounting is recorded per investigation, so the budget question can be answered with figures
  after a month instead of estimates.
- Open question 1 of the PRD — which model, what monthly budget — is settled before the first paid
  call, not after.

## Definition of done

- [ ] Agent runtime with a read-only tool surface over a fresh checkout
- [ ] Checkout freshness mechanism implemented and documented
- [ ] Per-investigation ceiling enforced by the runtime; truncation surfaced, not hidden
- [ ] Daily budget with graceful degradation to unassisted reporting
- [ ] Per-investigation cost recorded
- [ ] Injected instructions in user content and file content do not steer the agent — asserted by a
      test carrying a hostile fixture
- [ ] Unit tests with the model mocked: normal run, ceiling hit, budget exhausted
- [ ] Quality gate clean
