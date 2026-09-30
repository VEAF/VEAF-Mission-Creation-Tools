# FEAT-SUPPORT-SUGGESTIONS — an idea, checked against what already exists

Status: ✅ done · archived 2026-09-28

Origin: design session of 2026-09-05, added by David alongside the bug flow: *take suggestions and
improvement comments too, guided*. Lot 5, and the last, of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](FEAT-SUPPORT-DIAGNOSTIC.md).

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

- Reuses everything from [`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md): agent
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
  [ticket 01](FEAT-SUPPORT-SUGGESTIONS.md).
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
| 01 | [Does it already exist? Answer that first](FEAT-SUPPORT-SUGGESTIONS.md) | feat |
| 02 | [`/suggest` files a feature request worth reading](FEAT-SUPPORT-SUGGESTIONS.md) | feat |
| 03 | [Tell people what a suggestion becomes](FEAT-SUPPORT-SUGGESTIONS.md) | docs |

---

## Tickets, in full

## 01 — Does it already exist? Answer that first

Status: ✅ done

Type: feat

### What to build

Before anything is drafted, four sources are consulted and each produces its own answer in the
thread:

| Source | How it is consulted | Verdict it can return |
|---|---|---|
| `doc/` | the documentation assistant is **asked** | it exists and is documented — here is the answer and its pages |
| open issues | text matching, from the bug lot | it is already requested |
| `.backlog/<LOT>/` | text matching, from the bug lot | a lot already covers it, at this status |
| `ROADMAP.md` | text matching, from the bug lot | it is parked, ordered, or explicitly cancelled with its reasons |

None of the four opens an issue on its own, and none of them closes the flow on its own either: a
match is shown with its evidence and the user says whether it is what he meant.

### Why the documentation is asked rather than searched

The original shape of this ticket had the sources swept by text matching, like the bug lot's
duplicate sweep, and the PRD stated the sweep would cost no model call. **Measured on the real tree,
that does not work**, and the measurement is worth keeping:

| word | pages containing it | pages with it in a heading |
|---|---|---|
| `csar` | 24 / 144 (17%) | 6 |
| `combat` | 69 / 144 (48%) | 20 |
| `zone` | 87 / 144 (60%) | 20 |

The words that name a feature are everywhere in the documentation, because the pages cross-reference
each other — which is what makes the documentation good. No threshold separates *the page describing
CSAR* from *the twenty-four pages mentioning CSAR*. Three scorings were written and measured before
this was accepted: plain overlap scored 82% on `add`, `radio` and `way`; rarity weighting still
matched a request for SMS alerts against the support page, on `bot` and `serveur`, at 57%; requiring
the word in a heading changed neither. The bug sweep works because two reports of the same bug share
identifiers a reporter pasted — `veafSpawn.lua`, `KeyError`. A suggestion has none.

*"Does the documentation describe a way to do this?"* is the question `/ask` already answers, from
the same corpus, with its sources and under its quota. So the flow asks it. **Decided 2026-09-06**
with David, against three alternatives: showing leads instead of a verdict, a dedicated model call,
and dropping the documentation source altogether.

### What this costs, and what it changed

One model call per suggestion, on the free Gemini tier measured at 20 requests a day for the whole
Google project — shared with `/ask` and the site. The PRD's "no model call at all" is wrong and is
corrected there.

The **source tree is no longer swept**. A user cannot read Lua to find out whether his idea exists,
so the sources were never an answer *to him*; and matching them was measurably worse than matching
the documentation (a request about rescue helicopters scored 75% against
`v5_pipeline_converters.py`). The useful half of that verdict survives without pretending: when the
documentation is silent, the filed issue carries a line saying so, so a maintainer who knows the
feature exists reads it as the documentation gap it is.

### The failure mode to guard

A wrong *"it already exists"* silences a real idea, and the user will not argue with a bot. So the
answer is always shown **with its pages**, the user can say *that is not what I meant*, and the flow
continues to a real suggestion. What he answers is recorded either way: a rejection of an answer the
documentation actually gave is worth reading later.

*"The documentation could not be consulted"* is a third outcome, distinct from *"the documentation
says nothing"* — the Worker can be down and the quota can be spent. An issue that confuses the two
tells its reader the documentation was checked when it was not.

### Definition of done

- [x] The documentation is asked whether the request already exists, reusing the `/ask` Worker path
- [x] Three verdicts — it exists, it is silent, it could not be asked — each distinguishable
- [x] The answer carries the pages it cited, validated against the real tree so none is invented
- [x] Unit tests: the three verdicts, the absence keyword against prose containing it, and the
      instruction never reaching the retrieval query
- [x] The issues, `.backlog/` and `ROADMAP.md` sweep reused unchanged from the bug lot
- [x] Every match shows its evidence and can be rejected, after which the flow continues
- [x] Quality gate clean

---

## 02 — `/suggest` files a feature request worth reading

Status: ✅ done

Type: feat

### What to build

The command itself, on top of what [ticket 01](FEAT-SUPPORT-SUGGESTIONS.md) established and what the bug
lot already provides.

- `/suggest` opens a public thread, like `/ask` and `/bug`.
- The agent asks for what the template needs and the user rarely volunteers: **the problem behind
  the request**, not only the solution he imagined. `feature_request.yml` asks for problem,
  solution, alternatives and context — the first field is the one that makes a request decidable.
- The draft is shown, the user validates, the issue is filed under the same GitHub App with the
  `enhancement` label, in the user's language.
- The prior-art result is recorded in the issue: what was checked, and what was found. A reader
  three months later should not have to redo the search.

### What it stops short of

No design sketch. The session weighed it and turned it down: a wrong sketch in a public issue
steers the discussion into a wall, durably, and it is expensive to unwind. The agent states the
problem, the request and the prior art. Where it would fit and what it would touch is the work of
whoever opens the lot.

### Reuse, not reinvention

The form, the preview, the GitHub App, the relay and the quotas all come from
[`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md). If any of it has to be rewritten
here, that is a defect in the bug lot's factoring, not a task for this one.

