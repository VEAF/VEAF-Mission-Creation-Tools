# 02 — The CLI grows the tree, and breaks nothing

Status: ✅ done — 2026-08-10
Type: refactor
Files: `src/python/veaf-tools/veaf_tools/app.py`, `veaf_tools/commands/*.py`

## What it looks like afterwards

```
veaf-tools --help          ->  mission · convert · content · cockpit · dcs · about · ask · user-config · mcp
veaf-tools mission --help  ->  prepare · validate · build · extract · export
veaf-tools mission build   ->  runs
veaf-tools build           ->  runs, exactly as today, absent from every --help
```

## Tasks

- [ ] One `typer.Typer` per group, added to the root app with the group's label and description from
      ticket 01's module.
- [ ] Register each command **twice**: once under its group, once at the root with `hidden=True`.
      Verified available in Typer 0.24.1. One registration helper doing both, driven by the tree —
      not 25 hand-written pairs, which is how one gets forgotten.
- [ ] The CLI ↔ TUI bridge (`maybe_bridge_to_tui`, `app.py:66`) parses `sys.argv[1:]` to decide
      whether a command was invoked without a required option. It must accept **both** forms, and
      the two-token form must not be read as "a command plus a positional argument". This is the
      one place where the change is not mechanical — treat it as the risk of the ticket.
- [ ] Tests: the grouped form runs, the flat form runs, the flat form is absent from `--help`, and
      the bridge triggers identically for both.

## Watch out

`should_auto_pause()` and the double-click path exist so a mission maker can run the `.exe` with no
terminal. Whatever argv shape that produces has to keep working — check it rather than assume, since
nobody is going to report it broken until a release is out.

## Done

`build_cli_tree` reshapes the flat registrations: one `typer.Typer` per group, and each command also
left registered at the root with `hidden=True`. Driven by the tree rather than 25 hand-written pairs.
Both forms were run for real and produce identical output.

**The flagged risk was real.** `maybe_bridge_to_tui` took `tokens[0]` as the command, so
`veaf-tools mission build` made it see `mission`, find no `CommandSpec`, and let Typer run a command
that might be missing a required option — precisely the case the bridge exists to catch. It now
recognises a group id as the first token. A test asserts no group id is also a command name, since a
collision would make one of the two unreachable and the bridge would guess wrong.

**Two cosmetic limits, stated rather than fought.** Click sorts a group's commands alphabetically, so
`--help` shows `build, export, extract, prepare, validate` where the tree says
`prepare, validate, build, extract, export`; overriding it means a custom Group class for no
functional gain, and a five-entry reference panel is arguably better alphabetical. The wizard, which
is read top to bottom, does honour the tree order — that was a real bug, found by calling the real
renderer instead of re-implementing its loop in a probe. And Typer renders root commands before
sub-apps, so the two are split into named help panels rather than reordered.

**The stutter was fixed straight after, and my reasoning for deferring it was wrong.** I called
`convert v5` "a rename, which this lot rules out". Two facts I should have checked first: the
published version is 6.13.0, so the tree had never shipped and nobody could ever have typed
`convert convert-v5`; and the flat `convert-v5` stays registered at the root as a hidden alias
regardless of what the group calls it. So it cost nothing — and after a release it would have been a
genuinely breaking rename.

It was also not the one line I claimed. The wizard looks commands up by canonical name, so the
bridge has to map `other` back to `convert-other` — a command with **two required arguments**, which
is precisely when someone needs the wizard rather than Typer's help screen. `in_group_name` and
`resolve_command` live together in the tree module so the two directions cannot drift.
