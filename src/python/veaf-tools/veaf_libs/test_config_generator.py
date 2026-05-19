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
