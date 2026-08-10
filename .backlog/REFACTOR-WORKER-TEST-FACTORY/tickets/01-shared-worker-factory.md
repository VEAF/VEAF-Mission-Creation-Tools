# 01 — one shared `make_worker()` instead of twenty hand-built shells

Status: ✅ done

## Context

14 files under `test/python/mission_builder/` built a `MissionBuilderWorker` with
`object.__new__` (20 sites) and set a subset of `__init__`'s fields by hand. Each shell is a
partial copy of the field list, so a new field in `__init__` breaks an unpredictable subset of
them — twice on 2026-08-10, the second time needing edits in 15 files.

## Work

New `test/python/testlib/mission_builder_factory.py`:

- `init_field_defaults()` — the 28 attributes `__init__` assigns, each with the value `__init__`
  produces for an empty `mission.yaml` and no CLI override. Returned fresh per call so two workers
  never share a list or a dict.
- `make_worker(**overrides)` — defaults, then overrides, on an `object.__new__` shell. Rejects an
  override that is not an `__init__` field (`TypeError`, naming the key). Derives `output_mission`
  from `mission_folder` when only the folder is given. `mission_folder` defaults to `None`, so the
  helper touches no filesystem unless a test asks for a folder.

`pyproject.toml`: `pythonpath = ["src/python/veaf-tools", "test/python/testlib"]`. Necessary —
`--import-mode=importlib` blocks a sibling import, and a `conftest.py` fixture is unreachable from
the `unittest.TestCase` classes. A dedicated directory keeps `mission_builder` from resolving to
two packages.

Migrated, in call-site order: `test_assist_checklists_build`, `test_build_reference_warnings`,
`test_community_scripts_toggle` (×4), `test_config_override_build`, `test_ctld_user_config`,
`test_custom_scripts_order`, `test_custom_scripts_parsing`, `test_dcs_bridge`,
`test_dcs_bridge_trigger_shift` (×2, one of them the in-class `worker_with_three` fixture),
`test_dynamic_loading_prod`, `test_dynamic_mission_trigger_single_config`,
`test_mission_builder_defaults` (×2, one in-class), `test_strip_third_party_mods_wiring` (×2),
`test_trigger_spec_unified`.

Comments explaining *why* a value is what it is were carried over rather than dropped (the
`FIX-COMMUNITY-SOUNDS-PRUNED` note on `collected_community_sound_files={}`, the VMR-049 note on
`_dcs_bridge_temp_file` staying `None`) — those are the sites where a future reader needs them.

Method stubs stay assigned on the returned worker: they are behaviour, not `__init__` fields, and
`make_worker` refuses them on purpose.

## Tests

`test/python/mission_builder/test_mission_builder_factory_contract.py`:

- `ast`-reads the `self.<field>` assignments out of `inspect.getsource(__init__)` — nested branches
  included — and asserts every one has a default. Failure message names the field and the file.
- the symmetric check: a default with no matching assignment fails too, so a rename cannot hide.
- the shell really carries the attributes (`hasattr`), not just the defaults table.
- overrides: replacement works, mutable defaults are not shared between two workers, an unknown key
  raises, `output_mission` derives from `mission_folder`, an explicit `output_mission` wins, and
  nothing is created by default.

The guard was verified to fail: a `self.brand_new_field` injected into `__init__` produced the
intended message, and was then reverted.
