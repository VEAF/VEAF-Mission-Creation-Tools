# FEAT-SUPPORT-DISCORD-QA — the documentation answers on Discord

Status: ✅ done · archived 2026-09-28

Origin: design session of 2026-09-05. Lot 3 of the programme described in
[`FEAT-SUPPORT-DIAGNOSTIC`](FEAT-SUPPORT-DIAGNOSTIC.md). This is the first lot that puts a
service in front of users; it deliberately carries **no agent and no write access to GitHub**,
so that the channel, the permissions and the quotas are proven before
[`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md) adds either.

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
[`FEAT-SUPPORT-LOG-ANALYSIS` ticket 02](FEAT-SUPPORT-LOG-ANALYSIS.md).

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
| 01 | [A service that runs directly or in a container](FEAT-SUPPORT-DISCORD-QA.md) | feat |
| 02 | [`/ask` answers in a public thread](FEAT-SUPPORT-DISCORD-QA.md) | feat |
| 03 | [The quota follows the user, not the IP](FEAT-SUPPORT-DISCORD-QA.md) | feat |
| 04 | [Say what the bot is, and what it is not](FEAT-SUPPORT-DISCORD-QA.md) | docs |

---

## Tickets, in full

## 01 — A service that runs directly or in a container

Status: ✅ done

Type: feat

### The problem

Nothing in this repository is a long-running service. The tools are CLI executables, the Worker is
serverless and deployed by hand. This lot introduces a third shape, and it needs a place and a
skeleton before it needs features.

### What to build

A service folder in this repository — **not** under `poc/` — holding a process that:

- starts from environment configuration only, with **no secret in the repository** (Discord token,
  Worker endpoint, later the Anthropic key and the GitHub App credentials);
- runs identically when launched directly and when containerised, with a Dockerfile and a documented
  direct-run command;
- exposes enough state to tell whether it is alive and working — a silent death is the failure mode
  of every self-hosted bot, and the VEAF has no supervision for this yet;
- logs through the project's logger conventions, never `print()`;
- shuts down cleanly, so a container restart does not leave a half-answered thread.

### Deployment stance

Deployed independently of the tools release. The version lockstep between `pyproject.toml` and the
two agent manifests is about the shipped product; this service is not part of it and must not be
dragged into it.

Language and runtime are an implementation call, but the repository is a Poetry-managed Python
project with an existing Worker client, a logger, and an i18n layer — reusing them costs less than
introducing a second ecosystem, and the intake lot will want the `.miz` export machinery that only
exists in Python.

### Definition of done

- [x] Service folder created, outside `poc/`, with its own README stating how to run it both ways
- [x] Configuration entirely from the environment; a missing required variable fails loudly at
      startup rather than at the first request
- [x] Dockerfile, plus a documented direct-run command, both exercised
- [x] Health/state endpoint or equivalent, and structured logs
- [x] No secret committed — verified, given this repository already carries one such precedent
      elsewhere in the organisation
- [x] Unit tests on configuration loading and startup failure paths
- [x] Quality gate for the impacted language clean

### Outcome

Delivered in `services/support-bot/`.

**Runtime: Python.** The alternative was `discord.js` on Node — the better-trodden path for a
Discord bot, and the only argument for it. Against: the Worker client
(`src/python/veaf-tools/doc_chatbot/worker_client.py`) already speaks to the same chatbot backend,
the logger, the i18n layer and the whole quality toolchain are configured, and lot 4 of the
programme needs the `.miz` export machinery, which exists only in Python.

The service is its own Poetry project (`services/support-bot/pyproject.toml`, version `0.1.0`) with
**no runtime dependency** — configuration, structured logging, the health endpoints and the shutdown
sequence are standard library. That keeps the image small, keeps the Discord library out of the
`veaf-tools` executable when ticket 02 adds it, and makes the deployment cadence genuinely
independent of the tools release.

**"Both exercised"** means: the direct run was launched and probed on a workstation (health endpoint,
`--healthcheck` probe, `/status`, heartbeat lines, exit code 78 on a missing variable); the container
is built and driven in CI by the `Support Bot` workflow, which asserts that a misconfigured container
refuses to start, that the endpoint answers from outside, that Docker's own health check turns the
container healthy, and that `SIGTERM` reaches the process so the clean shutdown really runs on
`docker stop`. Docker is not installed on the workstation, so CI is where that half lives.

**Not done here, on purpose:** nothing connects to Discord yet. `SUPPORT_BOT_DISCORD_TOKEN` and
`SUPPORT_BOT_DISCORD_GUILD_ID` are required and validated at startup — so a deployment is already
correct before ticket 02 lands — but they are not used yet.

---

## 02 — `/ask` answers in a public thread

Status: ✅ done

Type: feat

### What to build

A `/ask` command on the VEAF Discord. It opens a **public thread** on the question and answers
there, streaming into an edited message.

Why a thread and not an ephemeral reply: the answer serves the next person who asks the same thing,
and anyone passing by can correct the bot. On a documentation assistant that is the only correction
loop that actually catches a wrong answer — no technical guard notices that the doc changed in 6.19.
It also gives the thread a durable identity, which lot 4 reuses to relay GitHub activity back.

### Mechanics

- Discord wants a response within **three seconds**: acknowledge deferred, then edit the message as
  the answer arrives. The Worker already streams over SSE, so the pieces exist.
- The bot cites the documentation pages it used, as links. An answer with no source is a claim.
- It says when the documentation does not cover the question, instead of extrapolating, and offers
  the route to `/bug` — which does nothing until lot 4, so in this lot it points at the support page
  instead.
- Language follows the asker; the corpus is indexed per language (`fr` / `en`) already.
- Errors from upstream are surfaced as a human sentence, including the rate-limited case, rather
  than a stack trace or silence.

### Notes

- The thread is created from the question, so the question text is visible in the channel; the
  answer lives inside. That keeps the channel readable.
- Nothing here writes to GitHub, and nothing here runs an agent. That is deliberate: this lot proves
  the channel, the permissions and the quotas first.

### Definition of done

- [x] `/ask` registered and answering in a thread attached to the question
- [x] Deferred acknowledgement inside three seconds, then progressive edit
- [x] Sources cited as links to the documentation pages used
- [x] "Not covered by the documentation" answered as such, with a route to the support page
- [x] Upstream errors, including rate limiting, rendered as a sentence
- [x] Unit tests with the Discord layer and the Worker both mocked, covering: normal answer,
      unknown answer, upstream error, rate limit
- [x] Quality gate clean

---

## 03 — The quota follows the user, not the IP

Status: ✅ done

Type: feat

### The problem

The Worker counts requests **per IP**
([`src/index.js:98`](../../poc/doc-chatbot/worker/src/index.js)): 10 a minute, 100 a day, keyed
on `CF-Connecting-IP`. A bot is one IP for an entire Discord server. Left as is, the whole VEAF
shares a single user's daily allowance and the bot stops answering after a hundred questions —
or, worse, one person exhausts it for everyone by lunchtime.

The service is the only component that knows **who** is asking. So the per-user quota belongs there,
and the Worker gets a `discord` client mode with a ceiling sized for a server rather than a browser.

### What to build

- Per-Discord-user counters in the service — a short window and a daily one, mirroring the shape the
  Worker already uses.
- A global daily ceiling for the whole bot, so a bad day has a known cost and a known end.
- When a limit is hit, the bot **says so** with when it resets. A bot that goes quiet is
  indistinguishable from a bot that is broken — and this is the same failure the CI monitors had.
- Counters that survive a restart, or degrade to something stricter rather than resetting to
  unlimited. Fail closed, as decided for the Worker.
- The `discord` client mode consumed on the Worker side, per
  [`FEAT-SUPPORT-LOG-ANALYSIS` ticket 02](FEAT-SUPPORT-LOG-ANALYSIS.md).

### Notes

- The audience is the VEAF Discord open to the DCS public, so the quota is the only thing standing
  between an unknown visitor and the free-tier ceiling that also serves the documentation widget and
  the CLI. Sizing it is a real decision, not a placeholder.
- These counters are reused, with a much lower ceiling, by
  [`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md). Build them once.

