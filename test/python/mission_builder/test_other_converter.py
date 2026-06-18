"""Tests for the third-party (non-VEAF) mission converter — FOOTHOLD-V6-001.

Detection of native script-loader triggers: the converter must list the scripts
loaded by a third-party mission's native triggers, **in load order**, so it can
scaffold an ordered ``custom_scripts:`` block. Structure mirrors the real Foothold
Caucasus `.miz` (Lekaa): each loader trigrule carries ordered ``a_do_script_file``
actions whose ``file`` is a ``mapResource`` key resolving to a ``.lua`` filename.
"""

import tempfile
import unittest
from pathlib import Path

from mission_builder.other_converter import (
    DetectedLoader,
    build_scaffold_yaml,
    detect_native_loader_triggers,
    detect_native_script_loaders,
)
from mission_tools.miz_tools import DcsMission


def _mission(trigrules: dict, mapres: dict) -> DcsMission:
    return DcsMission(
        file_path=Path("x.miz"),
        mission_content={"trigrules": trigrules},
        map_resource_content=mapres,
    )


class TestDetectNativeScriptLoaders(unittest.TestCase):
    def test_orders_by_trigrule_then_action_and_resolves_lua(self) -> None:
        trigrules = {
            2: {
                "comment": "ScriptLoader 1",
                "predicate": "triggerStart",
                "actions": [
                    {"predicate": "a_do_script_file", "file": "K1"},
                    {"predicate": "a_do_script_file", "file": "K2"},
                ],
            },
            3: {
                "comment": "ScriptLoader 2",
                "predicate": "triggerStart",
                "actions": [
                    {"predicate": "a_do_script_file", "file": "K3"},
                ],
            },
        }
        mapres = {"K1": "Moose.lua", "K2": "Foothold Config.lua", "K3": "MA_Setup_CA.lua"}

        result = detect_native_script_loaders(_mission(trigrules, mapres))

        self.assertEqual(
            [d.script for d in result],
            ["Moose.lua", "Foothold Config.lua", "MA_Setup_CA.lua"],
        )
        self.assertEqual(result[0], DetectedLoader("Moose.lua", 2, "ScriptLoader 1"))
        self.assertEqual(result[2].trigger_index, 3)

    def test_ignores_non_lua_resources(self) -> None:
        trigrules = {1: {"comment": "sounds", "actions": [{"predicate": "a_do_script_file", "file": "S"}]}}
        mapres = {"S": "beacon.ogg"}

        self.assertEqual(detect_native_script_loaders(_mission(trigrules, mapres)), [])

    def test_ignores_unresolved_keys(self) -> None:
        trigrules = {1: {"comment": "x", "actions": [{"predicate": "a_do_script_file", "file": "MISSING"}]}}

        self.assertEqual(detect_native_script_loaders(_mission(trigrules, {})), [])

    def test_empty_mission_yields_nothing(self) -> None:
        self.assertEqual(detect_native_script_loaders(DcsMission(file_path=Path("x.miz"))), [])

    def test_handles_dict_form_actions_keyed_by_index(self) -> None:
        # DCS stores actions as a dict keyed by numeric index (the real .miz form),
        # the keys carrying the order — not as a list.
        trigrules = {
            1: {
                "comment": "ScriptLoader",
                "actions": {
                    2: {"predicate": "a_do_script_file", "file": "K2"},
                    1: {"predicate": "a_do_script_file", "file": "K1"},
                },
            }
        }
        mapres = {"K1": "First.lua", "K2": "Second.lua"}

        result = detect_native_script_loaders(_mission(trigrules, mapres))

        self.assertEqual([d.script for d in result], ["First.lua", "Second.lua"])


