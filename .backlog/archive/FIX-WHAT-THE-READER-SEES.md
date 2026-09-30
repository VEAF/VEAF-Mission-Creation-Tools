# FIX-WHAT-THE-READER-SEES — three places the output buries what matters

Status: ✅ done — the five tickets are done; PR #939 merged 2026-09-07 · archived 2026-09-28

Origin: David, 2026-09-07, testing the whole thing on the live Discord within the hour it shipped.
Nothing here is broken; three things are simply unreadable, and two of them are mine from that same
evening.

## 1 & 2 — an answer cut where a second message would do

The continuation worked; the answer to it ended with

> ✂️ Réponse tronquée : elle dépassait ce qu'un message Discord peut porter.

## What is wrong

A Discord message holds 2000 characters and `/ask` renders its answer into **one**. Everything past
that is cut, with a notice — honest, and a waste: the answer lives in a **thread**, where a second
message is the most natural thing in the world.

Measured 2026-09-07, on the deployed service:

| | characters |
|---|---|
| Discord's ceiling | 2000 |
| the caveat, reserved | 131 |
| the sources line, one short link | 16 |
| **the follow-up invitation, added the same evening** | **146** |
| room left for the answer itself | 1702 |

That last line is the aggravating half and it is mine: the invitation shipped hours earlier took 8 %
of the body's room, on the very exchanges — the continuations — that carry the most context and
produce the longest answers.

## What to build

Decided with David (a+b, 2026-09-07):

**a. Overflow into further messages instead of truncating.** The answer is split on line boundaries,
each part within Discord's ceiling, and the footer — sources and caveat — goes on the **last** one.
A fenced code block the split runs through is closed at the end of one part and reopened at the
start of the next, so neither half renders as prose.

A ceiling stays, far higher: past a handful of messages an answer is not an answer any more, and
that case keeps the notice it has today.

**b. The invitation only on the first answer of a thread.** A reader who is *already* continuing a
thread knows he can continue it; repeating the line spends 146 characters where they are scarcest.

## What must not change

- **The caveat and the sources are never what gets cut.** They are reserved before anything else,
  exactly as they are today: an answer that loses its sources loses the only thing that lets a
  reader contradict it.
- **The streaming stays one message.** What is edited while the answer arrives is the first message;
  the extra ones are posted when the whole answer is in hand. A stream that posted messages as it
  went would rate-limit itself and interleave with anything else in the thread.
- **The escalation button stays on the last message**, where the reader's eye ends up.

## 3 — a report whose "what is missing" section is 93 % deliberate

Measured on **issue #938**, the first real `/bug` filed with a mission attached: the section headed
*Ce qui manque, et pourquoi* holds **28 lines, 26 of which are things the service withheld on
purpose** — `descriptionText`, `goals`, `drawings`, `trigrules`, every field of a `.miz` that is
summarised rather than published, plus what the log profile filtered out.

That withholding is the strong guarantee and must stay: a mission is *summarised*, its published
fields chosen one by one, which is what keeps a squadron's briefing off a public tracker. What is
wrong is calling it *missing*, and drowning in it the two lines that really are:

- no `doctor` block was pasted;
- `EventHandlers.lua:13`, named by the trace, is absent from the repository — which is a **finding**,
  and the reader has to scroll past twenty-five lines of deliberate withholding to reach it.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [An answer longer than one message becomes several](FIX-WHAT-THE-READER-SEES.md) | fix |
| 02 | [The invitation is written once per thread](FIX-WHAT-THE-READER-SEES.md) | fix |
| 03 | [What is missing, and what was kept back, are two lists](FIX-WHAT-THE-READER-SEES.md) | fix |
| 04 | [A proposal from the model shows its evidence](FIX-WHAT-THE-READER-SEES.md) | fix |
| 05 | [The bot says *tu*, everywhere](FIX-WHAT-THE-READER-SEES.md) | fix |

## Definition of done

