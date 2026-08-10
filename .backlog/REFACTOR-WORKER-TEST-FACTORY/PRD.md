# Lot REFACTOR-WORKER-TEST-FACTORY — adding a field to `MissionBuilderWorker` broke fifteen test files

Status: ✅ done
Branch: `refactor/worker-test-factory`

## Problem Statement

`MissionBuilderWorker.__init__` reads `mission.yaml`, resolves the scripts path and checks the
framework loader exists on disk. A unit test of a single method wants none of that, so
14 files under `test/python/mission_builder/` built the worker with
`object.__new__(MissionBuilderWorker)` — **20 sites** — and then set only the handful of attributes
the method under test happened to read.

Every one of those shells is a partial copy of `__init__`'s field list, so **adding a field to
`__init__` breaks a scattered set of tests with `AttributeError`**, and the fix is to hand-patch
every shell. It happened twice on 2026-08-10:

- `collected_community_sound_files` (PR #681, `FIX-COMMUNITY-SOUNDS-PRUNED`)
- `_dcs_bridge_temp_file` (`SECREV-2` / VMR-049) — 15 files, including two `worker_with_three`-style
  fixtures **inside** test classes that a naive regex over module-level helpers missed

The failure carries no attribution: `AttributeError: 'MissionBuilderWorker' object has no attribute
'_dcs_bridge_temp_file'` in a test about trigger index shifting says nothing about the field having
just been added three files away.

## Why it matters

The cost is paid by whoever adds the *next* field, and it is paid twice: once finding all the sites,
once discovering the ones a grep missed. Two occurrences in one day is the signal — the third is
coming.

## Solution

One shared factory, `test/python/testlib/mission_builder_factory.py`:

- `init_field_defaults()` returns **every** attribute `__init__` assigns, with the value `__init__`
  produces for an empty `mission.yaml` and no CLI override. Rebuilt per call, so the mutable
  defaults are never shared between workers.
- `make_worker(**overrides)` applies those defaults to an `object.__new__` shell, then the
  overrides. A test names only what it cares about. An override that is not an `__init__` field
  raises `TypeError` rather than silently creating an attribute nothing reads.
- The "no mission folder needed" property is kept: `mission_folder` defaults to `None`, so a worker
  touches no filesystem unless the test asks for a folder. When one is given, `output_mission`
  derives from it (`<mission_folder>/out.miz`) — the convention every caller already used.

Method stubs (`worker._community_enabled = lambda …`) stay where they are, assigned on the returned
worker: they are behaviour, not fields.

**The one edit is enforced, not hoped for.** `test_mission_builder_factory_contract.py` reads the
`self.<field>` assignments out of `__init__`'s source with `ast` — branches included, which is what
a regex over the file would miss — and fails naming the missing field and the file to fix:

```
AssertionError: MissionBuilderWorker.__init__ assigns ['brand_new_field'], which make_worker()
leaves unset. Add one entry per field to init_field_defaults() in
test/python/testlib/mission_builder_factory.py.
```

Verified by injecting a field into `__init__` and watching the guard fail with that message; the
symmetric check catches a default left behind for a field `__init__` no longer assigns, which is how
a rename would otherwise hide.

`test/python/testlib` is on pytest's `pythonpath`. It has to be: with `--import-mode=importlib` a
test module cannot import a sibling file, and a `conftest.py` fixture is unreachable from the
`unittest.TestCase` classes that need it. A dedicated directory rather than `test/python` avoids
`mission_builder` resolving to two different packages.

## Definition of Done

- [x] `make_worker()` defaults all 28 fields `MissionBuilderWorker.__init__` assigns
- [x] all 20 `object.__new__(MissionBuilderWorker)` sites across 14 files replaced; the only
      remaining one is inside the factory
- [x] `test_mission_builder_factory_contract.py` fails when a field is added to `__init__` and is
      not defaulted — **proven** by injecting one
- [x] a stale default (field removed or renamed) fails too
- [x] `mission_folder` defaults to `None`: no folder created unless the test asks
- [x] unknown override rejected with `TypeError`
- [x] `doc/developer/GUIDE.md` + `.en.md` document `testlib/` and the factory (both languages,
      explicit `{#shared-test-helpers}` anchor); `poetry run docs-check` green
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` +
      `plugin/.claude-plugin/plugin.json`
- [x] `poetry run pytest` green (2916 passed), `ruff check`/`ruff format --check` over
      `src/python/ test/python/ veaf_build/`, `mypy src/python/veaf-tools`

## Out of Scope

- **No production behaviour change.** `mission_builder_worker.py` is not touched.
- The mypy `ignore_errors` list: `mission_builder_worker.py` is not in it, and no worker was
  edited, so the erosion obligation does not apply to this lot.
- The coverage gate stays at 79 — measured coverage is 79.92 %, so the gate is already within the
  ~2-point ratchet band. The lot removes more test lines than it adds.
- The `unittest.TestCase` classes are left as they are. Converting them to pytest fixtures would be
  a much larger diff for no gain on the defect this lot fixes.
- The other hand-built worker shells in the repository (if any exist outside
  `test/python/mission_builder/`) — the grep found none.
