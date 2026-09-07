# 01 — The bot hears a mention, and only where it should

Status: ✅ done — merged in #931

Type: feat

## What

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

## Why the guard is four conditions and not one

Each one closes a way this becomes noise or a loop. The bot-author check is the one that cannot be
skipped: two bots that answer each other's mentions in a public thread is a runaway that costs the
day's whole allowance before anybody reads it.

## Done when

- `INTENTS` carries `guild_messages` and nothing privileged, with the reason in the comment beside it;
- a mention in an `/ask` thread produces an answer in that thread;
- a mention in a channel, in a `/bug` thread, or from a bot produces nothing at all;
- the quota keeper sees a follow-up exactly as it sees an `/ask`, and the refusal text is the same;
- tests cover each rejected shape — the point is what does *not* happen.
