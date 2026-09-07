# FEAT-SUPPORT-ASK-FOLLOWUP — the thread answers back

Status: 🔄 in-progress — the four tickets are done; the PR is open

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
| 01 | [The bot hears a mention, and only where it should](tickets/01-hear-the-mention.md) | feat |
| 02 | [The thread remembers what it was about](tickets/02-thread-memory.md) | feat |
| 03 | [Retrieve on the question, not on the ellipsis](tickets/03-retrieval-context.md) | feat |
| 04 | [Say so, in both languages and in the documentation](tickets/04-texts-and-docs.md) | docs |

## Definition of done

- Mentioning the bot in a thread it opened continues the conversation, in that thread;
- mentioning it anywhere else does nothing at all;
- a restart does not end a conversation;
- a follow-up spends a question of the asker's allowance, and says so when there is none left;
- `doc/SUPPORT.md` **and** `doc/SUPPORT.en.md` describe it, and `poetry run docs-check` passes.
