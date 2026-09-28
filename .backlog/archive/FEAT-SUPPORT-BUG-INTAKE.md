# FEAT-SUPPORT-BUG-INTAKE — from "it does not work" to an issue somebody can act on

Status: ✅ done · archived 2026-09-28

Origin: design session of 2026-09-05, **redesigned the same day** once the free-tier quota was
measured. Lot 4 of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](FEAT-SUPPORT-DIAGNOSTIC.md), and the only one that writes to a
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

1. ~~**Which Discord role** gates the enrichment~~ — settled 2026-09-06: the **mission maker** role
   of the VEAF Discord. Not the broader "member" role, and the reason is what the hypothesis
   contains: it names a file and a line of the repository, which is useful to somebody who will go
   and look, and noise to somebody who reported a crash and wants it fixed. The id lives in
   `SUPPORT_BOT_ENRICH_ROLE_ID`, never in the repository.
2. ~~**How the checkout stays fresh**~~ — settled in ticket 01: a periodic refresh with a bounded
   interval, reported on the issue as the revision every location was resolved against.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A form, and everything it becomes without a model](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 02 | [Attachments become bounded, redacted material](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 03 | [Nothing gets reported twice](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 04 | [The preview, and the click that files it](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 05 | [The issue is filed by a GitHub App, not by a person](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 06 | [The answer comes back to where the user is](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 07 | [Say what the machine wrote, and what it guessed](FEAT-SUPPORT-BUG-INTAKE.md) | docs |
| 08 | [One call, for members, while the quota lasts](FEAT-SUPPORT-BUG-INTAKE.md) | feat |
| 09 | [Enumerate every path that publishes](FEAT-SUPPORT-BUG-INTAKE.md) | chore |

## How it shipped

| PR | Tickets |
|---|---|
| [#919](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/919) | 01, 02 |
| [#920](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/920) | 03, 05 |
| [#922](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/922) | 04 |
| [#923](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/923) | 06, 07, 08, 09 |

Split rather than shipped as one, because Sourcery stops reviewing past ~150 000 characters of diff.

**What is left before the service does everything described here:** the Worker was deployed and the
`filed-by-bot` label created on 2026-09-06. The last step is setting `SUPPORT_BOT_ENRICH_ROLE_ID`
to the mission maker role and restarting the service — until then reports are collected, previewed,
filed and followed up, with no hypothesis section at all.

---

## Tickets, in full

## 01 — A form, and everything it becomes without a model

Status: ✅ done

Type: feat

### What to build

`/bug` opens a **Discord modal** — a box with fields — rather than starting a conversation. It asks
for what `.github/ISSUE_TEMPLATE/bug_report.yml` needs and nothing more: what happened, what was
expected, the steps. Version and component are not asked: they come from the `doctor` block the user
pastes, or they are reported as missing.

Then the service turns that into a filed issue **using no model at all**:

| From | Extract |
|---|---|
| the `doctor` block | tool version, DCS version, OS, paths, recent errors — already parsed by `veaf_libs/diagnostics.py` |
| a stack trace in the text or the log | the `file:line` it names |
| that location, in the checkout | the surrounding lines, and the callers of the function it sits in |
| `rules.json` | which known patterns the log matches, with their verified wording |

None of that is a judgement call. The trace *states* the location; finding callers is a search;
the catalogue is a lookup. Doing it deterministically is not a downgrade from an agent — it is more
exact, it costs no quota, and it works when the quota is gone.

### Why a form and not a conversation

A conversation costs a model call per turn and answers slowly. A modal answers instantly, cannot
drift, and is the same for everyone. The measurement that opened this programme says the missing
pieces in real reports are mechanical facts — versions and steps — not nuance a conversation would
have drawn out.

### Notes

- Discord modals cap the number of fields and their length. Keep to what the template needs; the
  long material arrives as attachments, handled in [ticket 02](FEAT-SUPPORT-BUG-INTAKE.md).
- Everything read here is **data, not instruction**. A log line or a mission field that reads like a
  command must never steer anything downstream — this is a public intake channel, which is exactly
  where such content arrives.
- The checkout must be fresh: a location pointing at a line that moved three releases ago is worse
  than no location. Freshness is open question 2 of the PRD.
- `/ask` gets an escalation button that opens this same modal, pre-filled with the question and the
  answer that did not satisfy.

### Definition of done

- [x] `/bug` opens a modal; submission is acknowledged inside Discord's three-second window
- [x] `doctor` block parsed when present, reported as missing when not — never guessed
- [x] Stack trace located to `file:line`, neighbourhood and callers extracted from the checkout
- [x] `rules.json` matches rendered with their own wording
- [x] Checkout freshness mechanism implemented and documented
- [x] Injected instructions in user text or file content steer nothing — asserted by a test carrying
      a hostile fixture
- [x] Unit tests: a full report, a report with no trace, a trace pointing at a file that no longer
      exists, an empty field
- [x] Quality gate clean

---

## 02 — Attachments become bounded, redacted material

Status: ✅ done

Type: feat

### The problem

The reports worth having come with files: #215 carried a `dcs.log`, two `~mis*.zip` and the full
mission. That is what makes a bug reproducible. But a raw `dcs.log` is measured at **11.1 MB** on
David's machine, and a `.miz` is a binary archive — neither can be handed to a model, and neither
can be left as a Discord link, since those URLs are signed and expire.

### What to build

- **Download** the attachments of the thread, with a size ceiling and an accepted-type list.
- **Filter the log** with the rules that already exist rather than new ones:
  [`veaf_logs/rules.json`](../../src/python/veaf-tools/veaf_logs/rules.json) and the *Diagnostic*
  profile. The excerpt builder from
  [`FEAT-SUPPORT-LOG-ANALYSIS` ticket 01](FEAT-SUPPORT-LOG-ANALYSIS.md)
  is the same job on the same material — share it, do not fork it.
- **Summarise a mission** through the existing `.miz` export to JSON/YAML rather than by reading
  bytes: modules enabled, zones, groups, versions. A structured summary is both cheaper and more
  useful than a binary blob.
- **Redact** everything before it goes anywhere: user paths, addresses, tokens, session identifiers.
- **Re-upload** the files to the issue itself, so the report survives the expiry of Discord's links.
  What is attached to the issue is the redacted material, and the ticket records what was stripped.

### Notes

- A `.miz` can carry mission passwords and module settings. Summarising through the export path
  makes it possible to decide field by field what is published; dumping the archive does not.
- An attachment that is too large, of an unexpected type, or unreadable is reported to the user as
  such — the flow continues without it rather than failing.
- Everything read here is **data, not instruction**, per [ticket 01](FEAT-SUPPORT-BUG-INTAKE.md).

### Definition of done

- [x] Download with size ceiling and type allow-list
- [x] Log filtering reusing the shared excerpt builder, not a second implementation
- [x] Mission summarised through the existing export, with the published field set decided explicitly
- [x] Redaction applied to every artefact before it leaves the service
- [x] Downloaded to local storage, so nothing downstream depends on a Discord URL surviving —
      the upload itself belongs to the GitHub App of [ticket 05](FEAT-SUPPORT-BUG-INTAKE.md), which receives
      the prepared files on `BugReport.attachments`
- [x] Oversized, unknown and corrupt attachments each handled without aborting the flow
- [x] Unit tests on a large synthetic log, a real-shaped `.miz`, and each rejection path
- [x] Quality gate clean

---

## 03 — Nothing gets reported twice

Status: ✅ done

Type: feat

### Why it is cheap here

The corpus is tiny: **9 open issues** in total, and `.backlog/` is already in the service's checkout.
Sweeping the existing work costs almost nothing, which is why this is not an optional refinement.

### What to build

Before the preview is rendered, the service looks at four places — all of it text matching, no model involved:

| Source | Answers |
|---|---|
| Open issues | is this already reported? |
| Recently closed issues | was this fixed in a version the user does not have? |
| `.backlog/<LOT>/` | is a lot already working on it? |
| `ROADMAP.md` | is it deliberately parked or cancelled? |

`CONTRIBUTING.md` is explicit that issues are an intake desk and the real work lives in lots, so
issues alone would miss most of the answer.

### What it does with the answer

- **Already reported**: comment on the existing issue with the new observation instead of opening a
  second one, and tell the user in the thread which issue it is.
- **Already fixed**: answer in the thread with the version that fixed it, and open nothing. This is
  the most valuable outcome — the user is unblocked immediately.
- **A lot is on it**: say so, with the lot, and open nothing.
- **Nothing found**: proceed, and record in the draft what was checked, so the reader knows the
  sweep happened.

### The failure mode to guard

A wrong "this is a duplicate" silences a real bug, and the user will not insist. So a match is
proposed with its evidence, and the user can say *no, mine is different* and continue — the sweep
informs the decision, it does not take it.

### Definition of done

- [x] Sweep across open issues, closed issues, `.backlog/` and `ROADMAP.md`
- [x] Each outcome implemented: duplicate, already fixed, lot in progress, nothing found
- [x] A proposed match always shows its evidence and can be rejected by the user, who then continues
- [x] What was checked is recorded in the draft
- [x] Unit tests with the GitHub API mocked and a fixture backlog, one per outcome, including the
      rejection path
- [x] Quality gate clean

### What was built

`veaf_support_bot/priorart.py`. The corpus is four kinds of candidate; the score weights *signal*
tokens — identifiers, file names, versions, anything that is not everyday vocabulary — three times
an ordinary word, and a proposal needs either a shared signal token or five shared ordinary ones.
The algorithm is deliberately legible: the score is printed with the words it was computed from, so
a maintainer who thinks it is wrong can see why it is wrong. A similarity model would score better
and explain nothing — and would cost a call this lot does not have.

The version that carries a fix is a **lookup, not a guess**: the changelog cites issues as
`[#123](FEAT-SUPPORT-BUG-INTAKE.md)`, so the version is the nearest `## [x.y.z]` heading above the citation. An
issue the changelog does not mention yields no version and the message says so.

Only **open** lots are candidates. Proposing a `✅ done` lot would tell a reporter his bug is being
worked on when it shipped months ago — the same silencing failure as a wrong duplicate.

### Two decisions worth revisiting

1. **With nobody to ask, the gate answers "rejected".** Ticket 04 owns the click that asks; until it
   exists the sweep runs, the finding is printed with its evidence and attached to the issue, and
   the report is filed. The alternative — auto-accepting a high-confidence match — would silence
   reports on a machine's unverified conclusion, which is exactly what this ticket forbids.
2. **The attached log is not part of the query.** A log shares hundreds of words with every other
   log; including it would match a report against everything and teach reporters to dismiss the
   proposal. The query is the reporter's own words plus what the trace named.

---

## 04 — The preview, and the click that files it

Status: ✅ done

Type: feat

### What to build

The service shows the issue exactly as it will be filed, and waits for the user to click.

The preview is entirely **facts**: what he typed in the form, the `doctor` block, the redacted log
excerpt, the located `file:line` with its neighbourhood, the mission summary, and what the prior-art
sweep checked. No hypothesis appears here — the enrichment of
[ticket 08](FEAT-SUPPORT-BUG-INTAKE.md) runs *after* the issue exists, and lands on it as a labelled
addition.

That ordering is the point: a quota that has run out, or a reporter without the role, can never cost
a report. The issue is filed either way.

### Why the user clicks

The issue is filed by a machine account, so the text carries his report without carrying his name —
he should see what is written on his behalf. And most of the preview is material he never wrote: the
log excerpt, the extracted code, the environment. He typed three fields; twenty lines get published.
The click is where he can see the difference and say *not that*.

What it does **not** do is filter noise: someone reporting a non-bug in good faith will click just
as readily. That is accepted; the prior-art sweep and the labelled hypothesis are what keep the
tracker honest, not the consent step.

### Mechanics

- The draft is rendered in the thread, within Discord's message limits, with the long parts folded
  or truncated **visibly** — never silently cut.
- File, edit and cancel. Edit reopens the modal with his answers in place and regenerates the
  preview.
- A draft nobody acts on expires, and says so when it does. An abandoned draft must not turn into an
  issue days later.
- The escalation button on `/ask` lands on the modal of [ticket 01](FEAT-SUPPORT-BUG-INTAKE.md),
  pre-filled with the question and the unsatisfying answer; the preview then behaves as usual.

### Definition of done

- [x] Preview rendered in the thread, carrying facts only
- [x] File / edit / cancel, with edit reopening the modal and regenerating the preview
- [x] Truncation always visible; nothing silently dropped
- [x] Preview expiry, announced
- [x] `/ask` escalation carries question and unsatisfying answer into the modal
- [x] Unit tests: each control, expiry, an over-long draft, the escalation path
- [x] Quality gate clean

### What was built

`veaf_support_bot/draft.py` holds the draft and the two bounds; the buttons live in
`discord_bot.py`, and the intake never draws one.

**The preview is the issue, not a rendering of it.** `IssueFiler.draft_of` calls the same
`render_body` the filing path calls, with the same arguments, so a preview that drifts from what
gets published is a test failure rather than a surprise on a public tracker. The one thing a second
renderer could never prove is that the issue says what the preview said.

**The question moved onto the exchange.** `decide` and `confirm` are now part of `BugExchange`
rather than objects built at start-up, because the buttons hang off *this* reporter's own message —
there is no reporter to ask when the service boots. That is also what finally answers ticket 03's
open point: `PriorArtGate.run` takes the confirmation as an argument, the gate's own field is gone,
and the proposal is genuinely put to the reporter with its evidence instead of always answering
*rejected*.

**Two things publish, and both wait for the click.** The ticket names the issue; the flow also
writes a *comment* when the reporter accepts a duplicate, carrying the same material onto the same
public tracker. Recognising an issue as his is not the same act as agreeing to publish twenty lines
under it, so the comment is previewed and confirmed exactly like the issue, under its own heading.

**Every failure leans the same way.** A silence expires, a Discord error cancels, an answer nobody
wrote a case for is treated as a refusal — the only path that reaches GitHub is a press of *File the
issue*. The two waits are five and eight minutes against Discord's fifteen-minute interaction token,
so the expiry can still be announced on the message it happened to; a timeout the service could no
longer write to would leave the reporter on a preview that never resolves.

**Truncation states its counts.** `fold` cuts on a line boundary, closes a fenced block it ran
through, and returns what it dropped so the notice can name it — the long parts are exactly the ones
the reporter did not write, so a silent cut would misrepresent the part that matters most.

### What ticket 06 still has to pick up

The escalation button carries the `/ask` exchange into the form but **not** the thread it came from:
`BugSubmission.thread_url` is still empty, so the issue says the thread was not recorded. Ticket 06
owns that link, and it is the same link the relay needs.

---

## 05 — The issue is filed by a GitHub App, not by a person

Status: ✅ done

Type: feat

### What to build

A dedicated GitHub App as the bot's identity: rights scoped to this repository and to what it
actually needs, short-lived tokens renewed automatically, revocable in one click, and issues that
appear signed by the bot without impersonating anybody.

The alternatives were weighed and rejected. A personal access token means a long-lived credential
sitting on the host with broader rights than needed, whose leak goes unnoticed. Reusing an existing
token means it can no longer be revoked without breaking something else, and the bot's actions
become indistinguishable from David's.

### What the issue looks like

- Written **in the user's language**. This departs from the repository's English-only rule for
  technical content, and matches what the tracker actually contains — the regulars report in French.
  Quoted material — log lines, error messages, zone names — is never translated.
- Shaped like `.github/ISSUE_TEMPLATE/bug_report.yml`: version, component, what happened, expected,
  steps, context. The form has never been used by a human in 60 issues; the machine can fill it
  every time.
- Labelled `bug`, plus a triage label marking it as machine-filed, so these are findable and
  countable later.
- Attribution to the Discord author, and a link back to the thread — the two halves of
  [ticket 06](FEAT-SUPPORT-BUG-INTAKE.md)'s bookkeeping.

### Notes

- The App's credentials live in the environment, never in the repository.
- Creation is idempotent per draft: a double click, a retry after a timeout, or a restart mid-flight
  must not produce two issues.
- A failure to create is reported in the thread with what to do, not swallowed.

### Definition of done

- [x] GitHub App used, with least-privilege scopes documented
- [x] Credentials from the environment only; renewal handled
- [x] Issue filled in the template's shape, in the user's language, quotes untranslated
- [x] Labelled `bug` plus a machine-filed marker
- [x] Discord author and thread link recorded on the issue
- [x] Creation idempotent across double click, retry and restart — asserted by tests
- [x] Creation failure surfaced to the user
- [x] Quality gate clean

### The permissions to grant, exactly

Installed on `VEAF/VEAF-Mission-Creation-Tools` **only**, webhook **inactive**, **no** events.

| Scope | Permission | Level |
|---|---|---|
| Repository | **Issues** | **Read and write** |
| Repository | **Metadata** | **Read-only** *(mandatory, selected by GitHub)* |
| Repository | everything else | **No access** |
| Organisation | everything | **No access** |
| Account | everything | **No access** |

`Contents` is deliberately **not** granted: the prior-art sweep reads `.backlog/` and `ROADMAP.md`
from the local checkout, never through the API, so the App never needs to read the code.

### What the ticket asked for and the platform does not allow

**Re-uploading the attachments to the issue.** GitHub has **no REST endpoint that attaches a file to
an issue** — the one the web interface uses is a session endpoint no App can call. The two
API-reachable substitutes (committing the file to the repository, publishing it as a release asset)
both need `Contents: write` on a **public** repository and would permanently publish a stranger's
`dcs.log` into it. Neither was built.

What was built instead: a **text** attachment small enough is carried *whole, inside the issue*, as
a comment — it lives as long as the issue does and is a link to nothing. Everything else is listed
with its name, its size and its SHA-256, and the issue says plainly that the bytes were not
published; the bounded excerpt and the mission's shape are in the body either way. **No Discord URL
is ever written into an issue.**

If David wants the raw files to survive, the options are: a dedicated branch written through
`Contents: write` (permanent, public, and a much broader permission), or asking the reporter for the
file through the ticket 06 relay when a maintainer actually needs it.

### The other thing to decide

The bot **does not create labels**. If `filed-by-bot` does not exist in the repository, the issue is
filed with `bug` alone and the reporter is told the label could not be applied. Letting a machine
invent taxonomy in a public tracker looked like a maintainer's decision rather than the bot's — the
label has to be created by hand, once.

---

## 06 — The answer comes back to where the user is

Status: ✅ done

Type: feat

### The debt this pays

Filing under a machine account means the reporter is subscribed to nothing. A maintainer asking
*"can you attach your `dcs.log`?"* on the issue is talking to an empty room, and the user never
learns his bug was even looked at. This is where integrations of this kind normally die: the report
travels fine, and then nobody speaks to anybody.

### What to build

- A durable link between a Discord thread and the issue it produced, surviving a restart.
- A listener for activity on those issues — new comments, labels that matter, closure — reposting
  into the originating thread, in a form a non-developer reads: who said what, and what it means for
  him.
- A tag on the thread when the issue closes, so the state is visible without opening anything.

### The direction not built

Discord → GitHub is deliberately left out. Letting a thread write comments onto a public repository
opens a write channel from a room anyone can join. If it is ever wanted, it needs its own decision
and its own guards; it is not a natural extension of this ticket.

The consequence is worth stating in the documentation: to add something to his report, the user
posts in the thread, and a maintainer carries it over. That is a manual step, and it is the accepted
cost.

### Notes

- Relaying every event turns a thread into noise. Relay what the reporter can act on or wants to
  know; ignore the rest.
- A deleted thread, an archived thread, or a user who left must not break the relay or crash the
  service.
- Bot comments must not feed back into the relay.

### Definition of done

- [x] Durable thread ↔ issue association, surviving restart
- [x] Comments and closure relayed into the originating thread, in plain language
- [x] Thread marked when the issue closes
- [x] Deleted, archived and orphaned threads handled without failure
- [x] No relay loop on the bot's own activity
- [x] Unit tests: relay of a comment, of a closure, and each degraded case
- [x] Quality gate clean

### What was built

`veaf_support_bot/relay.py`: the link store, the watcher, and the round. The Discord half is
`ClientThreadPoster`; the loop is a background task of the service.

**The thread is opened after the click and before the filing.** After, because an abandoned draft
must not leave a public thread about a report nobody filed. Before, because the issue carries the
thread's address in its body, and rewriting an issue afterwards is a second write that can fail on
its own. That also fills the `thread_url` ticket 04 left empty.

**Polling, as decided.** The App has no webhook and no events, so a webhook would have cost a public
route, a shared secret and a signature check for latency nobody is waiting on. One pair of calls per
followed issue every ten minutes sits far inside the 5000/hour an installation gets.

**The cursor is a comment id, never a timestamp.** Two comments in the same second would race, and
the symptom would be "the reporter missed the one answer that mattered". A transient failure moves
no cursor: `since` answers `None` rather than an empty state, so nothing is marked as seen.

**The anti-loop filter sits at the delivery step, not at the read.** It was written in the watcher
first, and the test that injects a state directly showed what that meant: any other producer of an
`IssueState` would have been free to feed the loop. Moved to `_deliver`, where the posting happens.

**One bad thread never ends the round.** A rate limit is retried; only a definitive *this thread no
longer exists* drops a link. A restart finds an empty Discord cache — the bot runs on
`Intents.none()` — so the poster **fetches** a thread it cannot see, which is what keeps the relay
alive across a redeploy.

### A bug this ticket found in passing

`extra={"thread": ...}` on a log line **raises** `KeyError`: `LogRecord` already owns that field.
It passed the relay's own tests, where no handler builds a record, and failed the moment the whole
suite ran with logging configured — which is to say it would have failed in production, on the line
reporting that a report had started being followed. Fixed, and `tests/test_log_fields.py` now walks
the package's syntax tree and fails on **any** `extra=` key that collides with a record field, so
the family is closed rather than this one member.

---

## 07 — Say what the machine wrote, and what it guessed

Status: ✅ done

Type: docs

### What to write

**For users**, on the support page: what `/bug` does, that files are read and filtered, that personal
data is stripped before publication, that nothing is filed before they click, that the issue is filed
by a bot on their behalf, and that answers come back into the thread. Say plainly that the **automatic
hypothesis is a members' extra** and that its absence takes nothing away from the report — otherwise
its absence reads as a failure. Also the manual
step: to add something later, post in the thread.

**For maintainers**, next to the service: how to read a machine-filed issue — which parts are
measured and which part is a guess — how the prior-art sweep decided what it decided, which Discord
role gates the enrichment, and how to switch the enrichment off entirely without touching the intake.

**In `CONTRIBUTING.md`**: the intake circuit gains a path. Today it says to pick a template; it
should also say that a report can arrive through Discord and what that changes for triage.

### The line to hold

An automatic hypothesis is a hypothesis. The documentation says so plainly, so nobody three months
later reads a machine guess as a diagnosis and closes a real bug on it. That is the risk the whole
labelling scheme exists to contain, and documentation is half of it.

### Notes

- Both languages in lockstep, in the `nav` with their `nav_translations` entry.
- Explicit English anchors on cross-linked sections.
- `poetry run docs-check` is the gate.

### Definition of done

- [x] User-facing section on the support page, both languages, covering the privacy and consent
      steps explicitly
- [x] Maintainer documentation next to the service, including how to switch the paid flow off
- [x] `CONTRIBUTING.md` intake section updated
- [x] The "hypothesis is a guess" line stated in both the user and maintainer documents
- [x] `poetry run docs-check` passes

### What was written

**For users** — `doc/SUPPORT.md` and `.en.md` gain a `/bug` section under an explicit `{#bug}`
anchor: what the form asks, what the bot makes of it *without any AI*, that nothing is published
before the click, that personal data is stripped and that a filter which cannot run publishes
nothing. It also states the one thing the filter does not catch — **what the reporter types
himself**, including his own name in a field or in a mission's file name — because a promise of
privacy that quietly has a hole is worse than no promise.

The stale paragraph went with it: the `/ask` page said the bot could not open an issue. It now
points at the escalation button.

**For maintainers** — the service's `README.md` grew alongside each ticket rather than in one pass
at the end: how the click works, how to read a machine-filed issue, which role gates the hypothesis
and how to switch it off (leave `SUPPORT_BOT_ENRICH_ROLE_ID` empty), how the relay polls and what it
does not do.

**In `CONTRIBUTING.md`** — the intake desk now has two doors, and a section on triaging an issue a
bot filed: the body is measured, the ⚠️ comment is a guess, **the reporter is on Discord** and is
reached by answering on the issue, and the attachments are described rather than attached.

### The line held

"The hypothesis is a guess" is stated in four places — the issue's own comment, the sentence the
reporter reads, the user documentation and the maintainer documentation. That is deliberate
repetition: the risk it contains is somebody three months from now reading a machine's guess as a
diagnosis and closing a real bug on it.

---

## 08 — One call, for members, while the quota lasts

Status: ✅ done

Type: feat

### What to build

The issue is already filed by the time this runs ([ticket 04](FEAT-SUPPORT-BUG-INTAKE.md)). This adds
**one** model call that reads the prepared context and returns a hypothesis, which is posted as a
clearly labelled comment or section on that issue.

Three gates, all cheap, all checked before the call:

1. **A VEAF role**, read from the Discord interaction itself. It cannot be forged and costs nothing.
2. **The daily ceiling**: 15 enrichments, against a measured free tier of 20 requests per day.
3. **One call per report**, enforced by the runtime rather than requested of the model.

### Why one call is enough

Everything an agent would have gone looking for is already in hand: the location, the surrounding
code, the callers, the catalogue matches, the prior art, the mission summary. The model is asked to
**conclude on a prepared file**, not to investigate. That is what turns ten to twenty calls into
one, and it is the whole reason the free tier is workable.

If one call proves insufficient, the answer is a better prepared context — more callers, a wider
neighbourhood, the matching rule's wording — not a second call.

### Failing without failing

Not a member, ceiling reached, model unavailable, malformed answer: in every case the issue stands
as filed and **says the hypothesis is absent**, with the reason in one plain sentence. The reporter
is never told his report failed, because it did not.

### The hypothesis, and how it is presented

Labelled as a machine guess, at block level — not a disclaimer at the bottom, which nobody reads.
It carries the suspected file and line and why. It is never phrased as a diagnosis, and it must be
possible for a maintainer three months later to tell in one glance what was measured from what was
guessed.

### Notes

- The daily counter shares its implementation with
  [`FEAT-SUPPORT-DISCORD-QA` ticket 03](FEAT-SUPPORT-DISCORD-QA.md),
  with a much lower ceiling. Fail closed: a counter that cannot be read means no enrichment, never
  unlimited enrichment.
- Consumption is recorded per report so the ceiling can be revisited from figures.
- Which role gates this is open question 1 of the PRD; the code reads a role id from the environment
  rather than a name.

### Definition of done

- [x] One model call per report, enforced by the runtime
- [x] Role check from the interaction, ceiling check, both before the call
- [x] Hypothesis posted labelled, with file and line, visually separable from the facts
- [x] Every refusal path leaves the issue intact and states why the hypothesis is missing
- [x] Counter fails closed
- [x] Consumption recorded
- [x] Unit tests with the model mocked: enriched, non-member, ceiling reached, model unavailable,
      malformed answer
- [x] Quality gate clean

### What was built

`veaf_support_bot/enrichment.py` holds the three gates and the single call;
`worker.HypothesisClient` makes it; `issue_body.render_hypothesis` labels it.

**The prepared file is the issue body itself.** Nothing new had to be assembled: the location, the
surrounding code, the callers, the catalogue matches, the prior art and the mission's shape are
already in it, in that order. That is what turns ten calls into one — the model is handed a finished
file and asked to conclude on it.

**The prompt lives in the Worker, not here.** `kind: "bug"` on the existing `/analyze` route selects
`bugHypothesisInstruction`, next to the log-analysis one. What a machine is allowed to claim on a
public tracker is then written down in a single place, and adding a caller does not add a dialect of
it. The route needed no new permission: the `discord` client mode already reaches `/analyze`.
**Consequence: the Worker is deployed by hand, so the instruction is live only once
`npx wrangler deploy` has run.**

**The role is read from `Member._roles`, not from `Member.roles`.** The public property resolves
each id against the guild cache and silently drops what it cannot find — and this bot runs on
`Intents.none()`, so that cache can be empty. Reading the property alone would have refused every
reporter forever while looking perfectly healthy. `tests/test_discord_consent.py` asserts the raw
payload path, because that is the failure this repository has shipped green before.

**An unset role switches the feature off, and that is the default.** Not a degraded mode: reports
are filed complete, with no hypothesis section at all, and both the issue and the reporter are told
which of the five reasons applies. Open question 1 of the PRD therefore needs no answer before
shipping — it needs one before the feature does anything, and it is one environment variable.

**The allowance fails closed**, unlike `/ask`'s. There, silence looks like a broken bot; here it
costs one paragraph on an issue that is already filed, and the resource is shared with the
documentation site and the command line.

### Still open

`SUPPORT_BOT_ENRICH_ROLE_ID` is unset, so nothing is enriched yet — David's call on which role, and
where the service reads its environment.

---

## 09 — Enumerate every path that publishes, instead of testing a few

Status: ✅ done

Type: chore

### Why this exists

Four leaks of personal data reached review across three PRs of this lot, and every one of them took
a path the hostile fixture did not carry:

| PR | The path | What escaped |
|---|---|---|
| #919 | archive member listing | `C:/Users/Firstname Lastname/…` from a `~mis*.zip` |
| #919 | a parser's error message | a fragment of the `.miz`, briefing prose one offset away |
| #919 | the attachment's filename | the reporter's own name |
| #920 | the attachment's **bytes**, carried into a comment | account name and e-mail address, verbatim |
| #920 | the reason published when redaction fails | the host's checkout path — the server's topography |

Each time the module header promised to *"redact every text artefact"*. Each time one caller did
not. And each fix added one more case to the fixture — which is testing the leaks we already found,
not the ones we have not.

This is the repository's own lesson, already written down after a different sweep: **enumerate the
family from the code, do not sample it by hand.** Thirteen hand-picked cases once made a whole
family look fixed while three members were still broken.

### What to build

A test that **derives** the list of publishing paths from the code rather than restating it, and
asserts that each one is redacted. Something along the lines of: every call that reaches the GitHub
transport, or every function whose return value ends up in an issue body, a comment or a label —
found by walking the module, not by listing names in the test.

Two properties matter more than the mechanism:

- **It fails when a new path is added without redaction.** That is the whole point; a test that only
  covers today's callers repeats the problem it is meant to end.
- **It says which path is unguarded**, not merely that something is.

The assertion belongs on the content that reaches the **transport**, not on a function's return
value — #920's leak was at an argument of the network call, and a test on the return value would
have passed beside it.

### Notes

- `attachments.py`, `issue_body.py`, `filing.py` and `priorart.py` are the modules that publish
  today. The point of the ticket is that this list must not live in the test.
- Fail closed everywhere: redaction unavailable means the content is withheld, never published raw.
  Two paths already do this (`safe_redact`, `_publishable`); the test should confirm all of them do.
- This is worth doing once the lot's features are in, not in the middle — it is a net, not a feature.

### Definition of done

- [x] A test that derives the publishing paths from the code
- [x] It fails when a path is added without redaction — proved by adding one
- [x] It names the offending path in its failure message
- [x] The assertion sits on what reaches the transport
- [x] Every existing path passes, or is fixed
- [x] Quality gate clean

### What was built, and why it is not only a test

The ticket asked for a net. Writing one made it obvious that the net could not hold on its own: any
test that enumerates *callers* is still a test of the callers we have, and the four leaks were all
callers that believed somebody else had redacted.

So the redaction moved **under** them. `GitHubApp` now redacts every outgoing body — recursively,
strings only, non-strings untouched — on its way to the transport, and refuses to send anything when
redaction cannot run. There is no way to reach GitHub that does not pass through it, which makes the
property structural rather than remembered. Callers keep redacting what they *quote*, for their own
bounds and their own wording; this is the floor under all of them, and applying it twice is
harmless.

`tests/test_publishing_paths.py` then asserts two things, neither of which is a list of names:

1. what reaches the **transport** is redacted — asserted on the bytes handed to it, because #920's
   leak was at an argument of the network call and a test on a return value passes right beside it;
2. **nothing reaches a network any other way** — a syntax walk over the package flags any call
   carrying a body (`json=`/`data=`) outside the two clients, naming the file and the line.

The walk is put on trial: a module that posts to a network is written to a temporary directory and
the same walk must flag it, by name. It is written outside the package on purpose — a test that
leaves a landmine in the shipped tree is worse than the hole it guards.

Two smaller decisions, both from the leaks already found: the refusal message names **no path of its
own** (the reason published when redaction failed leaked the host's checkout path in #920), and a
deployment with no checkout gets a redactor that raises rather than a passthrough.

---
