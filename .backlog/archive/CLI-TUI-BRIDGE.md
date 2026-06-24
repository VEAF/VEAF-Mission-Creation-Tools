# Lot CLI-TUI-BRIDGE — fall back to the TUI for missing options

Status: ✅ done

**Goal**: make the CLI and TUI two faces of the same flow. When a veaf-tools command is invoked **without the options it needs** (or with `--tui` on any command), drop into the TUI **at the right step**, pre-filling whatever was already given on the command line and only prompting for the rest, then run the command. Examples: `veaf-tools` → main menu; `veaf-tools prepare` → prepare's option prompts (template, path…); `veaf-tools prepare c:\tmp` → prepare's prompts **minus** the path (already supplied) → just asks the template. This supersedes prepare's interim `no_args_is_help` (bare `prepare` will enter the TUI prepare flow instead of printing help).

**Design notes / open questions (to settle when scoping)**:
- **Trigger**: `--tui` on any command (force), OR a "required" prompt for that command is missing from the CLI. Only commands that have a `CommandSpec` participate; others keep plain Typer behaviour.
- **"Provided vs default" detection**: Typer args carry defaults, so we can't natively tell "user typed it" from "default". Inspect `sys.argv` against the command's `CommandSpec.prompts` (map positional/flag tokens → `ArgPrompt.key`), in `main()` before `app()`.
- **Which prompts are "required"**: mark them on `ArgPrompt` (e.g. a `required`/`prompt_if_missing` flag) so optional flags (`--verbose`, `--force`) don't force the TUI; for `prepare`, template + folder qualify.
- **Reuse**: extend `run_wizard` to accept a target command + a set of pre-filled args and skip those prompts; `main()` routes to it.

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| CLI-TUI-BRIDGE-001 | `--tui` flag + missing-required detection routes any `CommandSpec` command into the TUI, pre-filling CLI-provided args and prompting the rest; replace prepare's `no_args_is_help`; tests; docs | `veaf_tools/app.py`, `veaf_libs/tui.py`, `veaf_tools/commands/`, `test/python/`, `doc/`, `CHANGELOG.md` | feat | ✅ |

**Done**: `maybe_bridge_to_tui()` + `_parse_provided()` added to `veaf_libs/tui.py`, called from `app.main()` before Typer dispatch; `ArgPrompt` gained `required` + `choices`; `run_wizard(preselected, provided)` skips the command-select step and any pre-filled prompt, and renders a `choices` select (used by `prepare`'s template). `prepare`'s `no_args_is_help` was **kept** as the non-TTY safety net (in a TTY the bridge rewrites argv first, so it never fires; outside a TTY a bare `prepare` still prints help rather than scaffolding the cwd). Tests in `test_tui.py` (`_parse_provided`, `maybe_bridge_to_tui`, bridge `run_wizard` paths); FR/EN docs in the mission-maker guide; coverage floor 68→69. **Review follow-up**: `GROUNDAI` now sits in `CASMISSION`'s tiers (`standard`/`full`) so the build no longer silently auto-enables an undeclared dependency. (An Escape-navigation attempt was reverted: making every prompt `mandatory=False` + binding a bare `escape` key broke the wizard on the Windows console — the first prompt skipped to `None`, so the bridge fell back to `no_args_is_help`. Escape navigation needs a terminal-tested reimplementation.)
