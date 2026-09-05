# FEAT-SUPPORT-DIAGNOSTIC — the three facts every bug report is missing

Status: ⬜ ready

Origin: design session of 2026-09-05, David's idea of a Discord assistant that answers on the
documentation, guides a bug report and opens the issue itself. The session split that idea into
**five lots**, and this one comes first because it is the only piece that keeps its value even if
the bot is never built.

## The programme this belongs to

| Order | Lot | Where it runs |
|-------|-----|---------------|
| **1** | `FEAT-SUPPORT-DIAGNOSTIC` — this one | the user's machine |
| 2 | [`FEAT-SUPPORT-LOG-ANALYSIS`](../FEAT-SUPPORT-LOG-ANALYSIS/PRD.md) | the user's machine |
| 3 | [`FEAT-SUPPORT-DISCORD-QA`](../FEAT-SUPPORT-DISCORD-QA/PRD.md) | Worker + service |
| 4 | [`FEAT-SUPPORT-BUG-INTAKE`](../FEAT-SUPPORT-BUG-INTAKE/PRD.md) | service |
| 5 | [`FEAT-SUPPORT-SUGGESTIONS`](../FEAT-SUPPORT-SUGGESTIONS/PRD.md) | service |

Two principles hold the programme together, and they are decisions, not preferences: **the free
tier carries the volume, the paid model is reserved for value**; and **the user's machine produces
the bounded material, the service only analyses it**. Everything below follows from the second.

## Why this lot exists

The idea started as "an AI that turns a user's complaint into a good issue". The measurement says
the complaint is rarely the weak part.

- **4 user-opened issues are still open**, the most recent from March 2024; the last issue filed by
  a user at all is #304, January 2026. There is no flood to triage.
- The issue forms in `.github/ISSUE_TEMPLATE/` have existed since 2026-05-20 and **none of the last
  60 issues used them**. Everyone writes free-form Markdown.
- When a regular does report (Tripack above all), he attaches the `dcs.log` excerpt with the full
  traceback, the mission, screenshots, and sometimes the fix — see #212, #215. The reports are
  already good.
- What is missing almost every time is mechanical and identical: **tool version, DCS version, steps
  to reproduce**. A model cannot deduce those. It can only ask someone who does not know them.

So the first thing to build is not an assistant, it is the three facts.

## What the tool cannot tell you today

| Fact | Available? |
|---|---|
| Tool version | printed at every launch ([`app.py:71`](../../src/python/veaf-tools/veaf_tools/app.py)) and by `about`, but there is **no `--version` flag** on the root callback |
| DCS version, OS, install paths | nowhere |
| Lua module inventory | `about --modules` only |
| Recent errors | `~/.veaf/veaf-tools.log`, which the documentation says is in the current directory |
| Stack traces | **never written** — `exception()` calls `error(str(e))` with no `exc_info` ([`logger.py:103`](../../src/python/veaf-tools/veaf_libs/logger.py)) |
| A diagnostic command | none among the 22 commands in `veaf_tools/commands/` |

An uncaught crash is worse still: `app()` runs inside a `try/finally` with no `except`
([`app.py:80`](../../src/python/veaf-tools/veaf_tools/app.py)), so a traceback lands on stderr and
is never journalled.

## Constraints

- `doctor` output is **the interface** the two following lots consume: `FEAT-SUPPORT-LOG-ANALYSIS`
  embeds it in its report block, and `FEAT-SUPPORT-BUG-INTAKE` parses it. Its shape is a contract,
  not a convenience — pin it in this lot and document it.
- Anything `doctor` prints may end up **pasted into a public issue** by a user who will not reread
  it. Redaction is part of this lot, not of the one that publishes.
- The `veaf_libs.logger` change touches every command in the tool. Existing behaviour on the
  console must not move; only what reaches the file does.
- Both documentation languages, in lockstep, and `poetry run docs-check` passes.
- `logger.error` raises `typer.Abort` — it is not a log call. Nothing here may route a diagnostic
  message through it.

## Open questions

1. **The exact field list of `doctor`** is what decides whether future issues are usable. Draft it,
   put it in front of David, and only then write the formatter.
2. **How the DCS version is read** — from `%USERPROFILE%\Saved Games\DCS*\Logs\dcs.log`'s header,
   from the install directory, or both, and what happens when DCS is absent (the PwC workstation
   case).

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [`veaf-tools doctor` collects the facts nobody supplies](tickets/01-doctor-command.md) | feat |
| 02 | [The user log finally records stack traces](tickets/02-log-records-tracebacks.md) | fix |
| 03 | [The documentation points at the log that exists](tickets/03-doc-support-page.md) | docs |
