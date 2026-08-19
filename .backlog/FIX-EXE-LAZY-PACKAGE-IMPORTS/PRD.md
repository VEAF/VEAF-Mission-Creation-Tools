# FIX-EXE-LAZY-PACKAGE-IMPORTS — the 6.15 executable dies on its first command

Status: ✅ done — 2026-08-19, both tickets

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
