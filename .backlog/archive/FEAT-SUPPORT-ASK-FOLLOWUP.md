# FEAT-SUPPORT-ASK-FOLLOWUP — the thread answers back

Status: ✅ done — merged in #931 · archived 2026-09-28

Origin: David, 2026-09-07, hours after the bot went up on the Docker host. *"Après `/ask` ça ouvre un
fil, mais quand on répond dans le fil ça ne repart pas au bot… c'est dommage."* His own shape for the
fix, and it is the right one: **mention the bot** — `@VEAF Tools Bot et si je veux créer une mission ?
on a des modèles ?` — so the bot never sees the messages that are not for it.

## Why a mention, and not every message in the thread

Because Discord enforces it for us. The `MESSAGE_CONTENT` intent is privileged, and this service asks
for **none**: `INTENTS = discord.Intents.none()`, on the stated ground that it reads slash-command
options and never message content. Two documented exceptions survive without that intent — content
in DMs with the app, and **content in which the app is mentioned**.

So the design David asked for is the one that needs no privilege: the gateway hands us the text of a
message that mentions the bot, and hands us an empty `content` for every other message in the room.
*The bot cannot read what is not addressed to it* stops being a promise the code keeps and becomes a
property of the connection. Listening at all needs `guild_messages`, which is **not** privileged:
nothing to enable in the developer portal, no review, no delay.

## What is already there, and what is missing

The transport already holds a conversation. `WorkerClient.body()` takes `messages: Sequence[Mapping]`
and the Worker builds Gemini `contents` from the whole list, trimmed to `MAX_HISTORY = 12` turns —
that is how the documentation widget on the site works. What `/ask` does today is send a
**three-turn** conversation built by `answer.protocol_turns()`: the protocol instruction, its
acknowledgement, and the question.

Missing, and only this:

1. **an ear** — no `on_message` handler, and `Intents.none()` would not deliver one;
2. **a memory** — nothing records that thread *T* was opened by question *Q* and answered *A*;
3. **a retrieval query that survives an ellipsis** — see below, it is the one real quality risk.

## The ellipsis, which is the part that can quietly be bad

The Worker picks the documentation passages from the **last user turn only** (`latestQuery`, then the
embedding of that text). David's own example is the demonstration: *"et si je veux créer une mission ?
on a des modèles ?"* retrieves against a phrase that names neither the tools nor the subject of the
thread. The model would hold the context and answer over the wrong pages — the failure that reads as
*the bot got worse* rather than as *retrieval missed*.

Decided (David, a1/b1/c1, 2026-09-07): **the retrieval query is built by joining the thread's opening
question to the follow-up**, the follow-up last and verbatim, at no extra cost and with no extra model
call. Measured while building it: the Worker uses that **same** turn for retrieval and for the model,
so separating the two would mean a new field on `/chat` and a Worker deployment. Joining them costs
one string, and the model reads that turn as what it is — *here is what I asked, here is what I am
asking now* — with the real exchange in the turns before it.

## Decisions taken with David, 2026-09-07

| # | Decision | Rejected, and why it matters |
|---|---|---|
| a1 | The bot answers a mention **only inside a thread it opened itself** | Answering mentions anywhere turns it into a channel assistant, and every mention spends the allowance shared with the site and the CLI |
| b1 | The thread ↔ conversation record lives in a **file on the `state` volume** | In memory only, a `docker compose up -d --build` silently ends every running conversation — a failure nobody sees until they live it |
| c1 | Retrieval joins the **opening question** to the follow-up | Leaving the ellipsis alone answers well over the wrong pages |

## Constraints

- **A follow-up is a question.** It goes through `QuotaKeeper` exactly like `/ask`: the per-user
  window, the per-user day, the whole-bot day. No second budget, no exemption.
- **Nothing new is trusted.** A mention's text is user input, like the slash command's option: data,
  never a code path, and it reaches the model as a plain turn.
- **No ping, ever.** Answers keep going out with mentions suppressed at the call site.
- **The bot ignores itself and every other bot**, or a thread becomes a loop.
- **`.env.example` and the README list every `SUPPORT_BOT_*` the Python reads**, in both directions —
  `tests/test_packaging.py` fails otherwise. A new state file means a new documented variable **and**
  a default in the `Dockerfile`, beside the other four.
- **Both languages.** `texts.py` holds French and English at parity, with a test enforcing it.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [The bot hears a mention, and only where it should](FEAT-SUPPORT-ASK-FOLLOWUP.md) | feat |
| 02 | [The thread remembers what it was about](FEAT-SUPPORT-ASK-FOLLOWUP.md) | feat |
| 03 | [Retrieve on the question, not on the ellipsis](FEAT-SUPPORT-ASK-FOLLOWUP.md) | feat |
| 04 | [Say so, in both languages and in the documentation](FEAT-SUPPORT-ASK-FOLLOWUP.md) | docs |

## Definition of done

- Mentioning the bot in a thread it opened continues the conversation, in that thread;
- mentioning it anywhere else does nothing at all;
- a restart does not end a conversation;
- a follow-up spends a question of the asker's allowance, and says so when there is none left;
- `doc/SUPPORT.md` **and** `doc/SUPPORT.en.md` describe it, and `poetry run docs-check` passes.

---

## Tickets, in full

## 01 — The bot hears a mention, and only where it should

Status: ✅ done — merged in #931

Type: feat

### What

