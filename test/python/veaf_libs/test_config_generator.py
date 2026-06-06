"""Tests for lua_config_generator — YAML-013."""

from __future__ import annotations

import unittest

from veaf_libs.lua_config_generator import generate_config_lua


class TestMissionIdentity(unittest.TestCase):
    def test_mission_name(self) -> None:
        lua = generate_config_lua({"mission": {"name": "TestMission"}})
        self.assertIn('veaf.config.MISSION_NAME = "TestMission"', lua)

    def test_mission_era(self) -> None:
        lua = generate_config_lua({"mission": {"era": "MODERN"}})
        self.assertIn("veaf.config.era = veaf.ERA.MODERN", lua)

    def test_mission_language(self) -> None:
        lua = generate_config_lua({"mission": {"language": "fr"}})
        self.assertIn('veaf.config.language = "fr"', lua)

    def test_no_mission_section_emits_nothing(self) -> None:
        lua = generate_config_lua({})
        self.assertNotIn("MISSION_NAME", lua)
        self.assertNotIn("veaf.config.era", lua)


class TestGlobalLogLevel(unittest.TestCase):
    def test_log_level_emitted(self) -> None:
        lua = generate_config_lua({"global_log_level": "trace"})
        self.assertIn('veaf.ForcedLogLevel = "trace"', lua)

    def test_no_log_level_section_absent(self) -> None:
        lua = generate_config_lua({})
        self.assertNotIn("ForcedLogLevel", lua)


class TestSecurity(unittest.TestCase):
    def test_security_disabled_true(self) -> None:
        lua = generate_config_lua({"security": {"disabled": True}})
        self.assertIn("veaf.SecurityDisabled = true", lua)

    def test_security_disabled_false(self) -> None:
        lua = generate_config_lua({"security": {"disabled": False}})
        self.assertIn("veaf.SecurityDisabled = false", lua)

    def test_no_security_section_absent(self) -> None:
        lua = generate_config_lua({})
        self.assertNotIn("SecurityDisabled", lua)


class TestLuaModules(unittest.TestCase):
    def test_enabled_module_gets_initialize(self) -> None:
        lua = generate_config_lua({"lua_modules": {"RADIO": {"enable": True}}})
        self.assertIn("veafRadio.initialize(true)", lua)

    def test_disabled_module_gets_setconfig(self) -> None:
        lua = generate_config_lua({"lua_modules": {"SPAWN": {"enable": False}}})
        self.assertIn('veaf.setConfig("SPAWN", "enable", false)', lua)

    def test_module_with_explicit_init(self) -> None:
        lua = generate_config_lua({"lua_modules": {"RADIO": {"enable": True, "init": {"help_menus": True}}}})
        self.assertIn("veafRadio.initialize(true)", lua)

    def test_unknown_module_is_ignored(self) -> None:
        """Unknown module IDs are not emitted — they stay in mission-script.lua."""
        lua = generate_config_lua({"lua_modules": {"FOOBAR": {"enable": True}}})
        self.assertNotIn("FOOBAR", lua)


class TestQra(unittest.TestCase):
    def test_silence_all_true(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {"silence_all": True, "definitions": []},
            }
        )
        self.assertIn("VeafQRA.ToggleAllSilence(true)", lua)

    def test_qra_definition_name(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {
                    "silence_all": False,
                    "definitions": [{"name": "AlphaQRA", "coalition": "RED"}],
                },
            }
        )
        self.assertIn('setName("AlphaQRA")', lua)


class TestCapMissions(unittest.TestCase):
    def test_cap_mission_emitted(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"COMBATMISSION": {"enable": True}},
                "cap_missions": [
                    {
                        "group_name": "CAP-01",
                        "menu_name": "Alpha",
                        "briefing": "Test",
                        "default": True,
                        "activated": True,
                    }
                ],
            }
        )
        self.assertIn('"CAP-01"', lua)
        self.assertIn("addCapMission", lua)


