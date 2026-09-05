# VEAF support bot — service

The long-running process behind the documentation assistant on the VEAF Discord.

It answers `/ask` on the VEAF Discord, in a public thread, from the documentation and nothing else.

---

## What it is, and what it is not

| | |
|---|---|
| **Shape** | A long-running service. Not a CLI, not a serverless Worker — the third shape in this repository. |
| **Home** | `services/support-bot/`, its own Python project with its own `pyproject.toml`. |
| **Release** | Deployed **independently** of the tools. Its version (`0.1.0`) is deliberately *not* the `veaf-tools` version, and it is **not** part of the lockstep between `pyproject.toml` and the two agent manifests. Nobody waits for a release to restart the bot. |
| **Dependencies** | One at run time: `discord.py` (which brings `aiohttp`). Everything else is standard library. |

### What it does **not** do

Stated plainly, because a user who expects one of these will read its absence as a bug:

- **It does not read the sources.** The corpus is `doc/`, 1.8 MB of documentation, and nothing else.
  A question whose answer only exists in a `.lua` or a `.py` file has no answer here. Reading code
  needs a different tool — an agent with a checkout, not a similarity search — and that arrives in
  [`FEAT-SUPPORT-BUG-INTAKE`](../../.backlog/FEAT-SUPPORT-BUG-INTAKE/PRD.md).
- **It does not open issues.** `/bug` does not exist. When the bot does not know, it points at the
  support page, which says where to report things.
- **It does not analyse logs.** That is
  [`FEAT-SUPPORT-LOG-ANALYSIS`](../../.backlog/FEAT-SUPPORT-LOG-ANALYSIS/PRD.md), a separate lot and
  a separate Worker route.
- **It answers from the documentation, so a documentation gap is a wrong or missing answer.** The
  fix is to write the page. There is nothing to retrain, and no way to correct the bot other than
  correcting `doc/`. That is the point: `/ask` failing is a documentation ticket.

---

## How `/ask` works

1. The interaction is **acknowledged within three seconds** — Discord's whole budget — before the
   quota is read or the Worker is called.
2. The acknowledgement becomes the visible **question message** in the channel.
3. A **public thread** is opened on it, and the answer is posted and edited there. Public on
   purpose: the answer serves the next person who asks the same thing, and anyone passing by can
   correct the bot. On a documentation assistant that is the only correction loop that catches a
   wrong answer — no technical guard notices that the documentation changed in 6.19.
4. The answer cites the pages it used, as links. The Worker cannot tell the service which passages
   it retrieved, so the **model** is asked to declare the titles it used and every declared title is
   checked against the real `doc/` tree. A title the corpus does not have is dropped. The bot can
   therefore show *fewer* sources than it used — never one that does not exist.
5. No page cited reads as "the documentation may not cover this", with a route to the support page.

If the bot cannot open a thread — usually a missing **Create Public Threads** permission — it says
so and answers in the channel anyway. Losing the answer would be worse.

**Nothing gets past step 1 without an answer.** Once the interaction is acknowledged, Discord shows
"the bot is thinking" until something edits the response, so every later step runs under one guard:
an upstream failure, a refusal from Discord itself, or a bug of ours all end as a sentence in the
thread. The whole exchange is also bounded — 60 seconds by default — because a deferred interaction
token dies after fifteen minutes, and an answer that arrives after that is an answer nobody sees.

---

## Running it

Both ways run the same module, `python -m veaf_support_bot`, with the same environment. There is no
"container mode" in the code, which is what makes the direct run a real rehearsal of the deployment.

### Configuration

Everything comes from the environment; nothing is read from a file in the repository, and no secret
is committed. Copy [`.env.example`](.env.example) — it documents every variable — to `.env` and fill
it in. That file is ignored by the repository's **root** `.gitignore`, which is where the rule has to
live: the root file ignores every nested `.gitignore`, so one placed here would look right and do
nothing.