### What reuse actually cost

Two pieces of the bug lot were written against `BugReport` and could not serve a second issue shape
without being copied — which the PRD names as a defect in that lot's factoring rather than work for
this one. Both were factored rather than duplicated:

- the **exchange protocol** every flow needs from Discord moved to `exchange.py` as `ThreadExchange`;
- the **filing mechanism** kept one implementation and gained `file_prepared`, the door an
  already-rendered issue comes through. One issue per key however many times it is asked, the
  recovery search when the ledger lost the answer, failures as outcomes — all of it shared. The
  assembly now builds **one** filer for both flows: the ledger is a whole-file rewrite, and two
  writers would lose each other's entries, which on a public tracker is a second issue.

`render_match` moved next to the `Sweep` it renders. 848 tests stayed green across the move.

### What the reviews found, and the one thing left open

Sourcery's weekly budget was spent when this lot was written, so it was reviewed by agents before
the PR was opened, then by Sourcery once the lot was split under the 150 000-character limit. Eleven
defects, all fixed here — among them three that would have shipped green:

- **three timed waits do not fit in one interaction token.** 300 + 300 + 480 against the 900 seconds
  a deferred token lives. Somebody could click *File the issue* on a dead token, having consented to
  something that never happens. The checks now give way, never the consent;
- **the no-filer path sent Discord 2040 characters**, measured, where it accepts 2000. The refusal is
  swallowed, so the asker kept an ephemeral placeholder for ever after filling five fields;
- **`/suggest` was published where it could never file anything.** Everything published goes through
  a redactor bound to the checkout, so without one nothing can be filed — and the command blamed a
  GitHub App that was correctly configured;
- **a suggestion could be told to update its version.** The flow reused the bug sweeper whole,
  closed issues included, so a feature request scoring against a recently closed issue was answered
  *this may already be fixed, update*;
- **two of my own tests were green for the wrong reason** — one sweep that matched nothing (the
  default *cancel* ended the flow), and one `assertIs(None, None)` guarding the very hazard the lot
  was designed around.

**Left open, deliberately: `ThreadExchange.confirm` is a boolean where three states exist.** *He
said no*, *he said nothing*, and *Discord refused to show him the question* all arrive as `False`.
The issue body no longer claims he disagreed — it says the request was maintained, which is true in
all three — but a tri-state would let it say which. It touches the bug flow too, so it is a lot of
its own rather than a change smuggled into this one.

### Definition of done

- [x] `/suggest` registered, answering in a public thread
- [x] The exchange elicits the underlying problem, not only the proposed solution
- [x] Draft, consent and publication reusing the bug lot's components unchanged
- [x] Issue filed with `enhancement`, in the template's shape, in the user's language
- [x] Prior-art findings recorded in the issue body
- [x] No design sketch produced
- [x] Unit tests: full flow, a suggestion resolved by prior art, a rejected match continuing
- [x] Quality gate clean

---

## 03 — Tell people what a suggestion becomes

Status: ✅ done

Type: docs

### What to write

**For users**, on the support page: `/suggest` exists, it first checks whether the thing already
exists, and an issue is only opened when it does not. Say plainly what happens next — an issue is a
report, not a commitment; `CONTRIBUTING.md` already states that an issue has exactly two futures,
picked up in a lot or left open as a report. Someone whose idea sits open for a year should have
read that beforehand.

**For maintainers**: how to tell a machine-filed suggestion from a hand-written one, and what the
prior-art section of the body means.

### The expectation to set

The honest framing is the one the session settled on: David alone decides, so a suggestion is
recorded, not queued. Saying it up front costs nothing and prevents the silent-tracker
disappointment that kills contribution.

### Open question to close here

Whether machine-filed suggestions carry a distinct label so they can be swept later — open question
1 of the PRD. Whatever is decided goes in this page, so the vocabulary is documented where triage
happens.

### Notes

- Both languages in lockstep, in the `nav` with their `nav_translations` entry.
- Explicit English anchors on cross-linked sections.

### The label decision

**No distinct label** (decided 2026-09-06 with David). `enhancement` + `filed-by-bot` already
isolates machine-filed suggestions exactly, and a third term would be vocabulary to maintain for a
filter anyone can write. Recorded in `docs/agents/triage-labels.md`, where triage happens.

### Definition of done

- [x] User-facing section on the support page, both languages
- [x] The "an issue is a report, not a commitment" expectation stated
- [x] Maintainer note on reading a machine-filed suggestion
- [x] The label decision recorded, and reflected in `docs/agents/triage-labels.md`
- [x] `poetry run docs-check` passes

---