class TestToLuaScalar(unittest.TestCase):
    """_to_lua_scalar converts Python scalars to Lua literals."""

    def setUp(self) -> None:
        from veaf_libs.lua_config_generator import _to_lua_scalar

        self._f = _to_lua_scalar

    def test_true(self) -> None:
        self.assertEqual(self._f(True), "true")

    def test_false(self) -> None:
        self.assertEqual(self._f(False), "false")

    def test_int(self) -> None:
        self.assertEqual(self._f(42), "42")

    def test_float(self) -> None:
        self.assertEqual(self._f(3.14), "3.14")

    def test_none(self) -> None:
        self.assertEqual(self._f(None), "nil")

    def test_string(self) -> None:
        self.assertEqual(self._f("hello"), '"hello"')


class TestLuaLongString(unittest.TestCase):
    """_lua_long_string wraps text in [[…]] or [==[…]==]."""

    def setUp(self) -> None:
        from veaf_libs.lua_config_generator import _lua_long_string

        self._f = _lua_long_string

    def test_simple(self) -> None:
        self.assertEqual(self._f("hello world"), "[[hello world]]")

    def test_contains_close_brackets(self) -> None:
        result = self._f("text with ]] inside")
        # Dynamic level: ]] → level 1 → [=[...]=]
        self.assertEqual(result, "[=[text with ]] inside]=]")


class TestExportPath(unittest.TestCase):
    def test_export_path_string(self) -> None:
        lua = generate_config_lua({"mission": {"export_path": "/some/path"}})
        self.assertIn('veaf.config.MISSION_EXPORT_PATH = "/some/path"', lua)

    def test_export_path_empty_string_gives_nil(self) -> None:
        lua = generate_config_lua({"mission": {"export_path": ""}})
        self.assertIn("veaf.config.MISSION_EXPORT_PATH = nil", lua)


class TestPasswordHashes(unittest.TestCase):
    def test_hash_emitted(self) -> None:
        lua = generate_config_lua({"security": {"password_hashes": ["abc123def"]}})
        self.assertIn('veafSecurity.password_L9["abc123def"] = true', lua)

    def test_multiple_hashes(self) -> None:
        lua = generate_config_lua({"security": {"password_hashes": ["h1", "h2"]}})
        self.assertIn('"h1"', lua)
        self.assertIn('"h2"', lua)


class TestSettings(unittest.TestCase):
    def test_string_setting(self) -> None:
        lua = generate_config_lua({"settings": {"MY_KEY": "val"}})
        self.assertIn('veaf.config.MY_KEY = "val"', lua)

    def test_bool_setting(self) -> None:
        lua = generate_config_lua({"settings": {"FLAG": True}})
        self.assertIn("veaf.config.FLAG = true", lua)

    def test_int_setting(self) -> None:
        lua = generate_config_lua({"settings": {"COUNT": 7}})
        self.assertIn("veaf.config.COUNT = 7", lua)


class TestModuleLogLevel(unittest.TestCase):
    def test_per_module_log_level(self) -> None:
        lua = generate_config_lua({"lua_modules": {"RADIO": {"enable": True, "logLevel": "trace"}}})
        self.assertIn('veaf.setConfig("RADIO", "logLevel", "trace")', lua)

    def test_module_setconfig_extra_key(self) -> None:
        lua = generate_config_lua({"lua_modules": {"RADIO": {"enable": True, "myParam": "hello"}}})
        self.assertIn('veaf.setConfig("RADIO", "myParam", "hello")', lua)


class TestNamedPoints(unittest.TestCase):
    def test_namedpoints_with_custom_points(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {
                    "NAMEDPOINTS": {
                        "enable": True,
                        "custom_points": [{"name": "Alpha", "lat": "41.1", "lon": "44.9"}],
                    }
                }
            }
        )
        self.assertIn('name = "Alpha"', lua)
        self.assertIn("veafNamedPoints.initialize(customPoints)", lua)

    def test_namedpoints_without_custom_points(self) -> None:
        lua = generate_config_lua({"lua_modules": {"NAMEDPOINTS": {"enable": True}}})
        self.assertIn("veafNamedPoints.initialize({})", lua)