- An answer of 3000 characters arrives whole, in two messages, with the footer on the second;
- a code block split across two messages renders as code in both;
- a preposterous answer is still bounded, and says so;
- the invitation appears on a thread's first answer and not on its continuations;
- an attached mission contributes **one** line to the report, not twenty-five, and what is genuinely
  missing is readable at a glance;
- a duplicate proposed by the model shows the title and the link of what it proposes, and a bug
  report is never proposed as a duplicate of a suggestion;
- no French string addresses the reader as *vous*, and a test says so;
- unit tests per case; quality gate clean.

---

## Tickets, in full

## 01 — An answer longer than one message becomes several

Status: ✅ done

Type: fix

### What to build

`answer.render` produces one string bounded at 2000 characters. It gains a sibling that produces a
**list** of them:

- split on line boundaries, never mid-sentence — a cut inside a line reads as corruption;
- a fenced code block the split runs through is **closed** at the end of one part and **reopened**
  at the start of the next, so neither half is rendered as prose;
- the footer — sources, then the caveat — is appended to the **last** part, and its room is reserved
  there before that part is filled;
- a ceiling on the number of parts. Past it, the last part carries the truncation notice that exists
  today: an answer of fifteen messages is not an answer.

`ask.py` then edits the streaming message with the first part and **posts** the others. The exchange
already switches its editing target on `post`, so the escalation button lands on the last message
with no further change.

### Why the streaming is not touched

While the answer arrives, one message is edited at a bounded rate. Posting parts as they stream
would rate-limit the exchange against itself and interleave with whatever else is written in the
thread. The parts are computed once the whole answer is in hand — which is also the only moment the
*last* part is known, and the footer belongs to it.

### Done when

- 3000 characters arrive whole, in two messages, with sources and caveat on the second;
- a code block split across the boundary renders as code on both sides;
- a preposterous answer is bounded and says so;
- nothing changes for an answer that fits, which is most of them.

---

## 02 — The invitation is written once per thread

Status: ✅ done

Type: fix

### What to build

The line *"Une question complémentaire ? Mentionnez-moi dans ce fil…"* is appended to every answer
the thread carries. It is worth 146 characters, measured, and on a continuation it tells the reader
something he is in the middle of doing.

So: it goes on the answer that **opens** a thread, and not on the answers to follow-ups.

The condition is already in hand — a continuation is exactly an exchange whose context carries a
conversation — so this is a condition, not a new piece of state.

### Done when

- the first answer of a thread invites the reader to continue;
- an answer to a follow-up does not;
- an answer with no thread still promises nothing at all, as before.

---

## 03 — What is missing, and what was kept back, are two lists

Status: ✅ done

Type: fix

### What is wrong

Measured on **issue #938**, the first `/bug` filed with a mission attached. The section headed *Ce
qui manque, et pourquoi* holds 28 lines:

| lines | what they are |
|---|---|
| 25 | fields of the `.miz` the service **chose** not to publish — `descriptionText`, `goals`, `drawings`, `trigrules`, `weather`, `map`… |
| 1 | what the log profile filtered out |
| 1 | no `doctor` block was pasted |
| 1 | `EventHandlers.lua:13`, named by the trace, absent from the repository |

The last two are what the section is *for*. They are at the bottom, after twenty-five lines that say
the service did its job.

Worse, the framing is wrong in a way that matters to a reporter reading his own issue: `.miz` fields
are not *missing*, they are **deliberately withheld** — a mission is summarised, its published
fields chosen one by one, which is what keeps a squadron's briefing and a mission password off a
public tracker. Told as an absence, that protection reads as a failure.

### What to build

Two lists, because they answer two questions.

- **What is missing** — a `doctor` block nobody pasted, a file that could not be read, a location
  the trace named and the checkout does not hold. Things a maintainer may act on.
- **What was deliberately not published** — one line per file, not one per field:
  *`Snowfox_20260903.miz`: summarised, only the fields listed above are published.* The detail of
  which fields is not information a reader wants; that it was summarised, is.

