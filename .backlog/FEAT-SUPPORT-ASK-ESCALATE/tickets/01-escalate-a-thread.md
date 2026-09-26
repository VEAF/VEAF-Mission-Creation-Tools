# 01 — Escalate a thread into a bug or a suggestion

Status: ⬜ ready

Type: feat

## What

Inside an `/ask` thread, a command that opens the `/bug` or `/suggest` intake **pre-filled from the
thread**, instead of from an empty form.

"Done" means: a mission maker who has just been told in a thread that something is wrong can file
the report without retyping it, and nothing reaches GitHub without their explicit confirmation.

## Where the content comes from

The thread holds the question, the bot's answers, and — since 2026-09-22 — every other message too.
That last part is new and deserves care:

> Until 2026-09-22 the app ran without the `MESSAGE_CONTENT` privileged intent, so Discord handed the
> bot an empty `content` for any message that did not mention it. `FEAT-SUPPORT-ASK-FOLLOWUP` builds
> on that: *"the bot cannot read what is not addressed to it"* was a property of the connection, not
> a rule the code had to keep. David enabled the intent in the developer portal on 2026-09-22 so that
> a maintainer session could read a thread end to end. The gateway connection still asks for
> `Intents.none() + guild_messages`, so **the service's runtime behaviour did not change** — but the
> guarantee is now declarative rather than structural.

So: build the draft from the messages that mention the bot and the bot's own replies. Do **not**
start reading the rest of the thread on the strength of an intent the service never asked for. If a
future ticket wants the whole conversation, that is a deliberate decision to take on its own, with
its own privacy answer — not a side effect of a portal toggle.

## Acceptance

- The command only offers itself inside a thread the bot owns; elsewhere it does not appear.
- The draft is shown to the user first. Editing it is possible, and confirming is a separate action.
- Nothing is filed on GitHub without that confirmation — reuse the consent path of
  `FEAT-SUPPORT-BUG-INTAKE` ticket 04 rather than writing a second one.
- A thread that produced no useful report leaves no issue behind: declining is a normal outcome, not
  an error.
- Tests cover: the command offered / not offered, a draft built from a thread, a declined draft
  filing nothing, and a confirmed draft filing exactly once.