class TestAssetsModule(unittest.TestCase):
    def test_assets_list_emitted(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {
                    "ASSETS": {
                        "enable": True,
                        "assets": [
                            {"sort": 1, "name": "Arco", "description": "Tanker", "information": "UHF 251"},
                        ],
                    }
                }
            }
        )
        self.assertIn('name = "Arco"', lua)
        self.assertIn('description = "Tanker"', lua)
        self.assertIn("veafAssets.initialize()", lua)

    def test_assets_optional_fields_omitted_when_none(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {
                    "ASSETS": {
                        "enable": True,
                        "assets": [{"sort": 1, "name": "X", "description": "D", "information": "I"}],
                    }
                }
            }
        )
        self.assertNotIn("linked", lua)

    def test_assets_optional_freq(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {
                    "ASSETS": {
                        "enable": True,
                        "assets": [
                            {
                                "sort": 1,
                                "name": "X",
                                "description": "D",
                                "information": "I",
                                "freq": 251.0,
                            }
                        ],
                    }
                }
            }
        )
        self.assertIn("freq = 251.0", lua)


class TestQraFull(unittest.TestCase):
    def test_qra_enemy_coalitions(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {
                    "silence_all": False,
                    "definitions": [
                        {
                            "name": "AlphaQRA",
                            "coalition": "RED",
                            "enemy_coalitions": ["BLUE"],
                        }
                    ],
                },
            }
        )
        self.assertIn("addEnnemyCoalition(coalition.side.BLUE)", lua)

    def test_qra_trigger_zone_and_radius(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {
                    "definitions": [
                        {
                            "name": "BetaQRA",
                            "coalition": "RED",
                            "trigger_zone": "QRA zone alpha",
                            "zone_radius": 30000,
                        }
                    ]
                },
            }
        )
        self.assertIn(':setTriggerZone("QRA zone alpha")', lua)
        self.assertIn(":setZoneRadius(30000)", lua)

    def test_qra_groups_by_enemy_count(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {
                    "definitions": [
                        {
                            "name": "C",
                            "coalition": "RED",
                            "groups_by_enemy_count": [{"enemy_count": 2, "groups": ["G1", "G2"], "random_pick": 1}],
                        }
                    ]
                },
            }
        )
        self.assertIn("setRandomGroupsToDeployByEnemyQuantity(2", lua)

    def test_qra_delay_and_react(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {
                    "definitions": [
                        {
                            "name": "D",
                            "coalition": "RED",
                            "delay_before_rearming": 60,
                            "delay_before_activating": 30,
                            "react_on_helicopters": True,
                            "airport_link": "Kutaisi",
                        }
                    ]
                },
            }
        )
        self.assertIn(":setDelayBeforeRearming(60)", lua)
        self.assertIn(":setDelayBeforeActivating(30)", lua)
        self.assertIn(":setReactOnHelicopters()", lua)
        self.assertIn(':setAirportLink("Kutaisi")', lua)

    def test_qra_simple_groups(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"QRA": {"enable": True}},
                "qra": {"definitions": [{"name": "E", "coalition": "RED", "simple_groups": ["Grp1", "Grp2"]}]},
            }
        )
        self.assertIn(':addGroup("Grp1")', lua)
        self.assertIn(':addGroup("Grp2")', lua)


class TestCombatMissions(unittest.TestCase):
    def test_combat_mission_with_element(self) -> None:
        lua = generate_config_lua(
            {
                "lua_modules": {"COMBATMISSION": {"enable": True}},
                "combat_missions": [
                    {
                        "name": "Op Alpha",
                        "friendly_name": "Alpha Op",
                        "secured": True,
                        "radio_menu_enabled": False,
                        "briefing": "Attack the airfield.",
                        "elements": [
                            {
                                "name": "Strike Element",
                                "groups": ["F16-01", "F16-02"],
                                "scalable": True,
                            }
                        ],
                    }
                ],
            }
        )
        self.assertIn(':setName("Op Alpha")', lua)
        self.assertIn(':setFriendlyName("Alpha Op")', lua)
        self.assertIn(":setSecured(true)", lua)
        self.assertIn(":setRadioMenuEnabled(false)", lua)
        self.assertIn("[[Attack the airfield.]]", lua)
        self.assertIn(':setName("Strike Element")', lua)
        self.assertIn('"F16-01"', lua)


