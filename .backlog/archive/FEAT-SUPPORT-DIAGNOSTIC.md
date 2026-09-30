# FEAT-SUPPORT-DIAGNOSTIC — the three facts every bug report is missing

Status: ✅ done · archived 2026-09-28

Origin: design session of 2026-09-05, David's idea of a Discord assistant that answers on the
documentation, guides a bug report and opens the issue itself. The session split that idea into
**five lots**, and this one comes first because it is the only piece that keeps its value even if
the bot is never built.

## The programme this belongs to

| Order | Lot | Where it runs |
|-------|-----|---------------|
| **1** | `FEAT-SUPPORT-DIAGNOSTIC` — this one | the user's machine |
| 2 | [`FEAT-SUPPORT-LOG-ANALYSIS`](FEAT-SUPPORT-LOG-ANALYSIS.md) | the user's machine |
| 3 | [`FEAT-SUPPORT-DISCORD-QA`](FEAT-SUPPORT-DISCORD-QA.md) | Worker + service |
| 4 | [`FEAT-SUPPORT-BUG-INTAKE`](FEAT-SUPPORT-BUG-INTAKE.md) | service |
| 5 | [`FEAT-SUPPORT-SUGGESTIONS`](FEAT-SUPPORT-SUGGESTIONS.md) | service |

Two principles hold the programme together, and they are decisions, not preferences: **the free
tier carries the volume, and depth is rationed rather than bought**; and **the user's machine produces
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

Both were answered by the implementation rather than left blocking, and **both remain open to
revision** — the field list and the DCS-version source are cheap to change while nothing consumes
the block yet, and expensive once lots 2 and 4 read it.

1. **The exact field list of `doctor`.** Shipped as the ticket's candidate table, one key per fact,
   17 in all: `schema`, `generated`, four `tool.*`, three `machine.*`, five `dcs.*`, three `veaf.*`,
   plus the recent-error records in their own delimited section. Dropped from the candidate list:
   nothing. Added: `schema` and `generated`, without which a consumer cannot tell which format it is
   reading or how stale the report is. The order is `FIELD_ORDER` in `veaf_libs/diagnostics.py` and
   the full table is in `doc/developer/diagnostic-block.md`.
2. **How the DCS version is read.** From the **header of `dcs.log`**, not the install directory.
   DCS states itself once, on the sixth line, as `DCS/2.9.29.27278 (x86_64; MT; Windows NT …)` —
   measured on a real log, 2026-09-05. That works for every install layout and needs no guess about
   where the game was put; the install directory would need one. Which write folder to read is
   decided by **the freshest `dcs.log`** among `Saved Games/DCS*` folders that actually hold one —
   a machine carries `DCS` beside `DCS.openbeta` and the per-module folders the updater leaves
   behind (`DCS_F14`, `DCS.C130J`), and only the ones with a log are installs. DCS absent reports
   `dcs.detected: no` and four `unknown`s, and nothing else in the report is affected.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [`veaf-tools doctor` collects the facts nobody supplies](FEAT-SUPPORT-DIAGNOSTIC.md) | feat |
| 02 | [The user log finally records stack traces](FEAT-SUPPORT-DIAGNOSTIC.md) | fix |
| 03 | [The documentation points at the log that exists](FEAT-SUPPORT-DIAGNOSTIC.md) | docs |

## What shipped

- `veaf-tools doctor`, at the root of the command tree and in the wizard, with two renderings: a
  table, and a delimited block carrying `schema: veaf-tools-doctor/1`.
- `veaf_libs/redaction.py` — written once here, reused by lots 2 and 4 rather than reinvented.
  Account names, e-mail addresses, credentials and routable IPv4 addresses go; loopback stays,
  because it is diagnostic and carries nothing.
- `veaf_libs/diagnostics.py` — the collectors, the block writer and **its parser**, side by side so
  the two halves cannot drift, with a round-trip test over the whole field set.
- The log file now records stack traces (`exception()` passes `exc_info`), journals an uncaught
  exception through a `sys.excepthook` installed in `main()` before it reaches stderr, and rotates
  at 2 MB keeping three older files. Console output is unchanged, asserted by test.
- `doc/SUPPORT.md` / `.en.md` in the nav, `doc/developer/diagnostic-block.md` / `.en.md` for the
  contract, `doctor` in `CLI_REFERENCE`, and the two wrong log paths in `TOOLS_REFERENCE` corrected
  in both languages.

