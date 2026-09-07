# FEAT-SUPPORT-DIAGNOSTIC — the three facts every bug report is missing

Status: ✅ done

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
| 01 | [`veaf-tools doctor` collects the facts nobody supplies](tickets/01-doctor-command.md) | feat |
| 02 | [The user log finally records stack traces](tickets/02-log-records-tracebacks.md) | fix |
| 03 | [The documentation points at the log that exists](tickets/03-doc-support-page.md) | docs |

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