Give the gateway connection the `guild_messages` intent — **not** privileged, nothing to enable in
the developer portal — and handle `on_message`.

A message is a follow-up when **all** of these hold:

- it mentions the bot (Discord only fills `content` in that case, so this is also what makes the text
  readable at all);
- it sits in a **thread the bot opened for an `/ask`**, known from the record of ticket 02;
- its author is neither this bot nor any other bot;
- what remains once the mention is stripped is not empty.

Anything else is dropped without a reply. A mention in a channel, in someone else's thread, or in a
`/bug` thread does nothing: those threads are the relay's, and answering there would mix a
documentation answer into a bug report's history.

### Why the guard is four conditions and not one

Each one closes a way this becomes noise or a loop. The bot-author check is the one that cannot be
skipped: two bots that answer each other's mentions in a public thread is a runaway that costs the
day's whole allowance before anybody reads it.

### Done when

- `INTENTS` carries `guild_messages` and nothing privileged, with the reason in the comment beside it;
- a mention in an `/ask` thread produces an answer in that thread;
- a mention in a channel, in a `/bug` thread, or from a bot produces nothing at all;
- the quota keeper sees a follow-up exactly as it sees an `/ask`, and the refusal text is the same;
- tests cover each rejected shape — the point is what does *not* happen.

---

## 02 — The thread remembers what it was about

Status: ✅ done — merged in #931

Type: feat

### What

Record, for each thread `/ask` opens: the opening question, and the turns exchanged since. Keep it in
a JSON file on the `state` volume, beside the quota counters, the filed-issue ledger and the relay
links — the same shape as `relay-links.json`, for the same reason: a conversation must survive
`docker compose up -d --build`.

- new setting `SUPPORT_BOT_ASK_THREADS_FILE`, default `state/ask-threads.json`, documented in
  `.env.example` **and** in the README table (both directions are asserted by
  `tests/test_packaging.py`), with `/app/state/ask-threads.json` added to the `Dockerfile`'s defaults;
- the record is trimmed: the Worker keeps `MAX_HISTORY = 12` turns anyway, so storing more is dead
  weight. Old threads are dropped by age, so the file cannot grow for ever on a busy server;
- a file that cannot be read or written **must not** take `/ask` down. A follow-up in a thread the
  service no longer knows is answered with "open a new question with `/ask`", never with silence.

### Why not read the thread back from Discord instead

It looks cheaper — the messages are right there — and it does not work: without the privileged
`MESSAGE_CONTENT` intent, the history the bot fetches comes back with empty `content` for everything
except its own messages. The asker's original question would be readable only because the bot echoed
it, which makes the record the honest source rather than a cache of one.

### Done when

- an answered `/ask` leaves a record; a follow-up finds it and continues the conversation;
- the record survives a restart of the service;
- an unreadable or unwritable file degrades to a clear message, and `/ask` keeps working;
- old records are pruned, and a test proves the file stops growing.

---

## 03 — Retrieve on the question, not on the ellipsis

Status: ✅ done — merged in #931. Amended 2026-09-22: the widening uses the **latest** question asked in the thread, not the opening one — a thread that drifted kept retrieving on the subject it started from.

Type: feat

### What

The Worker chooses the documentation passages from the **last user turn only**. A follow-up is
almost always elliptical — David's own example, *"et si je veux créer une mission ? on a des
modèles ?"*, names neither the tools nor the subject of the thread — so retrieval against it alone
lands on the wrong pages while the model, which does hold the context, answers confidently over them.

So: build the last user turn as the **thread's opening question joined to the follow-up**, the
follow-up last and verbatim. The model reads the real conversation in the preceding turns, and reads
that turn as what it is — *here is what I asked, here is what I am asking now*.

Measured while designing this, and it settles the shape: the Worker uses the **same** last user turn
for retrieval and for the model (`latestQuery` picks it, `toGeminiContents` sends the whole list).
Separating the two would mean a new field on `/chat` and a Worker deployment; joining them costs one
string and nothing else. Rejected for the same reason: asking a model to rewrite the query would be
better in theory and spends a request of a free tier already shared with the site and the command
line.

### Done when

- the turn sent for a follow-up carries the opening question and the follow-up, in that order;
- a follow-up that is already self-contained is not made worse — the join stays bounded, and the
  follow-up is the tail;
- the joined text respects the same length ceiling as a question;
- a test asserts the shape of the turns handed to the Worker, not the wording of the answer.

---

## 04 — Say so, in both languages and in the documentation

Status: ✅ done — merged in #931

Type: docs

### What

Nobody discovers a mention by accident. Three places have to say it:

- **the answer itself**: the message `/ask` posts in its thread ends with one line telling the reader
  he can mention the bot in this thread to ask more. Every string goes into `texts.py`, French and
  English at parity — the parity test is what keeps the service's own default language from being the
  one that is forgotten (which is exactly the debt `FIX-SUPPORT-BOT-DEBTS` ticket 01 pays);
- **`doc/SUPPORT.md` and `doc/SUPPORT.en.md`**: the `/ask` section gains a short paragraph on
  continuing in the thread, on the fact that a follow-up spends a question of the allowance, and on
  the bot answering only in the thread it opened;
- **`CHANGELOG.md`**, one entry appended at the end of `[Unreleased]`.

### Done when

- the thread's answer tells the reader how to continue, in his language;
- both documentation pages carry it and `poetry run docs-check` passes;
- the texts parity test covers the new strings.

---