Three variables are **required**: `SUPPORT_BOT_DISCORD_TOKEN`, `SUPPORT_BOT_DISCORD_GUILD_ID` and
`SUPPORT_BOT_WORKER_SECRET`. A missing or malformed one stops the process **at startup**, with a
message listing *every* problem at once and exit code **78** (`EX_CONFIG`) — a supervisor can tell
"this deployment is wrong, restarting will not help" from "it crashed, try again".

```text
CRITICAL veaf-support-bot.cli the support bot cannot start: 3 configuration problem(s)
  - SUPPORT_BOT_DISCORD_TOKEN is required but not set
  - SUPPORT_BOT_DISCORD_GUILD_ID is required but not set
  - SUPPORT_BOT_WORKER_SECRET is required but not set
```

#### Every variable

| Variable | Required | Default | What it is |
|---|---|---|---|
| `SUPPORT_BOT_DISCORD_TOKEN` | **yes** | — | The bot token. **Secret.** Anyone holding it *is* the bot. |
| `SUPPORT_BOT_DISCORD_GUILD_ID` | **yes** | — | The one guild served. Commands are published there and nowhere else. |
| `SUPPORT_BOT_WORKER_SECRET` | **yes** | — | **Secret.** Sent as `X-VEAF-Auth`; must equal the Worker's `DISCORD_CLIENT_SECRET`. |
| `SUPPORT_BOT_WORKER_ENDPOINT` | no | the production Worker `/chat` | Override to test against a preview deployment. |
| `SUPPORT_BOT_WORKER_CLIENT` | no | `discord` | Sent as `X-VEAF-Client`; the Worker quotas this mode apart from the CLI and the website. |
| `SUPPORT_BOT_QUOTA_STATE_FILE` | no | `state/quota.json` | Where the per-user counters live. Must be writable **and** must survive a restart. |
| `SUPPORT_BOT_QUOTA_USER_WINDOW_SECONDS` | no | `60` | Length of the per-user burst window. |
| `SUPPORT_BOT_QUOTA_USER_PER_WINDOW` | no | `3` | Questions one user may ask inside that window. |
| `SUPPORT_BOT_QUOTA_USER_PER_DAY` | no | `15` | Questions one user may ask in a UTC day. |
| `SUPPORT_BOT_QUOTA_GLOBAL_PER_DAY` | no | `200` | Questions the **whole bot** may ask in a UTC day. |
| `SUPPORT_BOT_HEALTH_HOST` | no | `127.0.0.1` (`0.0.0.0` in the image) | Interface the health endpoint binds. |
| `SUPPORT_BOT_HEALTH_PORT` | no | `8081` | Port it binds. `0` asks the OS for an ephemeral one, which `--healthcheck` then cannot probe. |
| `SUPPORT_BOT_LOG_LEVEL` | no | `INFO` | `CRITICAL`, `ERROR`, `WARNING`, `INFO` or `DEBUG`. |
| `SUPPORT_BOT_LOG_FORMAT` | no | `json` | `json` for a collector, `text` for a terminal. |
| `SUPPORT_BOT_HEARTBEAT_SECONDS` | no | `60` | Interval between heartbeat log lines. |
| `SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` | no | `10` | Bounds the **whole** shutdown sequence, not each step. |
| `SUPPORT_BOT_DRY_RUN` | no | `false` | Start everything except the connection to Discord. |

[`.env.example`](.env.example) carries the same list with the reasoning; `tests/test_packaging.py`
fails when the two drift apart, in either direction.

### Registering the Discord application

Once, at <https://discord.com/developers/applications>:

1. **New Application**, then **Bot** → **Reset Token**. That token is `SUPPORT_BOT_DISCORD_TOKEN`.
2. Leave every **Privileged Gateway Intent** off. The bot reads slash-command options and nothing
   else — not message content, not the member list — and `tests/test_discord_adapter.py` asserts it
   never asks for them.
3. **OAuth2 → URL Generator**: scopes `bot` and `applications.commands`; bot permissions **Send
   Messages**, **Create Public Threads** and **Send Messages in Threads**. Invite it to the VEAF
   guild with the generated URL.
   - Without *Create Public Threads* the bot still answers, in the channel, saying why.
   - Without *Send Messages in Threads* it opens a thread it cannot write in. Grant both.
