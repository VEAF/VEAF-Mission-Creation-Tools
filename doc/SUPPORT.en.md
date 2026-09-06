# Getting help

Something is not working. This page says **where to report it** and **what to provide** so that
someone can answer you with something other than "which version?".

## Where to go {#where}

| Your situation | The right place |
|---|---|
| A question, a doubt, "is this normal?" | [VEAF Discord](https://www.veaf.org/discord), `#support` channel |
| Something does not work as advertised | [a GitHub issue](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/new/choose) |
| An idea, a missing feature | [a GitHub issue](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/new/choose), "feature request" form |
| A security vulnerability | **no public issue** — see [below](#security) |

Discord is fastest for a question; an issue is the only place a defect does not get lost. When in
doubt, ask on Discord: someone will tell you whether it is worth an issue.

## The documentation assistant {#assistant}

The button at the bottom right of these pages opens an assistant that answers from the
documentation. It runs on a **free allowance, shared by every visitor of the site**: on a busy day
it can run out. The assistant will say so when that happens, and say when it comes back — the
allowance refills the next morning.

Nothing is broken, and nothing is lost in the meantime: the documentation is still there, and so
are Discord and the issues. The [`veaf-tools ask`](CLI_REFERENCE.en.md#ask) command talks to the
same assistant, hence to the same allowance.

## Asking the bot: `/ask` {#ask}

On the VEAF Discord, `/ask` answers questions **about the documentation**.

```text
/ask question: how do I add a radio preset to a mission?
```

The bot opens a **public thread** under your question and writes its answer there as it comes, with
links to the pages it used.

The thread is public on purpose: the answer serves the next person who asks the same thing, and
anyone passing by can correct the bot — "no, since 6.19 it works differently". On a documentation
assistant, that is the only correction that actually catches a wrong answer.

### What to know before relying on it

- **It answers from the documentation, and from nothing else.** It does not read the code, does not
  look at your mission, does not open your log. If the documentation does not cover the subject it
  says so and points you back at this page — that is an answer, not a failure.
- **It can be wrong, or a version behind.** Check the pages it cites; that is why it cites them. If
  the answer is wrong, say so in the thread: the people around will read it.
- **A documentation gap becomes a wrong or missing answer.** The fix is to write the page, not to
  tune the bot. So a question it cannot answer is useful: report it, it is worth a documentation
  ticket.
- **There are quotas.** A few questions per minute per person, a daily limit, and a limit for the
  whole server — they protect the free allowance the website and the command line also share. When
  it refuses, it tells you why and when it resets.

### What it does **not** do

It does not read the sources and does not look at your mission. If its answer does not solve your
problem, though, the **Report a bug** button under the answer opens the [`/bug`](#bug) form with
your question and its answer already in it.

!!! tip "The same thing outside Discord"
    `.\veaf-tools.exe ask` asks the same assistant the same questions, from your own machine. See
    the [CLI Reference](CLI_REFERENCE.en.md).

## Reporting a bug from Discord: `/bug` {#bug}

On the VEAF Discord, `/bug` opens a **form**: what happened, what you expected, the steps, and the
[`veaf-tools doctor`](#doctor) block. You can attach a log, a mission, a configuration file.

**You do not need a GitHub account.** The issue is opened by a bot, on your behalf: your Discord
name is credited as the reporter, and nothing else about you.

### What the bot makes of your form

Everything below happens **without any AI** — these are reads and searches, so they are exact, and
they work when nothing else does:

- it reads the `doctor` block for the tool version, the DCS version, the operating system;
- if your text or your log contains an error, it extracts the **file and the line**, then reads the
  surrounding code in the repository;
- it reduces an 11 MB log to the excerpt that matters, with whatever its catalogue recognises in it;
- it summarises the attached mission — theatre, date, weather, group counts — without publishing its
  contents;
- it compares your problem against the open issues, the recently closed ones, the lots in progress
  and the roadmap. **If it is already fixed, it tells you and opens nothing**: that is the best
  outcome available, and you are unblocked immediately.

### Nothing is published before you click

The bot shows you the issue **as it will be filed**, then waits. Three buttons: **file**, **edit**
(the form comes back with your answers), **cancel**. If you do not click, the preview expires after
eight minutes and nothing is filed.

That matters because you typed three fields and about twenty lines are about to be published: the
log excerpt, the code, your environment. The click is where you see the difference and can say *not
that*.

**Your personal data is stripped before publication**: paths from your disk, addresses, credentials.
If that filtering cannot run, **nothing is published** — never a fallback to the raw text. One thing
escapes the filter: what you type yourself. Write your name in *what happened*, or call your mission
`mission by John Smith.miz`, and it gets published.

### What happens next

The bot opens a **public thread** and puts the issue's link in it. When somebody answers on the
issue, or when it is closed, **the bot reports it in that thread**: you do not have to watch GitHub.

The other direction is **manual**: to add something — a file you forgot, a detail — write it in the
thread and a maintainer will carry it over to the issue. The bot does not write from Discord to
GitHub, deliberately: that would open a write channel onto a public repository from a room anybody
can join.

### The automatic hypothesis

On issues filed by a **VEAF member**, and while the day's allowance lasts, a model adds a
**hypothesis** about the cause: a separate comment, labelled as a machine's guess, naming the
suspected file and line.

It is not a diagnosis, and **its absence takes nothing away from your report**: everything else in
the issue is measured, quoted or parsed, never guessed. When it is missing, the issue says why.

## What to provide {#what-to-provide}

Useful reports all look alike. Three things, in this order:

1. **What you did, what you expected, what happened.** Three sentences are enough as long as they
   are concrete: "I ran `.\veaf-tools.exe build`, I expected a `.miz`, I got a red error".
2. **The `doctor` block** (below). It carries the versions and the paths — exactly what is almost
   always missing.
3. **The files**, if you have them: the DCS log, the mission, a screenshot.

## Running `doctor` {#doctor}

From the folder holding the executable:

```powershell
.\veaf-tools.exe doctor
```

!!! note "Why `.\`"
    PowerShell — the default Windows command prompt — does **not** look for programs in the current
    folder. Without the `.\` it answers that the command does not exist, while the file is plainly
    right there. In `cmd.exe` the `.\` is optional but accepted, so it is the form worth writing
    everywhere.

The command first prints a readable table, then a block delimited by
`=== VEAF-TOOLS DOCTOR BEGIN ===`. **That block is what you copy** into your Discord message or
your issue, as-is.

It is built to be published: your Windows account name is replaced by `<user>` everywhere it
appears, IP addresses by `<ip>`, e-mail addresses by `<email>`, and passwords and tokens by
`<redacted>`.

What is **kept** is the name of your missions, aircraft and payloads: those are what say *what* it
broke on, and hiding them would leave a report that says only "it did not work". If one of those
names looks sensitive to you, glance at the block before pasting it — it is plain text, you can edit
it.

To get only the block, without the table:

```powershell
.\veaf-tools.exe doctor --paste
```

## Where the logs are {#logs}

There are two, and they do not say the same thing.

| Log | Where | What it holds |
|---|---|---|
| Tool log | `%USERPROFILE%\.veaf\veaf-tools.log` | what `veaf-tools.exe` did on your machine: conversion, build, injection, and the full stack trace of any error |
| DCS log | `%USERPROFILE%\Saved Games\DCS\Logs\dcs.log` | what happened **in game**: script loading, Lua errors, VEAF module behaviour |

If you set the `VEAF_HOME` environment variable, the tool log is written there rather than in
`.veaf`. The `doctor` table gives you its exact path — the safest answer, since it comes from the
machine itself.

The tool log is **trimmed automatically**: it rolls over at 2 MB, and three older files are kept
beside it (`veaf-tools.log.1`, `.2`, `.3`). `doctor` looks for recent errors in those too: just
after a rollover the live log is nearly empty and the whole history sits in `.1`.

For the DCS log, [`veaf-logs`](mission-maker/LOGS.en.md) opens it and shows only what matters; the
raw file is often over 10 MB, which is neither readable nor sendable as-is.

## When it is DCS that is wrong {#dcs-trouble}

If the problem is in game — a mission that will not load, a module refusing to start, a missing VEAF
menu — `veaf-logs` can also **explain** what it reads, and prepare a ready-made report block. See
[DCS is misbehaving](pilot/dcs-trouble.en.md), written for someone who has never run a VEAF command.

## Reporting a security vulnerability {#security}

**Do not open a public issue.** Use
[GitHub's private reporting](https://github.com/VEAF/VEAF-Mission-Creation-Tools/security/advisories/new),
which keeps the report confidential until a fix is released. The full policy is in
[`SECURITY.md`](https://github.com/VEAF/VEAF-Mission-Creation-Tools/blob/develop/SECURITY.md).

## Going further

- [CLI Reference](CLI_REFERENCE.en.md) — every command and its options
- [Updater & release tools](TOOLS_REFERENCE.en.md) — troubleshooting `veaf-tools-updater.exe`
- [Read the DCS logs](mission-maker/LOGS.en.md) — the `veaf-logs` tool
