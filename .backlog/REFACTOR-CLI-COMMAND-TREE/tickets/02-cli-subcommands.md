# 02 — The CLI grows the tree, and breaks nothing

Status: ⬜ ready
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
