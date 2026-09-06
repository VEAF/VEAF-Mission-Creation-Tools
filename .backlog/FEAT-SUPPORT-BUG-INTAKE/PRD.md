# FEAT-SUPPORT-BUG-INTAKE — from "it does not work" to an issue somebody can act on

Status: ✅ done

Origin: design session of 2026-09-05, **redesigned the same day** once the free-tier quota was
measured. Lot 4 of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md), and the only one that writes to a
public repository.

## Two paths, and the deterministic one is the floor

`/bug` opens a **Discord form** — not a conversation. The user describes the problem in a few fields
and attaches what he has. From there the service does everything it can without any model at all,
and files the issue immediately. A model is then used to *enrich* that issue, for VEAF members and
while the day's small quota lasts. When it runs out, or when the reporter is not a member, nothing
breaks: the issue is already there, complete, minus one section.

| | Deterministic path — everyone, always | AI enrichment — members, within quota |
|---|---|---|
| Collect | Discord form + attachments | — |
| Read the tool's state | parse the `doctor` block | — |
| Reduce the log | `rules.json` + the shared excerpt builder | — |
| Locate the fault | the stack trace names `file:line`; read the neighbourhood and the callers | — |
| Summarise the mission | existing `.miz` export | — |
| Prior art | issues, `.backlog/`, `ROADMAP.md` | — |
| Redact | shared redaction helper | — |
| File the issue | GitHub App, template shape, user's language | — |
| Hypothesis | *(absent, and the issue says so)* | one call, on the prepared context |

The point is not that the model is optional. It is that **the issue is worth reading without it**,
so a quota, an outage or a non-member never turns a bug report into nothing.

## Why it was redesigned

The first design had an agent explore a checkout freely — ten to twenty model calls per report.
Then the free tier was **measured on AI Studio** rather than assumed: **20 requests per day**, for
both `gemini-2.5-flash` (5 RPM) and `gemini-2.5-flash-lite` (10 RPM), per Google project. David
chose to stay on the free tier rather than enable billing — 50 analyses a day would have cost about
$6 a month at the paid rate, and the decision was not to engage a payment method for that.

Twenty requests a day makes a chatty agent impossible, and that turned out to be a good constraint:
almost everything the agent was doing needed no model in the first place. A stack trace *names* the
file and the line; finding the callers is a search; prior art is a text match; a template is a
template. Once all of that is prepared, one call is enough to conclude on it.

| | |
|---|---|
| Free-tier quota, per project, per day | **20 requests** |
| Model calls per enriched report | **1**, enforced by the runtime |
| Daily ceiling on enrichment | **15**, leaving 5 requests of margin |
| Reports handled per day | **unlimited** — the deterministic path has no quota |

## Who gets the enrichment

Holders of a **VEAF Discord role**. It is read from the interaction itself, so the check costs
nothing and cannot be forged. Everyone else gets the deterministic issue, which is the same issue
minus the hypothesis section — not a degraded service, a service without a guess in it.

That is also the honest place for the boundary: the enrichment spends a shared association resource,
and members are who the association answers to first.

## The decisions that shape it

| Decision | Consequence to build |
|---|---|
| A **form**, not a conversation | collection costs zero model calls and answers instantly |
| The issue is filed by a **machine account** | the author cannot be reached on GitHub, hence the relay |
| The issue is filed **immediately**, before any enrichment | a quota failure can never lose a report |
| The service **reads the attached files** | download, filtering and summarising to write, all deterministic |
| Everything published is **redacted first** | a `dcs.log` carries `C:\Users\Firstname Lastname\...`, server addresses, session ids |
| The hypothesis is **labelled as a machine guess**, with file and line | visually separable from the facts, never readable as a diagnosis |
| Prior art is swept across issues **and** `.backlog/` | `CONTRIBUTING.md` says issues are an intake desk and the work lives in lots |
| The issue is written **in the user's language** | departs from the repository's English-only rule, matches what the tracker already contains |

## What is deliberately not built

**A conversation that chases missing information.** The form asks for what the template needs; if a
field is empty, the issue says so. Chasing it would cost calls, and the measurement that opened this
programme says the missing pieces are mechanical facts `doctor` already supplies.

**A second analysis pass.** If one call is not enough, the answer is a better prepared context, not
more calls.

## Open questions

1. **Which Discord role** gates the enrichment, and who grants it. David's call; the code reads a
   role id from the environment. **Still open, and it does not block anything**: the enrichment is
   off while `SUPPORT_BOT_ENRICH_ROLE_ID` is unset, and reports are filed complete without it.
2. ~~**How the checkout stays fresh**~~ — settled in ticket 01: a periodic refresh with a bounded
   interval, reported on the issue as the revision every location was resolved against.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A form, and everything it becomes without a model](tickets/01-form-and-extraction.md) | feat |
| 02 | [Attachments become bounded, redacted material](tickets/02-attachments.md) | feat |
| 03 | [Nothing gets reported twice](tickets/03-prior-art-sweep.md) | feat |
| 04 | [The preview, and the click that files it](tickets/04-draft-and-consent.md) | feat |
| 05 | [The issue is filed by a GitHub App, not by a person](tickets/05-github-app.md) | feat |
| 06 | [The answer comes back to where the user is](tickets/06-relay.md) | feat |
| 07 | [Say what the machine wrote, and what it guessed](tickets/07-docs.md) | docs |
| 08 | [One call, for members, while the quota lasts](tickets/08-ai-enrichment.md) | feat |
| 09 | [Enumerate every path that publishes](tickets/09-enumerate-publishing-paths.md) | chore |

## How it shipped

| PR | Tickets |
|---|---|
| [#919](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/919) | 01, 02 |
| [#920](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/920) | 03, 05 |
| [#922](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/922) | 04 |
| *(this branch)* | 06, 07, 08, 09 |

Split rather than shipped as one, because Sourcery stops reviewing past ~150 000 characters of diff.

**What is left before the service does everything described here:** set
`SUPPORT_BOT_ENRICH_ROLE_ID` to the VEAF role, create the `filed-by-bot` label by hand, and deploy
the Worker (`npx wrangler deploy`) so the bug-hypothesis prompt is live. None of the three blocks
the intake: without them, reports are collected, previewed, filed and followed up — with no
hypothesis and, until the label exists, with `bug` alone.
