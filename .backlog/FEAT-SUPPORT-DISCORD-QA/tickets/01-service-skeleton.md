# 01 — A service that runs directly or in a container

Status: ⬜ ready

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

- [ ] Service folder created, outside `poc/`, with its own README stating how to run it both ways
- [ ] Configuration entirely from the environment; a missing required variable fails loudly at
      startup rather than at the first request
- [ ] Dockerfile, plus a documented direct-run command, both exercised
- [ ] Health/state endpoint or equivalent, and structured logs
- [ ] No secret committed — verified, given this repository already carries one such precedent
      elsewhere in the organisation
- [ ] Unit tests on configuration loading and startup failure paths
- [ ] Quality gate for the impacted language clean