4. Right-click the server → **Copy Server ID** (Developer Mode must be on). That is
   `SUPPORT_BOT_DISCORD_GUILD_ID`. Commands are published to that guild only, so they appear
   immediately instead of taking up to an hour to propagate, and the bot stays un-invitable
   elsewhere.

### The other half: the Worker Secret

`SUPPORT_BOT_WORKER_SECRET` is a **shared** secret. Pick a value, then set it on both sides:

```powershell
cd poc\doc-chatbot\worker
npx wrangler secret put DISCORD_CLIENT_SECRET
```

Until that Secret exists on the Worker, the `discord` client mode is **refused outright** — it is
groundwork, not an open door. The bot then answers every question with "the documentation assistant
is refusing questions from this bot", which says plainly that retrying will not help.

### The quotas, and where to change them

| Ceiling | Default | Why that number |
|---|---|---|
| Per user, per minute | 3 | A burst guard. Below the 5 the Worker grants this mode, so the user meets the bot's message — which names the reset time — rather than the Worker's bare refusal. |
| Per user, per UTC day | 15 | Same reasoning against the Worker's 40. |
| Whole bot, per UTC day | 200 | The **only** bound on total spend: the Worker counts per user and cannot see the bot's total. Every question costs one Gemini embedding call, on a free tier shared with the documentation website and `veaf-tools ask`; the documentation index alone uses about 900 of the 1000 daily embeddings on a day it is rebuilt. |

Change them with the `SUPPORT_BOT_QUOTA_*` variables above. Raise the global one deliberately: it is
what stops a bad day from taking the website's chatbot down with it.

A refused question **says so**, with the reason and when the ceiling lifts, rendered as a Discord
timestamp so every reader sees it in their own timezone. A bot that simply goes quiet is
indistinguishable from a bot that is broken.

The counters are kept in `SUPPORT_BOT_QUOTA_STATE_FILE` so a restart is not a way to get a fresh
allowance. **Mount a volume at `/app/state`** in a container, or the counters die with the container.
When the file cannot be read or written — a corrupt file, a volume that went away, a bind mount the
service cannot write to — it does not carry on with counters nobody keeps: it drops to **2 questions
per minute *and* a tenth of the daily ceiling, for the whole bot** (20 a day at the defaults, capped
by what one user gets in a healthy day, so 15), says so at `ERROR`, and shows `"degraded": true` in
`/status`. Stricter on every axis, never "unlimited".

The daily half of that matters as much as the minute: what puts the service here is a *local* fault
that lasts until somebody notices, not a passing outage. A window ceiling alone would be 2880
questions a day — fourteen times what the healthy path allows, and payable by one person.

### Directly

Examples use PowerShell, the default shell on Windows. On Linux, `export NAME=value` replaces
`$env:NAME = "value"`.

```powershell
cd services\support-bot
poetry install
$env:SUPPORT_BOT_DISCORD_TOKEN = "..."
$env:SUPPORT_BOT_DISCORD_GUILD_ID = "..."
$env:SUPPORT_BOT_WORKER_SECRET = "..."
poetry run python -m veaf_support_bot
```

`poetry run veaf-support-bot` is the same entry point under its installed name. For a readable
terminal run, add `$env:SUPPORT_BOT_LOG_FORMAT = "text"`.

Stop it with `Ctrl+C`: that runs the shutdown sequence below.

### In a container

```powershell
docker build -t veaf-support-bot services\support-bot
docker run -d --name support-bot -p 8081:8081 `
  --env-file services\support-bot\.env `
  -v support-bot-state:/app/state `
  veaf-support-bot
