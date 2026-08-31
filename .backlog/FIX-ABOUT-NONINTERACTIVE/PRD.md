# FIX-ABOUT-NONINTERACTIVE — a command that cannot succeed in a script

Status: ⬜ ready

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

## Definition of done

- [ ] `veaf-tools about` with no terminal exits 0 and prints its content
- [ ] Run by hand, it still offers to open the site and still opens it on `y`
- [ ] The survey of other prompting commands is reported, including those left alone
- [ ] A test pins the non-interactive path

## Scope

| # | Ticket | Type |
|---|--------|------|
| 01 | [Do not abort when nobody can answer](tickets/01-no-abort-without-terminal.md) | fix |
