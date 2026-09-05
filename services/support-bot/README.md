# VEAF support bot — service

The long-running process behind the documentation assistant on the VEAF Discord.

**Status: skeleton.** This is ticket 01 of
[`FEAT-SUPPORT-DISCORD-QA`](../../.backlog/FEAT-SUPPORT-DISCORD-QA/PRD.md). The service starts,
configures itself, reports whether it is alive, logs in a structured format and stops cleanly. It
does **not** talk to Discord yet — the `/ask` command arrives in ticket 02.

---

## What it is, and what it is not

| | |
|---|---|
| **Shape** | A long-running service. Not a CLI, not a serverless Worker — the third shape in this repository. |
| **Home** | `services/support-bot/`, its own Python project with its own `pyproject.toml`. |
| **Release** | Deployed **independently** of the tools. Its version (`0.1.0`) is deliberately *not* the `veaf-tools` version, and it is **not** part of the lockstep between `pyproject.toml` and the two agent manifests. Nobody waits for a release to restart the bot. |
| **Dependencies** | None at run time. Everything below is standard library. |

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

Two variables are **required**: `SUPPORT_BOT_DISCORD_TOKEN` and `SUPPORT_BOT_DISCORD_GUILD_ID`.
A missing or malformed one stops the process **at startup**, with a message listing *every* problem
at once and exit code **78** (`EX_CONFIG`) — a supervisor can tell "this deployment is wrong,
restarting will not help" from "it crashed, try again".

```text
CRITICAL veaf-support-bot.cli the support bot cannot start: 2 configuration problem(s)
  - SUPPORT_BOT_DISCORD_TOKEN is required but not set
  - SUPPORT_BOT_DISCORD_GUILD_ID is required but not set
```

### Directly

Examples use PowerShell, the default shell on Windows. On Linux, `export NAME=value` replaces
`$env:NAME = "value"`.

```powershell
cd services\support-bot
poetry install
$env:SUPPORT_BOT_DISCORD_TOKEN = "..."
$env:SUPPORT_BOT_DISCORD_GUILD_ID = "..."
poetry run python -m veaf_support_bot
```

`poetry run veaf-support-bot` is the same entry point under its installed name. For a readable
terminal run, add `$env:SUPPORT_BOT_LOG_FORMAT = "text"`.

Stop it with `Ctrl+C`: that runs the shutdown sequence below.

### In a container

```powershell
docker build -t veaf-support-bot services\support-bot
docker run -d --name support-bot -p 8081:8081 --env-file services\support-bot\.env veaf-support-bot
```

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
| `GET /readyz` | **Readiness** — it can actually serve. What the container health check polls. | `200` / `503` |
| `GET /status` | The full picture, for a human: uptime, readiness, last heartbeat and its age, last error. | `200` |

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
  "last_error": null
}
```

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

Step 3 is the point of the whole sequence: from ticket 02 on, an `/ask` exchange is a thread opened,
a placeholder posted and an answer edited in. Killed halfway, it leaves a visibly broken exchange on
the server forever.

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
warning on **every** heartbeat, and `"dry_run": true` in `/status`.

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

### Why Python

The alternative was `discord.js` on Node, which is the better-trodden path for a Discord bot. Python
won on what this repository already has and what the lot needs next: a Worker client
([`worker_client.py`](../../src/python/veaf-tools/doc_chatbot/worker_client.py)) that already speaks
to the same chatbot backend, a logger and an i18n layer, the whole test and quality toolchain
configured, and — decisively — the `.miz` export machinery that lot 4 of the programme will need,
which exists only in Python. A second ecosystem would have bought a nicer Discord library and paid
for it in every other direction.
