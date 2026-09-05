# FEAT-SUPPORT-BUG-INTAKE — from "it does not work" to an issue somebody can act on

Status: ⬜ ready

Origin: design session of 2026-09-05. Lot 4 of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md), and the only one that spends money
and writes to a public repository.

## What it does

`/bug` on the VEAF Discord opens a guided exchange. The user describes the problem and attaches what
he has. The service downloads and filters those files, runs an agent over a fresh checkout of the
sources, sweeps the existing issues and the backlog for prior art, redacts, and shows a **draft**.
The user clicks. The issue is created under a dedicated GitHub App, in the user's own language.
Afterwards, comments and closure on that issue are relayed back into the Discord thread.

`/ask` gets an escalation button into this flow, which is the passage the two commands were designed
around.

## Why an agent and not the RAG

This is where reading the code pays. A stack trace names a file and a line — `veafNamedPoints.lua:4219`
— and a semantic search over chunks is the wrong instrument for an exact address. An agent with a
checkout can open that line, walk back to the callers, and check a hypothesis.

That is also why it stays **here and nowhere else**. The paid model is reserved for the rare,
high-value event; `/ask` and the log analyser keep running on the free tier. Volume on one side,
value on the other — the programme's first principle.

## What the measurement says about the target

There are **4 user-opened issues still open**, the most recent from March 2024; the last issue filed
by a user at all is #304, January 2026; 9 issues open in total. The forms in
`.github/ISSUE_TEMPLATE/` have never been used — **0 of the last 60 issues**. And when a regular
reports, the report is already good: #212 came with the diagnosis, the exact lines, the fix and
before/after screenshots.

So this lot is not there to absorb a flood, and it must not create one. Its job is to make the rare
report complete, deduplicated, and answerable — and to make the person who filed it hear back.

## The decisions that shape it

| Decision | Consequence to build |
|---|---|
| The issue is created by a **machine account** | the author cannot be reached on GitHub, hence the relay in ticket 06 |
| The **user validates the draft** before publication | the flow is two-step by construction, and the draft must be readable |
| The agent **reads the attached files** | download, filtering and summarising to write, and a context that must stay bounded |
| Everything published is **redacted first** | a `dcs.log` carries `C:\Users\Firstname Lastname\...`, server addresses, session identifiers |
| The agent gives a **labelled hypothesis** with file and line | it must be visually separable from the facts, and never read as a diagnosis |
| Prior art is swept across issues **and** `.backlog/` | `CONTRIBUTING.md` says issues are an intake desk and the work lives in lots |
| The issue is written **in the user's language** | departs from the repository's English-only rule for technical content, and matches what the tracker already contains |
| Quota per user, global daily ceiling | reuses the counters from [`FEAT-SUPPORT-DISCORD-QA` ticket 03](../FEAT-SUPPORT-DISCORD-QA/tickets/03-per-user-quota.md), with a real budget behind them |

## Size warning

This lot is large. Sourcery stops reviewing past ~150 000 characters of diff, and its weekly budget
is 250 000 across all PRs — measured on #759, and again on 2026-08-24 when #796 got the rate-limit
message 24 minutes after #795 was reviewed. **Sequence this into several PRs**, groundwork first
(tickets 01–02), rather than opening one unreviewable PR.

## Open questions

1. **Which Claude model, and the monthly budget.** The daily ceiling must be a figure before the
   first paid call is made, not after the first invoice.
2. **How the checkout stays fresh**: periodic pull or event-driven, decided with the service
   skeleton.
3. **What `doctor` prints** — this lot parses it, so its format has to be settled in lot 1.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [An agent with a checkout, and a ceiling on what it may spend](tickets/01-agent-runtime.md) | feat |
| 02 | [Attachments become bounded, redacted material](tickets/02-attachments.md) | feat |
| 03 | [Nothing gets reported twice](tickets/03-prior-art-sweep.md) | feat |
| 04 | [The draft, and the click that publishes it](tickets/04-draft-and-consent.md) | feat |
| 05 | [The issue is filed by a GitHub App, not by a person](tickets/05-github-app.md) | feat |
| 06 | [The answer comes back to where the user is](tickets/06-relay.md) | feat |
| 07 | [Say what the machine wrote, and what it guessed](tickets/07-docs.md) | docs |