`MaterialNote` carries which of the two it is, and the renderer puts each in its own section, with
its own heading, in both languages. The withheld section is **omitted entirely** when there is
nothing in it, which is the ordinary case for a report with no attachment.

### What must not change

The withholding itself. Not one field more is published than today — this ticket changes how it is
told, and nothing about what is told.

### Done when

- an attached `.miz` contributes **one** line, whatever its field count;
- the two genuine findings of #938 are readable without scrolling;
- the two sections are headed in French and in English;
- a report with nothing withheld shows no withheld section at all;
- tests: a mission's fields collapse to one line, a real absence stays in *what is missing*, and the
  two are never mixed.

---

## 04 — A proposal from the model shows what it is proposing

Status: ✅ done

Type: fix

### What happened, in front of a human

David, 2026-09-07, minutes after ticket 05 of the previous lot shipped. He asked `/suggest` for a UI
in `veaf-tools` resembling the one in ctld-tools, and the bot answered:

> 🔎 **Ta demande ressemble à un ticket déjà ouvert : #938.**

**#938 is his own bug report**, filed five minutes earlier — title *La mission ne fonctionne pas*,
labels `bug`, `filed-by-bot`, `lua`. Nothing to do with a UI.

Two defects, and the second explains the first.

### 1. The proposal carries no evidence

The whole service runs on one rule: **a match is proposed with its evidence, never asserted.** The
deterministic sweep prints the reference, the score and the shared words, precisely because a wrong
"this is a duplicate" silences a real request and the asker will not insist.

The proposal built from the model prints a number. Had the title been on screen — *La mission ne
fonctionne pas* — the answer would have been obvious without opening GitHub.

### 2. Bug reports are offered as candidates

Every open issue travels with the request, bug reports included. A feature request cannot be a
duplicate of a bug report: they are different natures, and the tracker says which is which with the
`bug` label the service itself applies.

Note what is **not** filtered: issues the bot filed. A duplicate may perfectly well be a ticket this
service opened for somebody else; what is filtered is the nature, not the origin.

### What to build

- the proposal shows the issue's **title and URL**, both already in hand — the sweep reads them from
  the same source;
- issues labelled `bug` are not offered to the model at all, which also shortens the prompt;
- the match handed to the rest of the flow carries that title, so the *second voice* comment and the
  log line name the issue rather than a bare number.

### Done when

- a proposal shows title and link, and refusing it still carries the request on;
- a bug report is never proposed as a duplicate of a suggestion;
- tests: the prompt holds no bug report, and the proposal holds the title of what it names.

---

## 05 — The bot says *tu*, everywhere

Status: ✅ done

Type: fix

### What is wrong

French has two ways of addressing somebody, and a service that uses both reads as two services.

Measured 2026-09-07, while the command descriptions of ticket 01 were being written: **29 keys
tutoient, 12 vouvoient** — and the formal ones are the most visible of the lot, because three of
them are the command descriptions themselves, which is the first thing a mission maker sees of this
bot before typing anything.

Nine of the twelve were written that same evening, by the ticket that made the forms speak French at
all. Three are older and slipped through because they carry **no `vous`**: an imperative addressed to
*vous* is formal without the pronoun — *« Corrigez-la dans ce fil »*, *« Mentionnez-moi dans ce
fil »*, *« Reposez la question »*.

### What to build

One register: **tu**. It is a squadron's Discord, not a bank, and the rest of the catalogue already
speaks that way — *« Tu as atteint ta limite »*, *« Ta demande ressemble à un ticket déjà ouvert »*.

And a test, because a rule nobody can check is a rule nobody follows. It catches both forms: the
pronoun, and the `-ez` imperative at the head of a clause — anchored on a clause boundary so `assez`
and `chez` are not read as commands. It also asserts it **can still fail**, on a sentence carrying
each form, since a pattern narrowed until it matches nothing lets the next one straight through.

### Done when

- no French string addresses the reader as *vous*, by pronoun or by imperative;
- the test states the rule, and proves it can fail;
- the module header says which register this catalogue uses, so the next string written follows it.

---
