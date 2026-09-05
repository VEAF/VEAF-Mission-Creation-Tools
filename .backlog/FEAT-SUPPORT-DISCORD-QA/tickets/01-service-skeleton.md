# 01 — A service that runs directly or in a container

Status: ✅ done

Type: feat

## The problem

Nothing in this repository is a long-running service. The tools are CLI executables, the Worker is
serverless and deployed by hand. This lot introduces a third shape, and it needs a place and a
skeleton before it needs features.

## What to build

A service folder in this repository — **not** under `poc/` — holding a process that:

- starts from environment configuration only, with **no secret in the repository** (Discord token,
  Worker endpoint, later the Anthropic key and the GitHub App credentials);
- runs identically when launched directly and when containerised, with a Dockerfile and a documented
  direct-run command;
- exposes enough state to tell whether it is alive and working — a silent death is the failure mode
  of every self-hosted bot, and the VEAF has no supervision for this yet;
- logs through the project's logger conventions, never `print()`;
- shuts down cleanly, so a container restart does not leave a half-answered thread.

## Deployment stance

Deployed independently of the tools release. The version lockstep between `pyproject.toml` and the
two agent manifests is about the shipped product; this service is not part of it and must not be
dragged into it.

Language and runtime are an implementation call, but the repository is a Poetry-managed Python
project with an existing Worker client, a logger, and an i18n layer — reusing them costs less than
introducing a second ecosystem, and the intake lot will want the `.miz` export machinery that only
exists in Python.

## Definition of done

- [x] Service folder created, outside `poc/`, with its own README stating how to run it both ways
- [x] Configuration entirely from the environment; a missing required variable fails loudly at
      startup rather than at the first request
- [x] Dockerfile, plus a documented direct-run command, both exercised
- [x] Health/state endpoint or equivalent, and structured logs
- [x] No secret committed — verified, given this repository already carries one such precedent
      elsewhere in the organisation
- [x] Unit tests on configuration loading and startup failure paths
- [x] Quality gate for the impacted language clean

## Outcome

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
