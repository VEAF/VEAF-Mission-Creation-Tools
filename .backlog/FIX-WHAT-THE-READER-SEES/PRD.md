# FIX-WHAT-THE-READER-SEES — three places the output buries what matters

Status: 🔄 in-progress — the four tickets are done; the PR is open

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
| 01 | [An answer longer than one message becomes several](tickets/01-overflow.md) | fix |
| 02 | [The invitation is written once per thread](tickets/02-invitation-once.md) | fix |
| 03 | [What is missing, and what was kept back, are two lists](tickets/03-missing-versus-withheld.md) | fix |
| 04 | [A proposal from the model shows its evidence](tickets/04-a-proposal-shows-its-evidence.md) | fix |

## Definition of done

- An answer of 3000 characters arrives whole, in two messages, with the footer on the second;
- a code block split across two messages renders as code in both;
- a preposterous answer is still bounded, and says so;
- the invitation appears on a thread's first answer and not on its continuations;
- an attached mission contributes **one** line to the report, not twenty-five, and what is genuinely
  missing is readable at a glance;
- a duplicate proposed by the model shows the title and the link of what it proposes, and a bug
  report is never proposed as a duplicate of a suggestion;
- unit tests per case; quality gate clean.
