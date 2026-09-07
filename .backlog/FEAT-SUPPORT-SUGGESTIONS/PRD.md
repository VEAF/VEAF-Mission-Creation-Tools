# FEAT-SUPPORT-SUGGESTIONS — an idea, checked against what already exists

Status: ✅ done

Origin: design session of 2026-09-05, added by David alongside the bug flow: *take suggestions and
improvement comments too, guided*. Lot 5, and the last, of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md).

## What it does

`/suggest` on the VEAF Discord. The user describes what he would like. The agent **first checks
whether it already exists** — it asks the documentation assistant, and it sweeps the open issues,
`.backlog/` and `ROADMAP.md`. If it does exist, it answers in the thread with the pages and opens
nothing. If it does not, it drafts a feature request, the user validates it, and the issue is filed
under the same GitHub App with the `enhancement` label.

## Why the check comes first

A large share of feature requests are documentation gaps wearing a costume: the thing exists, the
user did not find it. Answering *"it is there, here is the page"* serves him immediately, keeps the
tracker clean, and turns the exchange into a signal about the documentation rather than a task for
David.

It is the same gesture as the duplicate sweep on the bug side, aimed at a wider corpus: a suggestion
can already be implemented, already requested, already scheduled in a lot, or already declined —
`FEAT-ROLE-AWARE-RADIO-MENU` was cancelled with its measurements recorded precisely so the question
would not be reopened without them.

## The asymmetry with a bug

A bug is true or false and can be verified. A suggestion is only wanted or not, and **David is the
only one who decides** — so he is the one who absorbs the volume. That was weighed in the session:
the filter chosen is the prior-art check plus the user's own validation, not a social vote and not a
staff queue. The tracker takes the consequence, deliberately.

`.github/ISSUE_TEMPLATE/feature_request.yml` already exists — problem, solution, alternatives,
context, with a component dropdown — and has never been used by a human. The machine fills it every
time.

## Constraints

- Reuses everything from [`FEAT-SUPPORT-BUG-INTAKE`](../FEAT-SUPPORT-BUG-INTAKE/PRD.md): agent
  runtime, quotas, draft and consent, GitHub App, relay. This lot adds a flow, not an
  infrastructure — if it needs new plumbing, that is a signal the bug lot left something unshared.
- Issue written in the user's language, like a bug report.
- ~~The prior-art sweep costs **no model call at all**~~ — **wrong, and corrected on 2026-09-06**.
  Text matching works over issues, `.backlog/` and `ROADMAP.md`, and it is reused there unchanged.
  It does **not** work over the documentation: measured on the real tree, the words naming a feature
  are in 17% to 60% of the pages, because the pages cross-reference each other, and three successive
  scorings still matched a request for SMS alerts against the support page at 57%. *Does the
  documentation describe a way to do this?* is the question `/ask` already answers, so the flow asks
  it — one model call per suggestion, on the tier measured at 20 requests a day for the whole
  project. The measurement and the three alternatives weighed are in
  [ticket 01](tickets/01-prior-art-first.md).
- The **source tree is not swept**. A user cannot read Lua to find out whether his idea exists, so
  the sources were never an answer to him. When the documentation is silent the filed issue says so,
  which is what makes a maintainer read it as the documentation gap it may be.

## Open question, closed

1. **What happens to a declined suggestion.** An issue that will not be done stays open as a report,
   per `CONTRIBUTING.md`'s two-futures rule. **No distinct label** (decided 2026-09-06):
   `enhancement` + `filed-by-bot` already isolates machine-filed suggestions, and a third term is
   vocabulary to maintain for a filter anyone can write. The expectation itself is now stated to
   users on the support page, since a suggestion open for a year only disappoints someone who was
   told otherwise.

## How it shipped

| # | Ticket | Where it landed |
|---|--------|-----------------|
| 01 | Does it already exist? | `existing.py` — the documentation is **asked**, not searched; three outcomes, the third being *it could not be asked* |
| 02 | `/suggest` files a feature request | `suggestion.py` (the filled template), `suggest.py` (the flow), `exchange.py` + `filing.file_prepared` (the factoring reuse needed) |
| 03 | Tell people what a suggestion becomes | `doc/SUPPORT.md` and `.en.md`, `docs/agents/triage-labels.md`, the service README |

What changed against the plan: the documentation sweep costs a model call, because measuring showed
text matching cannot answer *does this exist* over a corpus that cross-references itself, and the
source tree is not swept at all. Both are argued in ticket 01 with the measurements.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Does it already exist? Answer that first](tickets/01-prior-art-first.md) | feat |
| 02 | [`/suggest` files a feature request worth reading](tickets/02-suggest-flow.md) | feat |
| 03 | [Tell people what a suggestion becomes](tickets/03-docs.md) | docs |