```

The volume is not optional in production: it is where the per-user quota counters live, and without
it `docker rm` hands everyone a fresh allowance. (In `cmd.exe` the line-continuation character is
`^`, not the backtick.)

The image binds the health endpoint on `0.0.0.0` (a container's loopback is unreachable from the
host), runs as an unprivileged user, and declares a Docker `HEALTHCHECK` that calls the service's
own `--healthcheck` probe. `docker stop` sends `SIGTERM` straight to the process — the entry point is
in exec form, with no shell in between — so the clean shutdown actually runs.

---

## Knowing whether it is alive

A self-hosted Discord bot dies silently: the process is up, the container says *running*, and the
only symptom is that nobody gets an answer. The VEAF has no supervision for this, so the service
makes itself checkable two ways.

### The HTTP endpoints

| Route | Meaning | Codes |
|---|---|---|
| `GET /healthz` | **Liveness** — the event loop still turns. Says nothing about readiness, on purpose: a transient un-readiness must not trigger a restart loop. | `200` |
| `GET /readyz` | **Readiness** — the Discord gateway is connected, so a question can actually be answered. What the container health check polls. | `200` / `503` |
| `GET /status` | The full picture, for a human: uptime, readiness, last heartbeat and its age, last error, and the day's quota spend. | `200` |

**Readiness means the gateway is connected**, and nothing weaker. A disconnection withdraws it, a
resumed session restores it, and a connection that ends for good takes the process down rather than
leaving a live container that will never answer again. A **dry run is therefore never ready** — it
answers nobody, and its container shows as *unhealthy*, which is exactly what should happen to one
left on in production.

```powershell
Invoke-RestMethod http://127.0.0.1:8081/status
```

```json
{
  "service": "veaf-support-bot", "version": "0.1.0",
  "ready": true, "not_ready_reason": null, "dry_run": false,
  "started_at": "2026-09-05T09:45:37.038+00:00", "uptime_seconds": 3.111,
  "ready_since": "2026-09-05T09:45:37.042+00:00",
  "last_heartbeat_at": "2026-09-05T09:45:40.072+00:00", "last_heartbeat_age_seconds": 0.077,
  "last_error": null,
  "details": {
    "day": "2026-09-05", "global_count": 12, "global_per_day": 200,
    "tracked_users": 4, "degraded": false, "degraded_reason": null,
    "degraded_count": 0, "degraded_per_day": 15
  }
}
```

`details` is the first thing to look at when the bot starts refusing: `global_count` against
`global_per_day` says whether the day's allowance is spent, and `degraded` says whether the counters
are being kept at all. When it is `true`, read `degraded_count` against `degraded_per_day` instead —
`global_count` stops moving while the counters are not kept, so it alone would show a bot answering
and a spend of zero. No Discord identity appears there — `/status` is an operator interface, not a
record of who asked what.

The endpoint binds `127.0.0.1` by default: it is an operator interface, not a public one. Point an
uptime monitor at `/readyz` through whatever already fronts the host.

### The heartbeat line

Every `SUPPORT_BOT_HEARTBEAT_SECONDS` (60 by default) the service logs
`"event": "service.heartbeat"`. That is what makes a log-based alert — *nothing from the bot for ten
minutes* — possible where nothing polls an endpoint.

### The logs

One JSON object per line on **stdout**, which is where a container supervisor collects them. Every
line carries an `event` key so alerts filter on a field rather than grep prose.

```json
{"ts": "2026-09-05T09:45:37.042+00:00", "level": "INFO", "logger": "veaf-support-bot.service",
 "message": "ready", "event": "service.ready", "health_port": 8081}
