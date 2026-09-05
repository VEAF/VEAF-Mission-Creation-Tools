# FEAT-SUPPORT-DISCORD-QA — the documentation answers on Discord

Status: ⬜ ready

Origin: design session of 2026-09-05. Lot 3 of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](../FEAT-SUPPORT-DIAGNOSTIC/PRD.md). This is the first lot that puts a
service in front of users; it deliberately carries **no agent and no write access to GitHub**,
so that the channel, the permissions and the quotas are proven before
[`FEAT-SUPPORT-BUG-INTAKE`](../FEAT-SUPPORT-BUG-INTAKE/PRD.md) adds either.

## What it is

A bot on the VEAF Discord, open to the wider DCS public, answering documentation questions through
`/ask`. Each question opens a **public thread**: the answer serves the next person, and anyone
around can correct the bot — *"no, since 6.19 it works differently"*. That social correction is a
better defence against a wrong answer than any technical guard, and it is why the answers are not
ephemeral.

## It is an adapter, not a new brain

The engine is already in production. `poc/doc-chatbot/worker` runs a real RAG — `gemini-2.5-flash-lite`,
`gemini-embedding-001` at 768 dimensions, top-6 passages, index rebuilt in KV on every push touching
`doc/**`. `veaf-tools ask` already talks to it through
[`worker_client.py`](../../src/python/veaf-tools/doc_chatbot/worker_client.py).

The corpus is `doc/` and stays `doc/`: 137 files, 1.8 MB. Sources are **5.1 MB** (2.8 MB of Lua,
2.3 MB of Python), a large part of it data tables — `veafNamedPoints.lua` alone is 539 KB,
`dcsUnits.lua` 365 KB. Indexing that would triple the corpus, blow the free embedding quota of 1000
per day (the doc index already uses about 900) and drown usage answers in tabular noise. Reading
code is lot 4's job, with a different tool: an agent with a checkout, not a similarity search.

## The service

A standalone process, written so it can run **either directly or in a container** — the VEAF can do
both. It lives in a dedicated service folder of this repository, not under `poc/`, and it is
deployed independently of the tools release: nobody waits for a version to fix the bot.

Three responsibilities it carries that a serverless design would not have: keeping its own
configuration and secrets outside the repository, staying alive, and being observable enough that a
silent death is noticed.

## The quota problem this lot must solve

The Worker rate-limits **per IP** ([`src/index.js:98`](../../poc/doc-chatbot/worker/src/index.js)):
10 per minute, 100 per day. A Discord bot is a **single IP** for an entire server — the whole VEAF
would share one user's allowance. So the per-user quota moves into the service, which knows who is
asking, and the Worker gains a `discord` client mode.

The admission hole behind it (`X-VEAF-Client: cli` bypassing the browser allow-list,
[`src/index.js:282`](../../poc/doc-chatbot/worker/src/index.js)) is closed one lot earlier, in
[`FEAT-SUPPORT-LOG-ANALYSIS` ticket 02](../FEAT-SUPPORT-LOG-ANALYSIS/tickets/02-worker-multi-client.md).

## Constraints

- Discord expects an answer within three seconds: reply deferred, then edit.
- Nothing in this repository touches Discord today — every occurrence of the word is a link, a badge
  or a named point called *Discordia*. There is no existing integration to reuse.
- The bot answers **only** what the documentation supports, and says when it does not know. It links
  the pages it used.
- The bot must not be invitable to arbitrary servers in this lot; the audience decision was the VEAF
  Discord, public to DCS players, not a general-purpose distribution.

## Open questions

1. **What happens to `poc/doc-chatbot/`.** It has been in production since June under a `poc/`
   folder, with a stale README whose definition-of-done boxes are all unticked and no active lot.
   This programme builds on it. Promote it out of `poc/` or leave it — David's call.
2. **How the checkout stays fresh** — relevant from lot 4 on, but the service skeleton built here
   decides whether that is a periodic pull or event-driven.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [A service that runs directly or in a container](tickets/01-service-skeleton.md) | feat |
| 02 | [`/ask` answers in a public thread](tickets/02-ask-command.md) | feat |
| 03 | [The quota follows the user, not the IP](tickets/03-per-user-quota.md) | feat |
| 04 | [Say what the bot is, and what it is not](tickets/04-docs.md) | docs |