class TestSkynet(unittest.TestCase):
    def test_skynet_enabled_with_flags(self) -> None:
        lua = generate_config_lua(
            {
                "external_modules": {
                    "skynet": {
                        "enabled": True,
                        "include_red_in_radio": True,
                        "debug_red": False,
                        "include_blue_in_radio": True,
                        "debug_blue": True,
                    }
                }
            }
        )
        self.assertIn("veafSkynet.initialize(true, false, true, true)", lua)

    def test_skynet_disabled_emits_nothing(self) -> None:
        lua = generate_config_lua({"external_modules": {"skynet": {"enabled": False}}})
        self.assertNotIn("veafSkynet", lua)


class TestCtld(unittest.TestCase):
    def test_ctld_enabled_emits_properties(self) -> None:
        lua = generate_config_lua(
            {"external_modules": {"ctld": {"enabled": True, "hoverPickup": True, "maximumCrates": 5}}}
        )
        self.assertIn("ctld.hoverPickup = true", lua)
        self.assertIn("ctld.maximumCrates = 5", lua)

    def test_ctld_disabled_emits_nothing(self) -> None:
        lua = generate_config_lua({"external_modules": {"ctld": {"enabled": False}}})
        self.assertNotIn("ctld.", lua)


class TestGenerateMissionYamlTemplate(unittest.TestCase):
    def test_returns_string_with_lua_modules_section(self) -> None:
        from veaf_libs.lua_config_generator import generate_mission_yaml_template

        result = generate_mission_yaml_template()
        self.assertIsInstance(result, str)
        self.assertIn("lua_modules:", result)
        self.assertIn("# qra:", result)
        self.assertIn("# cap_missions:", result)
        self.assertIn("# combat_missions:", result)

    def test_enabled_module_appears_uncommented(self) -> None:
        from veaf_libs.lua_config_generator import generate_mission_yaml_template

        result = generate_mission_yaml_template(enabled_module_ids={"RADIO"})
        lines = result.splitlines()
        uncommented = [line for line in lines if not line.startswith("#") and "RADIO" in line]
        self.assertTrue(len(uncommented) >= 1, "RADIO should appear uncommented")

    def test_disabled_module_appears_commented(self) -> None:
        from veaf_libs.lua_config_generator import generate_mission_yaml_template

        result = generate_mission_yaml_template(enabled_module_ids=set())
        lines = result.splitlines()
        radio_lines = [line for line in lines if "RADIO" in line]
        self.assertTrue(all(line.lstrip().startswith("#") for line in radio_lines))


class TestConfigMigrator(unittest.TestCase):
    """Tests for ConfigMigrator.pre_extract() and migrate()."""

    def setUp(self) -> None:
        from mission_builder.config_migrator import ConfigMigrator

        self.migrator = ConfigMigrator()

    def test_migrate_removes_dofile(self) -> None:
        content = 'doFile("veaf-scripts.lua")\nlocal x = 1\n'
        result = self.migrator.migrate(content)
        self.assertIn("[v6 migration]", result.new_content)
        self.assertEqual(len(result.removed_dofiles), 1)

    def test_pre_extract_mission_name(self) -> None:
        from mission_builder.config_migrator import MigrationResult

        content = 'veaf.config.MISSION_NAME = "OpenTraining"\n'
        partial = MigrationResult(new_content="")
        new_content = self.migrator.pre_extract(content, partial)
        self.assertEqual(partial.mission_name, "OpenTraining")
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_pre_extract_era(self) -> None:
        from mission_builder.config_migrator import MigrationResult

        content = "veaf.config.era = veaf.ERA.MODERN\n"
        partial = MigrationResult(new_content="")
        self.migrator.pre_extract(content, partial)
        self.assertEqual(partial.mission_era, "MODERN")

    def test_pre_extract_security_disabled(self) -> None:
        from mission_builder.config_migrator import MigrationResult

        content = "veaf.SecurityDisabled = true\n"
        partial = MigrationResult(new_content="")
        self.migrator.pre_extract(content, partial)
        self.assertIs(partial.security_disabled, True)

    def test_migrate_integrates_pre_extract(self) -> None:
        content = 'veaf.config.MISSION_NAME = "Alpha"\nlocal x = 1\n'
        result = self.migrator.migrate(content)
        self.assertEqual(result.mission_name, "Alpha")


if __name__ == "__main__":
    unittest.main()
