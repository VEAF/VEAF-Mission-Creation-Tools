# 05 — Stop pulling pydantic into the migrator

Status: ⬜ ready

Issue: [#725](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/725) (Sharko's closing
note) · Type: refactor · File: `src/python/veaf-tools/veaf_libs/lua_config_generator.py`

## Measured, not deduced

```
$ python -c "import sys; from mission_builder.config_migrator import ConfigMigrator; \
             print('pydantic loaded:', 'pydantic' in sys.modules)"
pydantic loaded: True
```

The chain: `config_migrator.py:19` imports `veaf_libs.lua_config_generator`, which at `:28` imports
`veaf_libs.checklists`, which at `:29` imports pydantic. Since 6.14.0, importing the **config
migrator** loads the **guided-checklist model**.

Note that `config_migrator` does not import `checklists` itself — a grep of its imports says
`i18n`, `lua_config_generator`, `lua_module_scanner` and nothing else, which is why the report's
phrasing ("the migrator imports `veaf_libs.checklists`") reads as wrong until you follow the second
hop. The coupling is real; it just lives one level down.

## Why bother

Inside the packaged environment this costs nothing — pydantic is a project dependency. It costs
someone importing `ConfigMigrator` as a library, where `typer` + `pyyaml` used to be enough. That
someone is Sharko, whose two measurement harnesses are the acceptance test for this whole lot, and
more generally anyone building tooling on our converter. A cockpit-checklist model has no business
being on that path.

## What to do

`config_migrator` needs exactly one thing from `lua_config_generator`: `yaml_module_entry`. Two
routes, pick by looking at the file:

- defer `lua_config_generator`'s `checklists` import into the function(s) that use it, or
- move `yaml_module_entry` to a module that carries no heavy dependency.

The second is cleaner if `yaml_module_entry` is a small formatting helper — check what else imports
it before moving it, since the win is not worth breaking three call sites.

## Test

A test asserting `pydantic` is **absent** from `sys.modules` after importing `ConfigMigrator`, run
in a fresh interpreter — a test that imports it in a process where something else already pulled
pydantic in passes for the wrong reason and would pin nothing. `subprocess` with `-c`, asserting on
the exit code, is the honest form.
