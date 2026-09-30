# FIX-EXE-LAZY-PACKAGE-IMPORTS — the 6.15 executable dies on its first command

Status: ✅ done — 2026-08-19, both tickets · archived 2026-09-28

Origin: Tripack, 2026-08-19, after updating a mission folder to 6.15. Running `veaf-tools.exe`
produces a traceback and nothing else:

```text
File "veaf_tools\commands\build.py", line 8, in <module>
File "mission_builder\__init__.py", line 57, in __getattr__
ModuleNotFoundError: No module named 'mission_builder.mission_builder_README'
[PYI-23608:ERROR] Failed to execute script 'veaf-tools' due to unhandled exception!
```

## The defect

`mission_builder` resolves its exports **lazily** since #757 (`feat(convert-v5): carry what v6 can
express`, in **6.15.0**, merged 2026-08-17). Its `__init__.py` holds a name → submodule table and
imports the target on first attribute access:

```python
_EXPORTS: dict[str, str] = {..., "MissionBuilderREADME": ".mission_builder_README", ...}

def __getattr__(name: str) -> Any:
    module = _EXPORTS.get(name)
    ...
    return getattr(import_module(module, __name__), name)
```

That is a good change for library users — importing `ConfigMigrator` no longer pulls pydantic — and
it is invisible from a checkout, where Python resolves the import at runtime.

**PyInstaller resolves imports statically.** It reads `import` statements to decide what to bundle.
A lazy package has none, so `from mission_builder import MissionBuilderREADME`
(`veaf_tools/commands/build.py:8`) makes it bundle the `__init__.py` and **not one** of the seven
submodules that table can hand out — nor, by cascade, the four they import in turn.

## Who it hurts

**Everyone on 6.15.x, for every command.** `veaf_tools/commands/build.py` is imported when the CLI
assembles its command tree, so the failure happens before argument parsing: `build`, `convert-v5`,
`prepare`, `--help` — all of them die the same way. The executable has never worked in the 6.15
line; 6.15.0 shipped on 2026-08-17 and nothing in the suite noticed, because every test runs from
the checkout.

The tooling is *only* distributed as this executable. A mission maker who updated has no working
tool at all, and no workaround short of reverting to 6.14.

## Scope

Restore the executable and make the blind spot testable. Deliberately **not** in scope: reverting
#757's lazy imports — the exe has to survive a lazy package, since the reason for laziness stands.

## The question this lot should answer beyond itself

Every test in the suite runs from the checkout, where an import that PyInstaller cannot see resolves
perfectly. So the whole class of *works from source, broken in the exe* defects is invisible to us,
and it has now bitten three times: the conversion profiles (`unknown conversion profile: foothold`),
`third_party_mods.json`, and this. Each was fixed by adding one entry to the build, guarded by one
test asserting that entry — a test per incident, no test for the family.

Is there a check that the executable **can start**? A smoke run of the built binary (`--help`, and
one command per module group) would have caught all three, and it is the only kind of test that can:
the packaged import graph is not observable from a checkout. Answer it in writing here — including
"no, and here is why" — rather than adding a fourth entry-and-test pair.

## The question, answered — 2026-08-19

**No, nothing checked it, and nothing in the suite could.** A checkout resolves every import
PyInstaller misses, so the packaged import graph is unobservable from where all our tests run. The
answer is therefore not a better unit test but running the artefact: the `exe-smoke` job builds the
binary and runs `--help` (which imports every command module) plus one real command that writes a
file. It would have caught all three defects to date.

Ticket 01's guards are kept even so, because they fail in **seconds on a developer's machine** and
name the missing module, where the smoke job fails in minutes on a runner with a traceback. They are
the fast path; the smoke job is the one that does not need to know the defect in advance.

Its limits are stated in ticket 02 rather than left to be discovered: it runs on Linux, so a
Windows-only packaging defect still gets through, and it executes two commands out of 25, so a data
file used by a third command only — the shape of the conversion-profiles defect — is still uncovered
until that command is smoked.

## Definition of done

- [x] The built `veaf-tools` executable starts and runs a real command
- [x] A test fails if a lazily-resolved package is not collected into the executable
- [x] The guard fires on the *next* package made lazy, not only on `mission_builder`
- [x] The question above answered in writing, whatever the answer

---

## Tickets, in full

## 01 — Collect the lazily-resolved packages into the executable

Status: ✅ done — 2026-08-19. Fix shipped, and verified on a rebuilt `dist/veaf-tools.exe`.
Type: fix
Files: `veaf_build/worker.py`, `test/python/veaf_build/test_build_standalone.py`

### The defect, reproduced

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

### What ships

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

### Measured on the rebuilt executable

`poetry run veaf-build build-standalone --version 6.15.4`, then:

| Ran | Before | After |
|---|---|---|
| `veaf-tools.exe --help` | `ModuleNotFoundError` | the 25-command tree |
| `veaf-tools.exe about` | `ModuleNotFoundError` | the VEAF blurb |
| `veaf-tools.exe generate-config --output .` | `ModuleNotFoundError` | a 197-line `mission.yaml` |

### Done when

- [x] The rebuilt executable starts and runs a real command
- [x] A test fails if a lazily-resolved package is not collected
- [x] That test fires on a *future* lazy package, not only on `mission_builder`
- [x] The three tests verified against the un-fixed build

---

## 02 — Answer the question: does anything check that the executable starts?

Status: ✅ done — 2026-08-19. `exe-smoke` job added to `python-quality.yml`.
Type: chore
Files: `.github/workflows/python-quality.yml`

### The question this answers

The PRD asks it: three defects of the same family have now shipped — *works from source, broken in
the exe* — and each was fixed by adding one entry to the build plus one test asserting that entry.
A test per incident, no test for the family. Ticket 01's guards are of that shape too: they know
about lazy packages because a lazy package broke us.

### The answer: no, and one job fixes it

Nothing in the suite can answer it. Every test runs from the checkout, where an import PyInstaller
cannot see resolves perfectly — the packaged import graph is not observable from a checkout at all.
The only test that can is running the built binary.

`exe-smoke` in `python-quality.yml`: build the standalone binary, then

- `veaf-tools --help`, which walks the whole command tree and therefore imports every command
  module — exactly what 6.15.0 broke;
- `veaf-tools generate-config --output .`, which runs real code and writes a real file.

It is a separate job because it needs the `build` dependency group (pyinstaller) that the quality
gate deliberately excludes, and it runs on the same paths, so a change to `veaf_build/` or to any
package is covered.

**What it costs and what it does not cover**, said plainly rather than implied:

- Roughly 2–4 minutes of runner time per Python-touching PR, in parallel with the existing job.
- It runs on Linux. PyInstaller cannot cross-compile, so this proves the *import graph and the
  bundled data* are right, not that the Windows binary is — a Windows-only packaging defect would
  still get through. Adding a Windows runner is the obvious extension; not taken now because the
  three defects it would have caught were all platform-independent.
- Two commands are not 25. `--help` covers every command's imports; only `generate-config` covers
  execution. A missing data file used by one command only (the conversion profiles were exactly
  that) still gets through unless that command is smoked.

So the honest claim is narrow: **this would have caught all three defects to date**, and it makes
the fourth cheap to cover — one line, in a job that already exists.

### Done when

- [x] The CI builds the executable and runs it on every Python-touching PR
- [x] The smoke covers the import graph (`--help`) and one real execution
- [x] What it does not cover is written down, not left to be discovered

---