### Definition of done

- [x] Per-user short-window and daily counters
- [x] Global daily ceiling, configurable, with its value documented
- [x] A refused request answers with the reason and the reset time
- [x] Restart does not silently reset counters to unlimited
- [x] `discord` client mode used against the Worker
- [x] Unit tests: per-user limit, global limit, restart behaviour, message rendering
- [x] Quality gate clean

---

## 04 — Say what the bot is, and what it is not

Status: ✅ done

Type: docs

### What to write

Two audiences, two documents.

**For users**, on the support page created in
[`FEAT-SUPPORT-DIAGNOSTIC` ticket 03](FEAT-SUPPORT-DIAGNOSTIC.md):
what `/ask` does, where it answers, that the answer comes from the documentation and may be wrong,
that a thread is public, and what to do when the bot does not know. Both languages, in the `nav`.

**For operators**, next to the service: how to run it, which environment variables it needs, how to
register the Discord application and which permissions it requires, what the quotas are set to and
where to change them, and how to tell whether it is alive.

### The line to hold

The bot answers **from the documentation**. Say it plainly, including the consequence: a
documentation gap becomes a wrong or missing answer, and the fix is to write the page, not to
retrain anything. That framing is what keeps `/ask` honest and turns its failures into documentation
tickets.

Also say what it deliberately does not do in this lot: it does not read the sources, it does not
open issues, it does not analyse logs. Each of those arrives later, and users who expect them now
will read the silence as a bug.

### Notes

- Explicit English anchors on anything cross-linked; both languages in lockstep.
- No hand-written version numbers.
- `poetry run docs-check` is the gate.

### Definition of done

- [x] User-facing section on the support page, both languages, in the `nav`
- [x] Operator documentation next to the service: variables, Discord registration, permissions,
      quotas, liveness
- [x] The "answers from the documentation" limit stated explicitly, with its consequence
- [x] What the bot does not do yet, stated
- [x] `poetry run docs-check` passes

---
