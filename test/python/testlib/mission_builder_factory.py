"""Build a `MissionBuilderWorker` for unit tests without running `__init__`.

`MissionBuilderWorker.__init__` reads `mission.yaml`, resolves the scripts path and
checks that the framework loader exists on disk — everything a unit test of one
method wants to avoid. So the tests bypass it with `object.__new__` and set the few
attributes the method under test happens to read.

The cost of doing that per test file is that **adding a field to `__init__` breaks a
scattered set of tests with `AttributeError`**, once per file. It happened twice on
2026-08-10 alone (`collected_community_sound_files`, then `_dcs_bridge_temp_file`,
the latter needing edits in 15 files). :func:`make_worker` centralises the shell so a
new field costs one edit here, and
`test_mission_builder_factory_contract.py` fails loudly when that edit is missing.

No filesystem access: `mission_folder` defaults to ``None``, so a worker costs
nothing unless the test asks for a folder.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from mission_builder.mission_builder_worker import MissionBuilderWorker


def init_field_defaults() -> dict[str, Any]:
    """Return every attribute `MissionBuilderWorker.__init__` sets, with a neutral value.

    The values mirror what `__init__` produces for an empty `mission.yaml` with no CLI
    override, so a test only has to name what it actually cares about. Rebuilt on each
    call: the mutable defaults must not be shared between workers.

    Returns:
        A mapping of attribute name to default value, one entry per field assigned in
        `__init__`.
    """
    return {
        # Constructor arguments
        "mission_folder": None,
        "output_mission": None,
        "migrate_from_v5": True,
        "no_veaf_triggers": False,
        # Mission content, filled in during work()
        "dcs_mission": None,
        "collected_community_script_files": None,
        "collected_community_sound_files": None,
        "collected_veaf_script_files": None,
        "collected_mission_script_files": None,
        "collected_mission_data_files": None,
        # Configuration resolved from mission.yaml
        "mission_yaml": {},
        "pipeline_cfg": {},
        "_raw_yaml": {},
        "dynamic_mode": False,
        "dev_mode": False,
        "scripts_path": None,
        "global_log_level": None,
        "lua_modules": None,
        # custom_scripts section
        "custom_scripts": [],
        "custom_scripts_generate_load_trigger": True,
        # config_override section
        "config_override_target": None,
        "config_override_values": {},
        # community_scripts section (None = "all opt-out scripts enabled")
        "enabled_community_script_ids": None,
        # dcs_bridge section
        "dcs_bridge_enabled": False,
        "dcs_bridge_lua_path": None,
        "dcs_bridge_bytes": None,
        "_dcs_bridge_temp_file": None,
        # Guided checklists
        "checklist_images": [],
    }


def make_worker(**overrides: Any) -> MissionBuilderWorker:
    """Return a `MissionBuilderWorker` shell with every `__init__` field defaulted.

    `__init__` is not run. Every attribute it would set is present, so a method under
    test never raises `AttributeError` for a field the test did not think to set.

    When `mission_folder` is given and `output_mission` is not, `output_mission`
    defaults to `<mission_folder>/out.miz` — the convention every caller used.

    Args:
        **overrides: Attribute values to replace the defaults with. Each key must be a
            field `__init__` assigns; anything else is a typo and is rejected. Method
            stubs are not accepted here — assign them on the returned worker.

    Returns:
        The worker shell, ready for the method under test.

    Raises:
        TypeError: If an override names something `__init__` does not assign.
    """
    fields = init_field_defaults()
    if unknown := sorted(set(overrides) - set(fields)):
        raise TypeError(
            f"make_worker() got unknown field(s) {unknown}: not assigned by "
            f"MissionBuilderWorker.__init__. Assign a method stub on the worker instead."
        )

    fields.update(overrides)
    if fields["output_mission"] is None and isinstance(fields["mission_folder"], Path):
        fields["output_mission"] = fields["mission_folder"] / "out.miz"

    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    for name, value in fields.items():
        setattr(worker, name, value)
    return worker