class TestDetectNativeLoaderTriggers(unittest.TestCase):
    def test_lists_loader_trigrules_in_order_with_comment(self) -> None:
        trigrules = {
            3: {"comment": "ScriptLoader 2", "actions": [{"predicate": "a_do_script_file", "file": "K3"}]},
            2: {"comment": "ScriptLoader 1", "actions": [{"predicate": "a_do_script_file", "file": "K1"}]},
        }
        mapres = {"K1": "Moose.lua", "K3": "Setup.lua"}

        result = detect_native_loader_triggers(_mission(trigrules, mapres))

        self.assertEqual(result, [(2, "ScriptLoader 1"), (3, "ScriptLoader 2")])

    def test_detects_inline_loader_via_do_script(self) -> None:
        trigrules = {1: {"comment": "boot", "actions": [{"predicate": "a_do_script", "text": "dofile('x.lua')"}]}}

        self.assertEqual(detect_native_loader_triggers(_mission(trigrules, {})), [(1, "boot")])

    def test_ignores_triggers_without_script_loading(self) -> None:
        trigrules = {1: {"comment": "flag", "actions": [{"predicate": "a_set_flag_value", "text": "x"}]}}

        self.assertEqual(detect_native_loader_triggers(_mission(trigrules, {})), [])


class TestBuildScaffoldYaml(unittest.TestCase):
    def _loaders(self) -> list[DetectedLoader]:
        return [
            DetectedLoader("Moose.lua", 2, "ScriptLoader 1"),
            DetectedLoader("Foothold Config.lua", 2, "ScriptLoader 1"),
            DetectedLoader("AIEN.lua", 5, "AIEN"),
        ]

    def test_custom_scripts_listed_in_order(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [(2, "ScriptLoader 1"), (5, "AIEN")])

        i_moose = yaml.index("Moose.lua")
        i_config = yaml.index("Foothold Config.lua")
        i_aien = yaml.index("AIEN.lua")
        self.assertTrue(i_moose < i_config < i_aien)
        self.assertIn("custom_scripts:", yaml)

    def test_paths_with_spaces_are_quoted(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [])

        self.assertIn('"src/scripts/Foothold Config.lua"', yaml)
        self.assertIn("src/scripts/Moose.lua", yaml)

    def test_strip_native_triggers_lists_comments(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [(2, "ScriptLoader 1"), (5, "AIEN")])

        self.assertIn("strip_native_triggers:", yaml)
        self.assertIn("ScriptLoader 1", yaml)
        self.assertIn("AIEN", yaml)

    def test_modules_block_present_and_disabled(self) -> None:
        yaml = build_scaffold_yaml(self._loaders(), [])

        self.assertIn("modules:", yaml)
        self.assertRegex(yaml, r"RADIO:\s*false")
        self.assertNotRegex(yaml, r":\s*true")


_REAL_MIZ = Path(r"D:\dev\_VEAF\tmp\test-foothold\test-caucasus\Foothold_CA_4.1.5_Multi_Language_Coldwar-Modern.miz")


@unittest.skipUnless(_REAL_MIZ.exists(), "real third-party Foothold .miz not available")
class TestOtherMissionConverterIntegration(unittest.TestCase):
    """End-to-end on the real Lekaa Foothold Caucasus `.miz`."""

    def test_scaffold_lists_scripts_in_load_order(self) -> None:
        from mission_builder.other_converter import OtherMissionConverter

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            report = OtherMissionConverter(version="test").convert(_REAL_MIZ, out)

            self.assertTrue(report.mission_yaml_generated)
            yaml = (out / "mission.yaml").read_text(encoding="utf-8")
            expected_order = [
                "Moose_2026-04-28.lua",
                "Foothold_Localization.lua",
                "Foothold Config.lua",
                "zoneCommander.lua",
                "MA_Setup_CA.lua",
                "WelcomeMessage.lua",
                "Zeus.lua",
                "EWRS.lua",
                "Foothold CTLD.lua",
                "Foothold_CTLD_Red.lua",
                "Splash_Damage_3.4.1_leka.lua",
                "AIEN.lua",
            ]
            positions = [yaml.index(name) for name in expected_order]
            self.assertEqual(positions, sorted(positions), "custom_scripts must follow native load order")
            self.assertIn("strip_native_triggers:", yaml)
            # Extracted scripts land in src/scripts/.
            self.assertTrue((out / "src" / "scripts" / "AIEN.lua").exists())

    def test_existing_yaml_not_overwritten_without_force(self) -> None:
        from mission_builder.other_converter import OtherMissionConverter

        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "mission"
            out.mkdir(parents=True)
            (out / "mission.yaml").write_text("sentinel: true\n", encoding="utf-8")

            report = OtherMissionConverter(version="test").convert(_REAL_MIZ, out, force=False)

            self.assertFalse(report.mission_yaml_generated)
            self.assertIn("sentinel: true", (out / "mission.yaml").read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
