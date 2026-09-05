# FEAT-SUPPORT-SUGGESTIONS — an idea, checked against what already exists

Status: ⬜ ready

Origin: design session of 2026-09-05, added by David alongside the bug flow: *take suggestions and
improvement comments too, guided*. Lot 5, and the last, of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md).

## What it does

`/suggest` on the VEAF Discord. The user describes what he would like. The agent **first checks
whether it already exists** — in the documentation, in the code, in `.backlog/` and in
`ROADMAP.md`. If it does, it answers in the thread with the link and opens nothing. If it does not,
it drafts a feature request, the user validates it, and the issue is filed under the same GitHub App
with the `enhancement` label.

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
  runtime, budget and quotas, draft and consent, GitHub App, relay. This lot adds a flow, not an
  infrastructure — if it needs new plumbing, that is a signal the bug lot left something unshared.
- Issue written in the user's language, like a bug report.
- No paid call is made before the prior-art sweep has run; a suggestion answered by an existing page
  should cost almost nothing.

## Open question

1. **What happens to a declined suggestion.** An issue that will not be done stays open as a report,
   per `CONTRIBUTING.md`'s two-futures rule. Whether machine-filed suggestions deserve a distinct
   label so they can be swept later is worth deciding before the tracker fills.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Does it already exist? Answer that first](tickets/01-prior-art-first.md) | feat |
| 02 | [`/suggest` files a feature request worth reading](tickets/02-suggest-flow.md) | feat |
| 03 | [Tell people what a suggestion becomes](tickets/03-docs.md) | docs |
