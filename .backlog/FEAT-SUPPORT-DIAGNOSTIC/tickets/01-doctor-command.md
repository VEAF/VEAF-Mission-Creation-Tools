# 01 — `veaf-tools doctor` collects the facts nobody supplies

Status: ✅ done

Type: feat

## The problem

Every bug report is missing the same three things: which version of the tool, which version of DCS,
and how to reproduce. The first two are mechanical facts sitting on the user's machine; the tool
just never reads them out. There is no diagnostic command among the 22 in
`src/python/veaf-tools/veaf_tools/commands/`, and no `--version` on the root callback
([`app.py:34`](../../../src/python/veaf-tools/veaf_tools/app.py) exposes only `--lang`).

`about --modules` is the closest thing today, and it covers only the embedded Lua modules — not the
OS, not DCS, not the paths, not the recent errors.

## What it produces

One command, two renderings of the same content: readable on the console, and a fenced block the
user can paste as-is. The paste form is the **contract** the next two lots consume, so it is
structured, versioned, and stable.

Candidate fields — the exact list is open question 1 of the PRD and wants David's arbitration
before the formatter is written:

| Group | Fields |
|---|---|
| Tool | version, executable path, frozen or source, Python version |
| Machine | OS and build, locale, free space on the mission folder's drive |
| DCS | version, variant (stable/openbeta), `Saved Games` path, whether the log exists and its age |
| VEAF | `VEAF_HOME`, presence of `veaf-tools.log` and its size, installed Lua module inventory |
| Recent | the last N error entries from `~/.veaf/veaf-tools.log`, already redacted |

## Redaction belongs here

The paste form is designed to be dropped into a **public** issue by someone who will not reread it.
Windows paths carry the account name (`C:\Users\Firstname Lastname\...`), and the log can carry
server addresses. Redaction is written once, in this lot, and reused by
[`FEAT-SUPPORT-LOG-ANALYSIS`](../../FEAT-SUPPORT-LOG-ANALYSIS/PRD.md) rather than reinvented there.

## Notes

- The command must work when DCS is absent — the tool runs on machines without the game.
- No `print()`: `veaf_libs.logger` only, and never `logger.error`, which raises `typer.Abort`.
- `doctor` must not fail on a missing piece; an unknown field is reported as unknown, and the rest
  is still produced. A diagnostic command that crashes on the machine being diagnosed is worthless.

## Definition of done

- [x] `veaf-tools doctor` exists, is registered in `command_tree.py` and reachable from the TUI
- [x] Two renderings: console and a paste block whose format carries a version marker
- [x] Redaction helper applied to every path and address, unit-tested against a Windows user path,
      an IPv4 address and a token-shaped string
- [x] Works with DCS absent, with `VEAF_HOME` unset, and with no log file
- [x] Unit tests for each collector, with the environment mocked
- [x] `poetry run pytest`, ruff check + format, and mypy on the shipped package all clean
- [x] `--cov-fail-under` raised to stay within ~2 points of the measured coverage
