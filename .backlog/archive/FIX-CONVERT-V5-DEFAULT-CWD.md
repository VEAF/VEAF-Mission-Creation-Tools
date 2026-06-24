# Lot FIX-CONVERT-V5-DEFAULT-CWD — `convert-v5` uses current directory by default

Status: ✅ done

**Goal**: Remove `no_args_is_help=True` from the `convert-v5` command so that invoking `veaf-tools convert-v5` with no arguments runs against the current working directory (the default `"."` already declared on `mission_folder`).

**Root cause**: `convert_v5.py:19` — `@app.command(no_args_is_help=True, ...)` overrides the `"."` default and shows help instead.

**Fix**: Change `no_args_is_help=True` → `no_args_is_help=False` (or remove the parameter entirely).

**Branch**: `fix/convert-v5-default-cwd` → PR → `develop-v6`

| # | Ticket | Files | Type | Effort | Status |
|---|--------|-------|------|--------|--------|
| CVCWD-001 | Remove `no_args_is_help=True` from `@app.command` decorator | `veaf_tools/commands/convert_v5.py` | fix | 5 min | ✅ |
