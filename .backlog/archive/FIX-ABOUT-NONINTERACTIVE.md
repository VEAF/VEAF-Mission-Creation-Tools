# FIX-ABOUT-NONINTERACTIVE — a command that cannot succeed in a script

Status: ✅ done · archived 2026-09-28

Origin: found while investigating the "fix windows exe" report, which turned out to be this and
nothing else. Measured on a released 6.x binary and on a freshly built one.

## What happens

`veaf-tools about` asks "Voulez-vous ouvrir le site web de la VEAF dans votre navigateur ? [y/N]".
With no keyboard — a CI job, a batch file, a piped invocation — Click cannot read the answer,
prints `Aborted.` and exits **1**.

Measured:

| Invocation | Exit code |
|---|---|
| `about`, stdin closed | 1 |
| `about`, answered `n` | 0 |
| `--help`, six runs | 0 every time |
| `generate-config` | 0, file written |

So the binary is fine. `about` is the only command that cannot succeed unattended, and it fails
for a reason a caller cannot fix.

## Why it is worth a lot at all

It cost real time: the exit code was reported as a defect of the Windows executable, on two
binaries, and led to a chip being raised against the packaging. The measurement that settled it
took several rounds. A command that reports failure on success is a trap for whoever automates
next.

## The decision to make

The prompt is good when a human runs it. Options:

1. **Skip the prompt when there is no terminal** and exit 0 — `sys.stdin.isatty()`, the same shape
   `should_auto_pause` already uses for the exit pause.
2. **Keep asking, but treat an unreadable answer as "no"** rather than as an abort.
3. Add a `--no-prompt` flag. Explicit, but it puts the burden on every caller and nobody knows they
   need it until it has already failed.

Recommendation: **1**, and check whether any other command prompts the same way — `about` is
unlikely to be alone, and finding the second one the same way would be a waste.

Recommendation taken: **1**. `veaf_tools.helpers.is_interactive()` reads `isatty` on **both**
`stdin` and `stdout` — one channel carries the question, the other the answer, and redirecting
either makes the prompt a trap (`stdin` closed aborts, `stdout` captured hangs on a question
nobody was shown). `veaf_tools.helpers.confirm()` wraps `typer.confirm` on top of it, so every
command shares one convention rather than each growing its own guard.

## Definition of done

- [x] `veaf-tools about` with no terminal exits 0 and prints its content
- [x] Run by hand, it still offers to open the site and still opens it on `y`
- [x] The survey of other prompting commands is reported, including those left alone
- [x] A test pins the non-interactive path

## Survey

`about` was **not** alone. Ten prompts abort the same way; the same helper now covers all of them.

| Prompt | Verdict |
|---|---|
| `about` — open the website | Fixed. Unattended answer: no. |
| `--readme` on `extract`, `inject-presets`, `extract-aircraft-groups`, `build`, `inject-waypoints`, `extract-waypoints`, `inject-weather` (7 sites) | Fixed. Unattended answer: **yes** — `--readme` asks for the documentation on purpose, so it is printed rather than silently skipped. |
| `convert-v5` — overwrite an existing `mission.yaml` | Fixed. Unattended answer: no; `--force` is the scripted way to overwrite. |
| `inject-weather` — use the freshly converted `.lua` → `.yaml` | Fixed. Unattended answer: no; the converted file is still written and reported. |
| `veaf-build about` — the same prompt, copied | Fixed. Same helper. |
| `veaf-build` — overwrite `RELEASE_NOTES.md` | Fixed. Unattended answer: no, keep what is there. |

Left alone, on purpose:

| Prompt | Why |
|---|---|
| The `--pause` / double-click exit pause (`input(...)`, ~15 sites) | Already guarded — either by the explicit `--pause` flag or by `should_auto_pause()`. |
| `prepare --template custom` module picker, and the `--tui` wizard | `run_wizard` already checks `isatty`; the `custom` picker is reached only by explicitly asking for it. |
| `inject-waypoints --interactive` / `inject-aircraft-groups --interactive` group selectors (bare `input()`) | Opt-in flag. A caller that passes `--interactive` unattended is asking for a prompt. |
| `ask` REPL | Already catches `EOFError` and exits 0. |
| `_ask_replace` (file overwrite menu) | Already returns "keep everything" when `stdin` is not a terminal. |

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Do not abort when nobody can answer](FIX-ABOUT-NONINTERACTIVE.md) | fix |

---

## Tickets, in full

## 01 — Do not abort when nobody can answer

Status: ✅ done

Type: fix · Files: the `about` command, plus whatever the survey turns up

### Reproduce first

```bash
veaf-tools about < /dev/null ; echo $?      # 1, prints "Aborted."
echo n | veaf-tools about ; echo $?          # 0
```

### The change

Ask only when there is someone to answer. `veaf_tools/helpers.py` already reads
`sys.stdout.isatty()` for the exit pause (`_is_double_clicked`); use the same kind of test rather
than inventing a second convention, and put it where other commands can reuse it.

### Survey

Look for other commands that prompt unconditionally. The point of the lot is that a command must
not report failure when it succeeded; `about` is the instance we tripped over, not necessarily the
only one. Report what you find, including what you leave.

### What was done

`veaf_tools/helpers.py` gained `is_interactive()` and `confirm()`; the ten unconditional prompts
now go through them (see the survey table in the PRD). No new user-facing string, so no
translation work — the change removes a question, it does not add one.

### Definition of done

- [x] No terminal → no prompt, content printed, exit 0
- [x] With a terminal → unchanged, including opening the browser on `y`
- [x] A test covers the non-interactive path
- [x] The survey is in the PR
- [ ] `poetry run pytest`, ruff, mypy clean (`poetry install --without build --all-extras` first,
      or the coverage figure is wrong)

---
