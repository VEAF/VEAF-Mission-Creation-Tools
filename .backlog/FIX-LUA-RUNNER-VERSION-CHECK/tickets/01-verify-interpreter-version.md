# 01 — verify the interpreter version instead of taking the first `lua` on PATH

Status: ✅ done

## Context

`_find_lua()` returned the first name that `shutil.which` resolved, in the order `lua5.1`, `lua`.
Nothing asked what version that was. A scoop-provided `lua` is 5.4, and the suite then failed in
34 places for reasons that have nothing to do with the VEAF code.

## Work

In `veaf_build/lua_tests.py`:

- `_lua_version_banner(executable)` runs `<exe> -v` and returns the combined stdout/stderr banner
  (5.1 prints it on **stderr**, later versions on stdout — both are read), or `""` when the
  executable cannot be run. `stdin=subprocess.DEVNULL` and a timeout so a non-Lua binary on the
  name cannot hang the runner.
- `_find_lua()` collects the candidates that exist (`lua5.1`, `lua51`, `lua`, plus the Windows
  fallback path), version-checks each, and returns the first reporting Lua 5.1.
- When none does, `typer.BadParameter` carries the list of what *was* found with its banner, why a
  5.2+ interpreter is refused, and the install command per platform.

`lua51` is new in the list: it is the shim `scoop install lua51` creates alongside `lua`, and the
one still pointing at 5.1 when another Lua is also installed.

## Tests

`test/python/veaf_build/test_lua_interpreter_check.py` — 5.1 accepted, 5.4 refused with a message
naming what it found, a 5.1 candidate preferred over a 5.4 `lua`, the empty-PATH case, the Windows
fallback version-checked, and an unrunnable candidate rejected rather than raising.
