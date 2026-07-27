# Lot FIX-TUI-MISSING-COMMANDS — every CLI command must appear in the interactive TUI

Status: ✅ done

**Goal**: 4 of the 17 `veaf-tools` commands have **no `CommandSpec`** in [tui.py](src/python/veaf-tools/veaf_libs/tui.py) (`COMMANDS` list), so they are absent from the interactive wizard menu **and** from the CLI↔TUI bridge: `validate`, `migrate-config`, `generate-config`, `user-config`. A user who double-clicks `veaf-tools.exe` (TUI mode) cannot reach them — e.g. can't run `validate` interactively (reported by David). The TUI must expose **all** commands.

Confirmed by audit (vs the 13 already covered). Clarifications from David:
1. **All** commands belong in the TUI menu (even those without mandatory args — they're still launchable from the menu, like `about`).
2. The **CLI→TUI bridge** (auto-drop into the wizard when an arg is missing) only concerns commands with a **mandatory** argument. Among the 4, only `migrate-config` has one (`input_file`, a `typer.Argument(...)` with no default) → its `ArgPrompt` gets `required=True`. `validate` (`mission_folder` default `.`), `generate-config` (options only), `user-config` (options only) get no `required=True`.

Signatures (for the specs):
- `validate`: positional `mission_folder` (default `.`) + `--strict` flag.
- `migrate-config`: positional `input_file` (**required**) + `--output` / `--yaml-output` options.
- `generate-config`: `--output` option (no positional).
- `user-config`: `--set` / `--unset` / `--init` options (no positional).

**Branch**: `fix/tui-missing-commands` → PR → `develop` (Python TUI only).

| # | Ticket | Files | Type | Status |
|---|--------|-------|------|--------|
| FIX-TUI-MISSING-COMMANDS-001 | Add a `CommandSpec` for `validate`, `migrate-config`, `generate-config`, `user-config` in `COMMANDS`, with their primary `ArgPrompt`s and `required=True` only on `migrate-config.input_file`. Add the FR/EN i18n labels (`tui.cmd.*.description`, new `tui.arg.*`). | `veaf_libs/tui.py`, `veaf_libs/locales/{en,fr}.json` | fix | ✅ (#513) |
| FIX-TUI-MISSING-COMMANDS-002 | Guard test: assert that **every** Typer command registered on `app` has a matching `CommandSpec` in `COMMANDS` (would have caught the missing 4). Extend `test_tui.py`. | `test/python/veaf_libs/test_tui.py` | test | ✅ (#513) |