```

`SUPPORT_BOT_LOG_FORMAT=text` switches to a readable one-line format for a terminal.

The bot token never appears in a log line or in a traceback: the configuration object redacts it in
both `repr` and the startup line, and a configuration error never echoes the value it refused — only
its shape (`is not an integer (got 47 characters)`). Pasting the token into `SUPPORT_BOT_DISCORD_GUILD_ID`
is an easy first-deployment slip, and that message is printed at `CRITICAL` on stdout, where a log
collector picks it up.

---

## Shutting down

`SIGTERM` (a container restart) or `SIGINT` (`Ctrl+C`) starts a sequence, in this order:

1. readiness drops — a probe sees `503` immediately, before anything is torn down;
2. the heartbeat stops;
3. work already in flight gets `SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` (10 by default) to finish;
4. anything still running is cancelled, and the log line says how many;
5. the health endpoint closes, and a final `"event": "service.stopped"` line reports the reason,
   the uptime and the number of cancelled tasks.

Step 3 is the point of the whole sequence: an `/ask` exchange is a thread opened, a placeholder
posted and an answer edited in. Killed halfway, it leaves a visibly broken exchange on the server
forever. Every exchange is registered with the drain, and the gateway is closed **after** it — a
closed connection cannot edit a message, so closing first would guarantee the abandoned placeholder
the sequence exists to avoid.

`SUPPORT_BOT_SHUTDOWN_GRACE_SECONDS` bounds the **whole** sequence, not each step: step 5 gets what
step 3 left of it. That matters because `docker stop` kills at ten seconds whatever the service
intends — a shutdown that can add up to twice the configured grace is one whose final line is never
written, and a bot that dies silently is the exact failure this service is built to make visible. A
health connection still open when the budget runs out has its socket cut, and the abort is logged
(`"event": "health.connections_aborted"`) rather than done quietly — that last step can add up to one
more second, for the event loop to collect the aborted sockets, so the true ceiling is the grace plus
a second.

---

## Dry run

`SUPPORT_BOT_DRY_RUN=true` starts every moving part except the connection to the outside world, and
needs no credentials. It is how the container is smoke-tested in CI.

Left on by accident it would be an invisible outage, so it is not quiet: a warning at startup, a
warning on **every** heartbeat, `"dry_run": true` in `/status`, and — since it answers nobody —
`/readyz` returning `503` with `"not_ready_reason": "dry-run"`, which makes the container
*unhealthy*.

---

## Working on it

```powershell
cd services\support-bot
poetry install
poetry run pytest
poetry run ruff check veaf_support_bot tests --fix
poetry run ruff format --check veaf_support_bot tests
poetry run mypy
```

Same tools and the same ruff settings as the rest of the repository; `mypy` is **stricter** here
(`disallow_untyped_defs`), because the package is new and starts clean. The repository-wide
commands in `CLAUDE.md` (`ruff check src/python/ test/python/ veaf_build/`, `mypy
src/python/veaf-tools/`, root `pytest`) do **not** cover this folder — the
[`Support Bot`](../../.github/workflows/support-bot-ci.yml) workflow does, and it also builds the
image and exercises the container.

### After changing a documentation page

The bot links the pages it cites from an index generated out of `doc/` and checked in. Renaming a
page, or changing its first heading, makes that index stale:

```powershell
poetry run python scriptsefresh_doc_pages.py
```

`tests/test_doc_pages.py` rebuilds the index from the real tree and fails when the checked-in copy
has drifted, so forgetting the command is a red test rather than a link that quietly 404s. The
workflow triggers on `doc/**` for that reason.

### The tests that matter most

`tests/test_wiring.py` asserts the **connections**, not the handlers: the command registered, the
callback reaching the handler with the asker and their locale, the exchange tracked so a shutdown
drains it, readiness published by the gateway, the counters built from the configuration and
enforced by the handler that actually runs. Four bugs have shipped green on this repository because
a suite called the handler and never the thing that branches to it.

Its last class cuts each of those wires and asserts the matching test turns red. A wiring test that
cannot fail is the same bug one level up.

### Why Python

The alternative was `discord.js` on Node, which is the better-trodden path for a Discord bot. Python
won on what this repository already has and what the lot needs next: a Worker client
([`worker_client.py`](../../src/python/veaf-tools/doc_chatbot/worker_client.py)) that already speaks
to the same chatbot backend, a logger and an i18n layer, the whole test and quality toolchain
configured, and — decisively — the `.miz` export machinery that lot 4 of the programme will need,
which exists only in Python. A second ecosystem would have bought a nicer Discord library and paid
for it in every other direction.
