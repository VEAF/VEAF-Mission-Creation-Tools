"""custom_scripts declaration order honoured in the load sequence (FOOTHOLD-V6-008).

The mission-script load order must follow the `custom_scripts:` declaration order,
not the glob/collection order. Reordering is *in place*: declared scripts are
reordered among the slots they already occupy; undeclared files (VEAF infra,
unknowns) never move.
"""

from __future__ import annotations

import unittest
from pathlib import Path

from mission_builder.mission_builder_worker import CustomScript, MissionBuilderWorker
from veaf_libs.config_override import OVERRIDE_SCRIPT_NAME


def _worker(declared: list[str], target: str | None = None, values: dict | None = None) -> MissionBuilderWorker:
    worker: MissionBuilderWorker = object.__new__(MissionBuilderWorker)
    worker._dcs_bridge_temp_file = None
    worker.custom_scripts = [CustomScript(path=name) for name in declared]
    worker.config_override_target = target
    worker.config_override_values = values or {}
    return worker


class TestApplyCustomScriptsOrder(unittest.TestCase):
    def test_reorders_declared_to_declaration_order(self) -> None:
        worker = _worker(["Moose.lua", "zoneCommander.lua", "Foothold setup.lua"])
        files = [
            "l10n/DEFAULT/Foothold setup.lua",
            "l10n/DEFAULT/zoneCommander.lua",
            "l10n/DEFAULT/Moose.lua",
        ]
        names = [Path(f).name for f in worker._apply_custom_scripts_order(files)]
        self.assertEqual(names, ["Moose.lua", "zoneCommander.lua", "Foothold setup.lua"])

    def test_undeclared_scripts_keep_absolute_position(self) -> None:
        worker = _worker(["B.lua", "A.lua"])  # declared order: B then A
        files = [
            "veaf-config.lua",  # undeclared infra — must stay at index 0
            "A.lua",
            "mission-script.lua",  # undeclared — must stay at index 2
            "B.lua",
        ]
        names = [Path(f).name for f in worker._apply_custom_scripts_order(files)]
        self.assertEqual(names, ["veaf-config.lua", "B.lua", "mission-script.lua", "A.lua"])

    def test_declared_but_missing_file_is_ignored(self) -> None:
        worker = _worker(["Ghost.lua", "A.lua", "B.lua"])
        files = ["B.lua", "A.lua"]  # Ghost.lua not collected
        names = [Path(f).name for f in worker._apply_custom_scripts_order(files)]
        self.assertEqual(names, ["A.lua", "B.lua"])

    def test_no_custom_scripts_is_a_noop(self) -> None:
        worker = _worker([])
        files = ["B.lua", "A.lua"]
        self.assertEqual(worker._apply_custom_scripts_order(files), files)


class TestOrderComposesWithOverride(unittest.TestCase):
    def test_override_stays_after_target_after_reorder(self) -> None:
        worker = _worker(
            ["Moose.lua", "Foothold Config.lua", "Foothold setup.lua"],
            target="Foothold Config.lua",
            values={"CapDifficulty": "x"},
        )
        # Glob/collection order is scrambled; the override sits last by accident.
        files = [
            "l10n/DEFAULT/Foothold setup.lua",
            "l10n/DEFAULT/Moose.lua",
            "l10n/DEFAULT/Foothold Config.lua",
            f"l10n/DEFAULT/{OVERRIDE_SCRIPT_NAME}",
        ]
        ordered = worker._position_config_override(worker._apply_custom_scripts_order(files))
        names = [Path(f).name for f in ordered]
        self.assertEqual(
            names,
            ["Moose.lua", "Foothold Config.lua", OVERRIDE_SCRIPT_NAME, "Foothold setup.lua"],
        )


if __name__ == "__main__":
    unittest.main()