Two things the tickets did not ask for and the machine made necessary: a **per-line length cap** on
the error records (a real record ran past 400 characters on one line, which line-capping alone would
not have bounded), and a byte-count that reads in MB (the log measured **87 MB** on David's machine,
which is the same fact that made rotation urgent rather than tidy).

## What the review corrected

Six findings on PR #913, four of them serious, all measured against the real machine rather than
against fixtures. They are worth keeping because each one names a rule of thumb that failed.

| # | Finding | What it cost, measured |
|---|---|---|
| 1 | The entropy rule redacted DCS identifiers, not secrets | 74 substitutions and **0 credentials** over 1489 real `ERROR` records; 169 GUIDs and 493 identifiers in the repository's own data. `unknown payload <redacted>`. Now 0 / 0. |
| 2 | The account name survived outside a home path | 56 survivals in the same records (`Temp\pytest-of-<name>`), on lines already redacted three segments earlier. Now 0. |
| 3 | Rotation failed loudly and lost the record on Windows | 3 records out of 3 dropped and 4 KB of traceback on **stderr** with a second handle held — a mode `FileHandler` did not have, introduced by this lot. Now 3/3 written, 0 bytes on stderr. |
| 4 | The first rollover hid the history from `doctor` | 1 record returned instead of 5; on a real 87 MB log the first support conversation would have shown "no recent errors" to someone reporting a crash. |
| 5 | Pattern false negatives | IPv6, `access_token=`, `client_secret=`, JSON `"token": "…"`, an address ending a sentence, `127.0.1.1`, and `DCS/2.9.10.1` read as an IP address. |
| 6 | The block's value contract | A multi-line value re-parsed as two fields, one of them forged — the parser being the trust boundary of `FEAT-SUPPORT-BUG-INTAKE`. |

The guard that should have caught the first one, `test_a_module_name_is_not_mistaken_for_a_secret`,
asserted on a 17-character string with no digit: it could not fail whatever the rule did. It is
replaced by an **enumerated sweep** over every identifier of that shape the repository actually
contains — the `test_defaultSpawnRadii` lesson, applied to a family rather than to a sample.

---

## Tickets, in full

## 01 — `veaf-tools doctor` collects the facts nobody supplies

Status: ✅ done

Type: feat

### The problem

Every bug report is missing the same three things: which version of the tool, which version of DCS,
and how to reproduce. The first two are mechanical facts sitting on the user's machine; the tool
just never reads them out. There is no diagnostic command among the 22 in
`src/python/veaf-tools/veaf_tools/commands/`, and no `--version` on the root callback
([`app.py:34`](../../src/python/veaf-tools/veaf_tools/app.py) exposes only `--lang`).

`about --modules` is the closest thing today, and it covers only the embedded Lua modules — not the
OS, not DCS, not the paths, not the recent errors.

### What it produces

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

### Redaction belongs here

The paste form is designed to be dropped into a **public** issue by someone who will not reread it.
Windows paths carry the account name (`C:\Users\Firstname Lastname\...`), and the log can carry
server addresses. Redaction is written once, in this lot, and reused by
[`FEAT-SUPPORT-LOG-ANALYSIS`](FEAT-SUPPORT-LOG-ANALYSIS.md) rather than reinvented there.

### Notes

- The command must work when DCS is absent — the tool runs on machines without the game.
- No `print()`: `veaf_libs.logger` only, and never `logger.error`, which raises `typer.Abort`.
- `doctor` must not fail on a missing piece; an unknown field is reported as unknown, and the rest
  is still produced. A diagnostic command that crashes on the machine being diagnosed is worthless.

### Definition of done

- [x] `veaf-tools doctor` exists, is registered in `command_tree.py` and reachable from the TUI
- [x] Two renderings: console and a paste block whose format carries a version marker
- [x] Redaction helper applied to every path and address, unit-tested against a Windows user path,
      an IPv4 address and a token-shaped string
- [x] Works with DCS absent, with `VEAF_HOME` unset, and with no log file
- [x] Unit tests for each collector, with the environment mocked
- [x] `poetry run pytest`, ruff check + format, and mypy on the shipped package all clean
- [x] `--cov-fail-under` raised to stay within ~2 points of the measured coverage

---

## 02 — The user log finally records stack traces

Status: ✅ done

Type: fix

### The problem

