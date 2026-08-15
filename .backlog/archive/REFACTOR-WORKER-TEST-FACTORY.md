# Lot REFACTOR-WORKER-TEST-FACTORY — adding a field to `MissionBuilderWorker` broke fifteen test files

Status: ✅ done

**Goal**: `MissionBuilderWorker.__init__` reads `mission.yaml`, resolves the scripts path and checks
the framework loader on disk — none of which a unit test of a single method wants. So 14 files under
`test/python/mission_builder/` built the worker with `object.__new__(MissionBuilderWorker)` (**20
sites**) and set by hand only the attributes the method under test happened to read.

Every shell was a partial copy of `__init__`'s field list, so **adding a field broke a scattered,
unpredictable subset of tests with `AttributeError`**. It happened **twice on 2026-08-10**:
`collected_community_sound_files` (PR #681, `FIX-COMMUNITY-SOUNDS-PRUNED`), then
`_dcs_bridge_temp_file` (`SECREV-2` / VMR-049) needing edits in 15 files — including two
`worker_with_three`-style fixtures **inside** test classes that a regex over module-level helpers
missed.

The failure carried no attribution: `AttributeError: 'MissionBuilderWorker' object has no attribute
'_dcs_bridge_temp_file'` inside a test about trigger index shifting says nothing about a field added
three files away. Two occurrences in one day was the signal.

**Branch**: `refactor/worker-test-factory` → [#686](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/686) → `develop`

| # | Ticket | Type | Status |
|---|--------|------|--------|
| 01 | One shared `make_worker()` instead of twenty hand-built shells | refactor | ✅ |

## What shipped

`test/python/testlib/mission_builder_factory.py`:

- **`init_field_defaults()`** — every one of the 28 attributes `__init__` assigns, each with the
  value `__init__` produces for an empty `mission.yaml` and no CLI override. Rebuilt per call, so
  two workers never share a list or a dict.
- **`make_worker(**overrides)`** — defaults then overrides on an `object.__new__` shell. A test names
  only what it cares about. An override that is not an `__init__` field raises `TypeError` naming the
  key, rather than silently creating an attribute nothing reads.
- The "no mission folder needed" property is kept: `mission_folder` defaults to `None`, so a worker
  touches no filesystem unless the test asks for a folder; when one is given, `output_mission`
  derives from it, the convention every caller already used.

All 20 sites across 14 files migrated. Method stubs (`worker._community_enabled = lambda …`) stay
assigned on the returned worker: they are behaviour, not fields, and `make_worker` refuses them on
purpose. Comments explaining *why* a value is what it is were carried over rather than dropped —
those sites are exactly where a future reader needs them.

`pyproject.toml` gains `pythonpath = [..., "test/python/testlib"]`. Necessary rather than
convenient: `--import-mode=importlib` blocks a sibling import, and a `conftest.py` fixture is
unreachable from the `unittest.TestCase` classes that need it. A dedicated directory keeps
`mission_builder` from resolving to two different packages.

## The one edit is enforced, not hoped for

`test_mission_builder_factory_contract.py` reads the `self.<field>` assignments out of `__init__`'s
source with `ast` — **nested branches included**, which is what a regex over the file would miss —
and fails naming both the missing field and the file to fix:

```
AssertionError: MissionBuilderWorker.__init__ assigns ['brand_new_field'], which make_worker()
leaves unset. Add one entry per field to init_field_defaults() in
test/python/testlib/mission_builder_factory.py.
```

**Verified by injecting a field into `__init__` and watching the guard fail with that message**, then
reverting. The symmetric check catches a default left behind for a field `__init__` no longer
assigns, which is how a rename would otherwise hide.

## On Sourcery's review

It asked for a dict to be checked alongside the list for shared mutable defaults. Doing that
per named field would need extending every time a mutable default is added — **the maintenance shape
this lot exists to remove**. So the test walks `init_field_defaults()` instead, mutates every
list/dict/set on one worker and asserts the other is untouched, and refuses to pass vacuously if the
factory ever has no mutable default left. Verified to fail: sharing the defaults table between
workers produces `mission_yaml is shared between two workers`.

## Out of scope

- **No production behaviour change** — `mission_builder_worker.py` is not touched.
- The mypy `ignore_errors` erosion obligation does not apply: `mission_builder_worker.py` is not on
  that list and no worker was edited.
- The coverage gate stays at 79 (measured 79.92 %, already inside the ~2-point ratchet band). The lot
  removes more test lines than it adds.
- The `unittest.TestCase` classes are left as they are — converting them to pytest fixtures would be
  a far larger diff for no gain on the defect this lot fixes.

**Verification**: `poetry run pytest` green (2916 passed), ruff check + format over
`src/python/ test/python/ veaf_build/`, mypy over `src/python/veaf-tools`, `docs-check` green with
the `{#shared-test-helpers}` anchor documented in `GUIDE.md` and `GUIDE.en.md`.
