# 01 — Collect the lazily-resolved packages into the executable

Status: ✅ done — 2026-08-19. Fix shipped, and verified on a rebuilt `dist/veaf-tools.exe`.
Type: fix
Files: `veaf_build/worker.py`, `test/python/veaf_build/test_build_standalone.py`

## The defect, reproduced

Tripack's traceback is the reproduction; the cause is one line of PyInstaller behaviour. Running the
6.15.x executable:

```text
File "mission_builder\__init__.py", line 57, in __getattr__
ModuleNotFoundError: No module named 'mission_builder.mission_builder_README'
```

`mission_builder/__init__.py` names its submodules only inside a string table read at runtime, so
PyInstaller — which decides what to bundle by reading `import` statements — bundles none of them.
Eleven modules are missing from the executable: the seven the export table points at
(`config_migrator`, `mission_builder_README`, `mission_builder_worker`, `mission_promoter`,
`other_converter`, `v5_converter`, `v5_pipeline_converters`) and the four they import in turn
(`presets_schema_migrator`, `coalition_placeholder`, `era_detector`, `third_party_mods`).

## What ships

`--collect-submodules mission_builder`, declared as `_LAZY_PACKAGES` in `veaf_build/worker.py` next
to the other build declarations and passed through a new `collect_submodules` argument.

**A package list, not a module list**, on purpose: an export added to the table tomorrow is covered
without a build change — the same reasoning as the conversion profiles shipping as a directory.
Reverting the lazy imports was the other option and is not taken: the reason for them stands (a
library user of `ConfigMigrator` should not install pydantic), and the executable has to survive a
lazy package rather than forbid one.

Three tests, each guarding a different way to break this again:

| Test | Fails when |
|---|---|
| `test_veaf_tools_build_collects_every_lazy_package` | a package on disk resolves lazily and the build does not collect it — found by **scanning** for the `__getattr__` + `import_module` pattern, so it fires on the next package made lazy |
| `test_every_lazy_export_target_ships` | `mission_builder`'s own export table names a module the executable would not contain |
| `test_pyinstaller_command_passes_collect_submodules` | the packages are declared but never translated into PyInstaller arguments |

Verified by removing the fix and re-running: the first two fail, the third stays green (it tests the
wiring, not the list) — which is the split intended.

## Measured on the rebuilt executable

`poetry run veaf-build build-standalone --version 6.15.4`, then:

| Ran | Before | After |
|---|---|---|
| `veaf-tools.exe --help` | `ModuleNotFoundError` | the 25-command tree |
| `veaf-tools.exe about` | `ModuleNotFoundError` | the VEAF blurb |
| `veaf-tools.exe generate-config --output .` | `ModuleNotFoundError` | a 197-line `mission.yaml` |

## Done when

- [x] The rebuilt executable starts and runs a real command
- [x] A test fails if a lazily-resolved package is not collected
- [x] That test fires on a *future* lazy package, not only on `mission_builder`
- [x] The three tests verified against the un-fixed build