`veaf_libs.logger.exception(e)` calls `error(str(e), exception_type=type(e))`
([`logger.py:103`](../../src/python/veaf-tools/veaf_libs/logger.py)) — no `exc_info`, so **the
stack trace is never written to the file**. The log records that something failed and loses the
only part that says where.

The file itself is `~/.veaf/veaf-tools.log` (or `$VEAF_HOME/veaf-tools.log`), resolved through
`get_veaf_home()` ([`logger.py:49`](../../src/python/veaf-tools/veaf_libs/logger.py)), appended
to for ever with no rotation.

An uncaught exception is not journalled at all: `app()` is wrapped in `try/finally` with no
`except` ([`app.py:80`](../../src/python/veaf-tools/veaf_tools/app.py)), and there is no
`sys.excepthook` anywhere in `src/python/`. The user sees a raw traceback on stderr, which scrolls
away, and the log keeps no trace of the crash that just happened.

### What changes

Three things, all in the file sink — the console output must not move:

1. `exception()` writes the traceback to the file.
2. A last-resort handler journals an uncaught exception before it reaches the terminal, so a crash
   leaves something behind for `doctor` to find.
3. Rotation, so the file that gets read back stays a sane size. Its absence is why nobody looks at
   it today.

### Why it belongs before the assistant

[Ticket 01](FEAT-SUPPORT-DIAGNOSTIC.md) reads the last errors out of this file. Right now that returns
one-line messages with no location — which is exactly the material a support assistant cannot do
anything with either.

### Definition of done

- [x] `exception()` writes the full traceback to the log file
- [x] An uncaught exception is journalled before the process dies, and the user still sees what they
      see today on the console
- [x] Rotation in place, with a documented size and retention
- [x] Console output byte-identical to before on a representative command — asserted by a test, not
      by reading
- [x] Unit tests covering: an exception with a cause chain, an uncaught exception, and rotation
      firing
- [x] `poetry run pytest`, ruff check + format, mypy clean

---

## 03 — The documentation points at the log that exists

Status: ✅ done

Type: docs

### The problem

Two defects, one small and one structural.

**The path is wrong.** [`doc/TOOLS_REFERENCE.md:626`](../../doc/TOOLS_REFERENCE.md) and `:816`
(and their `.en.md` twins) tell the user to look for `veaf-tools.log` *in the current directory*.
It is written to `~/.veaf/veaf-tools.log`, through `get_veaf_home()`. Someone following the page
finds nothing and concludes there is no log.

**There is no page about getting help.** The subject is scattered across three places, none of them
saying what to provide:

| Where | What it says |
|---|---|
| [`doc/index.md:96`](../../doc/index.md) | three links — Discord, GitHub issues, the VEAF site |
| [`doc/pilot/GUIDE.md:387`](../../doc/pilot/GUIDE.md) | the same links again |
| [`doc/TOOLS_REFERENCE.md:810`](../../doc/TOOLS_REFERENCE.md) | a real procedure, but only for `veaf-tools-updater.exe` |

`SECURITY.md` is the only file in the repository that says what a report should contain — and it
covers vulnerabilities only.

The debug-logging section of [`doc/mission-maker/GUIDE.md:993`](../../doc/mission-maker/GUIDE.md)
explains where the DCS log lives and how to raise the log level, but never says to attach it to a
report.

### What to write

A support page, in both languages and in the `nav`, that answers one question: *something is wrong,
what do I do?* It routes to the right place (Discord for a question, an issue for a defect, the
security channel for a vulnerability), tells the reader to run `doctor` and paste its block, and
says where both logs live — the tool's and DCS's.

This is also the page the Discord bot will link to, so it must exist before
[`FEAT-SUPPORT-DISCORD-QA`](FEAT-SUPPORT-DISCORD-QA.md).

### Notes

- Explicit English anchors on any section linked from elsewhere — `## Obtenir de l'aide {#support}`
  / `## Getting help {#support}`.
- Command examples in PowerShell, always written `.\veaf-tools.exe`.
- No hand-written version numbers.

### Definition of done

- [x] The two wrong log paths in `TOOLS_REFERENCE` corrected, FR and EN
- [x] A support page shipped as `page.md` **and** `page.en.md`, both in the `mkdocs.yml` `nav` with
      their `nav_translations` entry
- [x] It covers: which channel for what, `doctor`, where the two logs are, what to attach
- [x] Linked from `doc/index.md` and from the pilot guide, both languages
- [x] `poetry run docs-check` passes

---
