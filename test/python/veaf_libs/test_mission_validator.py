"""Tests for the pre-build mission validator (veaf_libs.mission_validator)."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from veaf_libs.mission_validator import ERROR, WARNING, validate_mission_folder

# A minimal DCS mission table: one blue player F-15 group + BLUFOR/REDFOR territory zones.
_MISSION_WITH_PLAYER = """mission =
{
    ["coalition"] =
    {
        ["blue"] =
        {
            ["country"] =
            {
                [1] =
                {
                    ["name"] = "USA",
                    ["plane"] =
                    {
                        ["group"] =
                        {
                            [1] =
                            {
                                ["name"] = "Uzi",
                                ["units"] = { [1] = { ["skill"] = "Client", ["type"] = "F-15C" } },
                            },
                        },
                    },
                },
            },
        },
    },
    ["triggers"] = { ["zones"] = { [1] = { ["name"] = "BLUFOR base" }, [2] = { ["name"] = "REDFOR base" } } },
}
"""

# Same but no aircraft and no zones.
_MISSION_EMPTY = """mission =
{
    ["coalition"] = { ["blue"] = { ["country"] = {} } },
    ["triggers"] = { ["zones"] = {} },
}
"""


def _make_folder(mission_yaml: str, mission_table: str | None = None, extra: dict[str, str] | None = None) -> Path:
    folder = Path(tempfile.mkdtemp())
    (folder / "mission.yaml").write_text(mission_yaml, encoding="utf-8")
    if mission_table is not None:
        (folder / "src" / "mission").mkdir(parents=True)
        (folder / "src" / "mission" / "mission").write_text(mission_table, encoding="utf-8")
    for rel, content in (extra or {}).items():
        p = folder / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    return folder


def _levels(issues) -> list[str]:
    return [i.level for i in issues]


class TestMissionValidator(unittest.TestCase):
    def test_missing_mission_yaml_is_an_error(self) -> None:
        folder = Path(tempfile.mkdtemp())
        issues = validate_mission_folder(folder)
        self.assertEqual(_levels(issues), [ERROR])

    def test_invalid_yaml_is_a_single_error(self) -> None:
        folder = _make_folder("modules:\n  RADIO: true\n   bad-indent: x\n")
        issues = validate_mission_folder(folder)
        self.assertEqual(_levels(issues), [ERROR])

    def test_unknown_module_is_an_error(self) -> None:
        folder = _make_folder("modules:\n  NOPE: true\n", mission_table=_MISSION_WITH_PLAYER)
        self.assertTrue(any(i.level == ERROR for i in validate_mission_folder(folder)))

    def test_missing_custom_script_is_an_error(self) -> None:
        folder = _make_folder(
            "custom_scripts:\n  scripts:\n    - path: src/scripts/ghost.lua\n",
            mission_table=_MISSION_WITH_PLAYER,
        )
        msgs = [i.message for i in validate_mission_folder(folder) if i.level == ERROR]
        self.assertTrue(any("ghost.lua" in m for m in msgs))

    def test_present_custom_script_passes(self) -> None:
        folder = _make_folder(
            "custom_scripts:\n  scripts:\n    - path: src/scripts/real.lua\n",
            mission_table=_MISSION_WITH_PLAYER,
            extra={"src/scripts/real.lua": "-- ok\n"},
        )
        self.assertFalse(any("real.lua" in i.message for i in validate_mission_folder(folder)))

    def test_clean_mission_has_no_issues(self) -> None:
        folder = _make_folder("modules:\n  RADIO: true\n", mission_table=_MISSION_WITH_PLAYER)
        self.assertEqual(validate_mission_folder(folder), [])

    def test_tum_without_zones_warns(self) -> None:
        folder = _make_folder("modules:\n  TUM: true\n", mission_table=_MISSION_EMPTY)
        msgs = [i.message for i in validate_mission_folder(folder) if i.level == WARNING]
        self.assertTrue(any("BLUFOR" in m or "REDFOR" in m or "TUM" in m for m in msgs))

    def test_tum_with_zones_does_not_warn_about_zones(self) -> None:
        folder = _make_folder("modules:\n  TUM: true\n", mission_table=_MISSION_WITH_PLAYER)
        self.assertFalse(any("territory" in i.message.lower() for i in validate_mission_folder(folder)))

    def test_waypoints_without_aircraft_warns(self) -> None:
        folder = _make_folder(
            "modules:\n  RADIO: true\n",
            mission_table=_MISSION_EMPTY,
            extra={"src/waypoints.yaml": "waypoints: {}\n"},
        )
        self.assertTrue(any(i.level == WARNING for i in validate_mission_folder(folder)))

    def test_no_source_mission_warns_and_skips(self) -> None:
        folder = _make_folder("modules:\n  RADIO: true\n")  # no src/mission
        issues = validate_mission_folder(folder)
        self.assertEqual(_levels(issues), [WARNING])

    def test_conversion_profile_incompatible_module_is_error(self) -> None:
        folder = _make_folder(
            "conversion_profile: foothold\nmodules:\n  CTLD: true\n",
            mission_table=_MISSION_WITH_PLAYER,
        )
        issues = validate_mission_folder(folder)
        self.assertTrue(any(i.level == ERROR and "CTLD" in i.message for i in issues))

    def test_conversion_profile_compatible_modules_clear(self) -> None:
        folder = _make_folder(
            "conversion_profile: foothold\nmodules:\n  RADIO: true\n",
            mission_table=_MISSION_WITH_PLAYER,
        )
        self.assertFalse(any("incompatible" in i.message.lower() for i in validate_mission_folder(folder)))

    def test_config_override_known_segments_pass(self) -> None:
        folder = _make_folder(
            'config_override:\n  target: "Foothold Config.lua"\n  values:\n    CapDifficulty: medium\n',
            mission_table=_MISSION_WITH_PLAYER,
            extra={"src/scripts/Foothold Config.lua": "CapDifficulty = easy\n"},
        )
        self.assertFalse(any("config_override" in i.message for i in validate_mission_folder(folder)))

    def test_config_override_unknown_segment_is_error(self) -> None:
        folder = _make_folder(
            'config_override:\n  target: "Foothold Config.lua"\n  values:\n    GhostSetting: 1\n',
            mission_table=_MISSION_WITH_PLAYER,
            extra={"src/scripts/Foothold Config.lua": "CapDifficulty = easy\n"},
        )
        issues = validate_mission_folder(folder)
        self.assertTrue(any(i.level == ERROR and "GhostSetting" in i.message for i in issues))


class TestValidateMissionContent(unittest.TestCase):
    """FEAT-BUILD-VALIDATE-REFS — Mission-Editor reference checks and their severity."""

    def test_missing_declared_group_is_error(self) -> None:
        from veaf_libs.mission_validator import validate_mission_content

        yaml_data = {"cap_missions": [{"group_name": "Ghost"}]}
        mission = {"coalition": {}}
        issues = validate_mission_content(yaml_data, mission)
        self.assertEqual(_levels(issues), [ERROR])

    def test_airwave_missing_trigger_zone_with_fallback_is_warning(self) -> None:
        from veaf_libs.mission_validator import validate_mission_content

        yaml_data = {
            "modules": {
                "AIRWAVES": {
                    "airwave_zones": [
                        {"name": "Z01", "trigger_zone_name": "AW-1", "zone_center_coordinates": "U37", "zone_radius": 9}
                    ]
                }
            }
        }
        issues = validate_mission_content(yaml_data, {"triggers": {"zones": []}})
        self.assertEqual(_levels(issues), [WARNING])
        self.assertIn("AW-1", issues[0].message)

    def test_clean_content_has_no_issues(self) -> None:
        from veaf_libs.mission_validator import validate_mission_content

        self.assertEqual(validate_mission_content({}, {"coalition": {}, "triggers": {"zones": []}}), [])


class TestRadioMenuSchema(unittest.TestCase):
    """Schema validation of modules.RADIO.user_menus (FEAT-RADIO-YAML-MENUS)."""

    def _check(self, user_menus: dict) -> list:
        from veaf_libs.mission_validator import _check_radio_menus

        return _check_radio_menus({"modules": {"RADIO": {"user_menus": user_menus}}})

    def test_valid_tree_has_no_issues(self) -> None:
        issues = self._check(
            {
                "tree": [
                    {
                        "menu": "Drapeaux",
                        "items": [
                            {"command": "ON", "action": "flag.on", "flag": "a"},
                            {"command": "QRA", "action": "qra.start", "qra": "N"},
                            {"command": "Lua", "action": "lua", "function": "m.f"},
                        ],
                    }
                ]
            }
        )
        self.assertEqual(issues, [])

    def test_unknown_action_is_error(self) -> None:
        issues = self._check({"tree": [{"command": "X", "action": "bogus.verb"}]})
        self.assertEqual(_levels(issues), [ERROR])
        self.assertIn("bogus.verb", issues[0].message)

    def test_missing_target_is_error(self) -> None:
        issues = self._check({"tree": [{"command": "Set", "action": "flag.set", "flag": "a"}]})  # no value
        self.assertEqual(_levels(issues), [ERROR])
        self.assertIn("value", issues[0].message)

    def test_no_user_menus_is_noop(self) -> None:
        from veaf_libs.mission_validator import _check_radio_menus

        self.assertEqual(_check_radio_menus({"modules": {"RADIO": {}}}), [])
        self.assertEqual(_check_radio_menus({}), [])


if __name__ == "__main__":
    unittest.main()
