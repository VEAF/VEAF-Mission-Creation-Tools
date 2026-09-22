# FEAT-SUPPORT-ASK-ESCALATE — turn an answered question into an issue

Status: ⬜ ready

Origin: David, 2026-09-22, in the `/ask` thread about CSAR configuration
([1551871856972271616](https://discord.com/channels/471061487662792715/1551871856972271616)). Tripack
asked the bot to *"contacter Zip pour qu'il valide"*, David replied that a bot cannot go fetch a
human, and then noticed the real gap himself:

> **10:22:43** — *"Cela dit là t'as pas fait d'issue. Je me note ça"*
>
> **10:23:08** — *"Peut-être qu'on pourrait rajouter une commande pour basculer d'une conversation
> `ask` à une `bug` ou `suggest`"*

## The gap

An `/ask` thread is where a mission maker finds out something is wrong — the documentation is unclear,
an example does not work, a feature is missing. It is the moment the report is **cheapest to write**:
the context is right there, in the thread, already phrased.

And nothing collects it. `/bug` and `/suggest` exist, both open their own intake form, and both start
from an empty page. So the user who has just spent twenty minutes explaining the problem to the bot
has to explain it a second time, to a form, from scratch. In this thread nobody did — the exchange
produced a real documentation gap and **zero issues**.

## What it does

A command available **inside an `/ask` thread** that escalates the conversation into `/bug` or
`/suggest`, pre-filled from what the thread already contains.

The bot is an intermediary, not a reporter: the draft is shown to the user, who edits and confirms
before anything is filed. The existing `/bug` consent step (`FEAT-SUPPORT-BUG-INTAKE` ticket 04) is
the model and should be reused rather than re-invented.

## Not in scope

- Filing anything without an explicit confirmation from the user.
- Pinging a human. David was explicit in the thread: the bot does not go get somebody.
- Reading messages the bot was not addressed in. See the note in the ticket about what the
  `MESSAGE_CONTENT` intent changed on 2026-09-22.

## Tickets

| # | Title | Status |
|---|---|---|
| 01 | [Escalate a thread into a bug or a suggestion](tickets/01-escalate-a-thread.md) | ⬜ |
