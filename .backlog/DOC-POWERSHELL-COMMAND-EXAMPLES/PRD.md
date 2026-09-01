# DOC-POWERSHELL-COMMAND-EXAMPLES — every command example in the docs fails as written

Status: ✅ done

Origin: David, 2026-09-01. Measured on `develop` the same day.

## The defect

The documentation writes `veaf-tools.exe …` in **118 places across 28 files**, and `.\veaf-tools.exe`
in **zero**. In PowerShell — the default shell on Windows, and the one a mission maker gets — the
bare form does not run:

> `veaf-tools.exe` is not recognized as a name of a cmdlet, function, script file, or executable
> program.

PowerShell does **not** search the current directory, deliberately: it is a protection against
dropping a `git.exe` in a folder and having it run instead of the real one. `cmd.exe` does search
it, which is why the habit survives and why nobody noticed.

Measured 2026-09-01 on `D:\dev\_VEAF\VEAF-Demo-Mission\veaf-tools.exe`:

| Form | PowerShell | `cmd.exe` |
|---|---|---|
| `veaf-tools.exe --help` | **fails** | works |
| `.\veaf-tools.exe --help` | works | works |

So `.\` is not the PowerShell spelling — it is the **portable** one, and the only one worth
writing.

## Why it costs more than it looks

The error names the file the reader is looking straight at, in the folder they are standing in. It
reads as "the tool is broken", not "prefix it". A newcomer following the new tutorial hits it on
their first command, and nothing on the page tells them what happened.

## What to write, beyond the prefix

Where a page **teaches** the command line rather than merely quoting one command, it must also say
that PowerShell is the default and that `cmd` differs — and explain how, briefly:

- `.\` is required in PowerShell, optional in `cmd`;
- environment variables: `$env:VEAF_LANG = "fr"` vs `set VEAF_LANG=fr`;
- line continuation: a backtick in PowerShell, a caret in `cmd`.

The tutorial and the concept cards are the pages that teach; the reference pages mostly quote.

## Definition of done

- [ ] No `veaf-tools.exe` without `.\` remains in `doc/` — check the count, it is 118 today
- [ ] Same treatment for the other shipped executables (`veaf-tools-updater.exe`,
      `ctld-tools.exe`, anything else run from a mission folder) — the defect is the habit, not the
      one binary
- [ ] The pages that teach the command line explain the PowerShell/`cmd` difference
- [ ] Both languages in step
- [ ] `poetry run docs-check` passes

## Already done, and why it is not in this lot

The rule is in `CLAUDE.md` under **Documentation** as of 2026-09-01, with the measurement. That is
the living half: a lot fixes today's 118, a rule stops the 119th. Do not remove it.

## Closing note — the 118 was two populations, not one

Re-measured while closing: the reference `grep -rhoE '(^|[^.\\/`])veaf-tools\.exe'` does **not**
exclude a preceding backslash the way its character class reads, so its 118 was **80 genuinely bare
command lines plus 38 that already carried `.\`** (the tutorial and the migration guide were
already correct). The companion `grep -rho '\.\veaf-tools\.exe'` reported zero for the opposite
reason: `\v` is not a literal `v` in a basic regular expression. Nothing about the defect changes —
80 bare lines is still 80 — but the counts to quote are the ones below.

Delivered: **120** command lines prefixed inside code fences (`veaf-tools.exe`,
`veaf-tools-updater.exe`, `veaf-logs.exe`) — 114 under `doc/`, 6 in the repository README, which
carries the same quick start and the same defect — plus **40** inline invocations in prose. The 28 bare
mentions that remain are all deliberate: 6 mermaid nodes, 12 tree-diagram lines, 6 shell comments,
2 lines of an ASCII flow diagram, and the 2 quoted error messages — which have to stay bare, they
*are* the failing form.

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Prefix every example, and explain the two shells](tickets/01-prefix-and-explain.md) | docs |

## Watch out

`.gitignore`, `.gitattributes` and prose that *names* the file rather than running it
(`the veaf-tools.exe binary`, `place veaf-tools.exe next to…`) must be left alone. Only a command
line gets the prefix — a blind replace would corrupt sentences.
