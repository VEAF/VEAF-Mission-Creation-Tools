"""Tests for ConfigMigrator — edge cases that actually matter.

Covers:
- _net_depth() heuristic (elseif, keywords in comments, for/do)
- Block comment passthrough (--[[ ... ]])
- Bare initialize() wrapping only at depth 0
- if veafXxx then guard module detection
- _build_yaml_snippet enabled vs commented modules
- _find_matching_close brace/paren matching
- _extract_skynet boolean argument parsing
- _extract_assets row parsing
- _extract_qra_chains silence toggle + chain definitions
- _extract_cap_missions definition extraction
- _extract_identity_and_security (MIG-002)
- _extract_combat_missions (MIG-002)
- _extract_shortcuts (MIG-002)
- _extract_named_points (MIG-002)
- _extract_sanctuary_zones (MIG-002)
- _extract_combat_zone_settings (MIG-002)
- _extract_combat_zones (MIG-002)
- _extract_airwaves_zones (MIG-002)
- _extract_security_mm (MIG-002)
- Integration tests on real fixtures (MIG-001)
"""

from __future__ import annotations

import pathlib
import unittest

import yaml
from mission_builder.config_migrator import ConfigMigrator, MigrationResult
from veaf_libs.lua_config_generator import MANDATORY_MODULES

# ---------------------------------------------------------------------------
# Fixture paths (MIG-001)
# ---------------------------------------------------------------------------
_FIXTURE_DIR = pathlib.Path(__file__).parents[2] / "veaf-tools"
_MB_FIXTURE = _FIXTURE_DIR / "mission-builder" / "src" / "scripts" / "missionConfig.lua"
_DEMO_FIXTURE = _FIXTURE_DIR / "demo-mission" / "src" / "scripts" / "missionConfig.lua"


class TestNetDepth(unittest.TestCase):
    """_net_depth() must correctly count Lua nesting changes."""

    def test_if_then_opens(self) -> None:
        self.assertEqual(ConfigMigrator._net_depth("if veafSpawn then"), 1)

    def test_end_closes(self) -> None:
        self.assertEqual(ConfigMigrator._net_depth("end"), -1)

    def test_function_opens(self) -> None:
        self.assertEqual(ConfigMigrator._net_depth("function setup()"), 1)

    def test_function_with_end_net_zero(self) -> None:
        # one-liner: function…end opens +1 and closes -1 → net 0
        self.assertEqual(ConfigMigrator._net_depth("function foo() return 1 end"), 0)

    def test_elseif_does_not_open(self) -> None:
        # elseif contains "if" but must NOT increase depth
        self.assertEqual(ConfigMigrator._net_depth("  elseif x > 0 then"), 0)

    def test_if_and_elseif_on_same_line(self) -> None:
        # "if" opens +1, "elseif" subtracts back one "if" → net 0
        self.assertEqual(ConfigMigrator._net_depth("if a then x() elseif b then"), 0)

    def test_keyword_in_inline_comment_not_counted(self) -> None:
        self.assertEqual(ConfigMigrator._net_depth("local x = 1 -- if debugging"), 0)

    def test_for_and_do_both_counted(self) -> None:
        # "for" (+1) + "do" (+1) → 2 (documented heuristic)
        self.assertEqual(ConfigMigrator._net_depth("for i=1,10 do"), 2)

    def test_plain_assignment_zero(self) -> None:
        self.assertEqual(ConfigMigrator._net_depth("local x = veafSpawn.initialize()"), 0)


class TestBlockComments(unittest.TestCase):
    """Content inside --[[ ... ]] must not be processed."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_dofile_inside_block_comment_not_removed(self) -> None:
        content = '--[[\ndoFile("veaf-scripts.lua")\n]]\n'
        result = self.m.migrate(content)
        self.assertEqual(result.removed_dofiles, [])
        # The original line must still be present
        self.assertIn('doFile("veaf-scripts.lua")', result.new_content)

    def test_initialize_inside_block_comment_not_wrapped(self) -> None:
        content = "--[[\nveafSpawn.initialize()\n]]\n"
        result = self.m.migrate(content)
        self.assertEqual(result.wrapped_calls, [])
        self.assertNotIn("if veafSpawn then", result.new_content)


class TestBareInitializeWrapping(unittest.TestCase):
    """Bare initialize() at depth 0 must be wrapped; NOT at depth > 0."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_bare_initialize_at_toplevel_is_wrapped(self) -> None:
        result = self.m.migrate("veafSpawn.initialize()\n")
        self.assertEqual(len(result.wrapped_calls), 1)
        self.assertIn("if veafSpawn then", result.new_content)

    def test_bare_initialize_inside_function_not_wrapped(self) -> None:
        content = "function setup()\n  veafSpawn.initialize()\nend\n"
        result = self.m.migrate(content)
        self.assertEqual(result.wrapped_calls, [])
        self.assertIn("veafSpawn.initialize()", result.new_content)
        self.assertNotIn("if veafSpawn then", result.new_content)

    def test_wrapped_call_still_registers_module(self) -> None:
        # veafSpawn maps to "SPAWN" via var_name in the module scanner.
        result = self.m.migrate("veafSpawn.initialize()\n")
        self.assertIn("SPAWN", result.enabled_modules)


class TestGuardDetection(unittest.TestCase):
    """if veafXxx then guards must register the module as enabled."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_guard_registers_module(self) -> None:
        content = "if veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        self.assertIn("RADIO", result.enabled_modules)

    def test_no_duplicate_module_from_guard(self) -> None:
        content = "if veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        self.assertEqual(result.enabled_modules.count("RADIO"), 1)

    def test_multiple_modules_all_detected(self) -> None:
        content = "if veafSpawn then\n  veafSpawn.initialize()\nend\nif veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        # veafSpawn maps to "SPAWN" via var_name; veafRadio maps to "RADIO"
        self.assertIn("SPAWN", result.enabled_modules)
        self.assertIn("RADIO", result.enabled_modules)


class TestYamlSnippet(unittest.TestCase):
    """_build_yaml_snippet marks enabled modules without # and disabled with #."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def _migrate(self, content: str) -> str:
        return self.m.migrate(content).yaml_snippet

    def test_enabled_module_not_commented(self) -> None:
        # veafRadio maps to "RADIO" via get_modules(), so it appears unindented
        snippet = self._migrate("if veafRadio then\n  veafRadio.initialize()\nend\n")
        lines = snippet.splitlines()
        radio_line = next((ln for ln in lines if "RADIO" in ln and not ln.strip().startswith("#")), None)
        self.assertIsNotNone(radio_line, "RADIO should appear without a leading # comment")

    def test_disabled_module_commented_out(self) -> None:
        # MOVE is not in this content so it should appear commented out in the snippet
        snippet = self._migrate("if veafRadio then\n  veafRadio.initialize()\nend\n")
        lines = snippet.splitlines()
        move_commented = any(ln.strip().startswith("#") and "MOVE" in ln for ln in lines)
        self.assertTrue(move_commented, "MOVE should appear commented out in the snippet")

    def test_mandatory_module_no_enable_key(self) -> None:
        """Mandatory modules that are active must use {} syntax, never emit 'enable:'."""
        snippet = self._migrate(
            "if veafUnits then\n  veafUnits.initialize()\nend\n"
            "if veafMarkers then\n  veafMarkers.initialize()\nend\n"
            "if veafRadio then\n  veafRadio.initialize()\nend\n"
        )
        lines = snippet.splitlines()

        # Any mandatory module that appears uncommented must use bare null `key:`, not `enable:`
        for mandatory in MANDATORY_MODULES:
            uncommented = [ln for ln in lines if mandatory in ln and not ln.lstrip().startswith("#")]
            if not uncommented:
                continue  # module not in enabled_set for this input — skip
            mandatory_lines = [ln for ln in uncommented if ln.strip() == f"{mandatory}:"]
            self.assertNotEqual(mandatory_lines, [], f"{mandatory} must be emitted as bare null '{mandatory}:'")
            enable_lines = [ln for ln in uncommented if "enable:" in ln]
            self.assertEqual(enable_lines, [], f"{mandatory} must not have 'enable:' in yaml snippet")

        # Non-mandatory enabled module must use shorthand `: true` (no extra config here)
        self.assertTrue(
            any(": true" in ln and not ln.lstrip().startswith("#") for ln in lines),
            "At least one non-mandatory module must be emitted with ': true'",
        )


class TestFindMatchingClose(unittest.TestCase):
    """_find_matching_close must match paired characters through nesting."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_simple_braces(self) -> None:
        s = "{abc}"
        self.assertEqual(self.m._find_matching_close(s, 0, "{", "}"), 5)

    def test_nested_braces(self) -> None:
        s = "{a{b{c}d}e}"
        self.assertEqual(self.m._find_matching_close(s, 0, "{", "}"), 11)

    def test_parens(self) -> None:
        s = "(foo(bar)baz)"
        self.assertEqual(self.m._find_matching_close(s, 0, "(", ")"), 13)

    def test_inner_start(self) -> None:
        # Starting at the second brace
        s = "outer{inner}rest"
        self.assertEqual(self.m._find_matching_close(s, 5, "{", "}"), 12)


class TestExtractSkynet(unittest.TestCase):
    """_extract_skynet must parse 4 boolean arguments from veafSkynet.initialize()."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_all_four_booleans_parsed(self) -> None:
        content = "veafSkynet.initialize(true, false, true, false)\n"
        result = MigrationResult(new_content="")
        self.m._extract_skynet(content, result)
        self.assertIsNotNone(result.skynet_config)
        cfg = result.skynet_config
        assert cfg is not None
        self.assertTrue(cfg["include_red_in_radio"])
        self.assertFalse(cfg["debug_red"])
        self.assertTrue(cfg["include_blue_in_radio"])
        self.assertFalse(cfg["debug_blue"])

    def test_skynet_line_commented_out(self) -> None:
        content = "veafSkynet.initialize(true, false, true, false)\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_skynet(content, result)
        # The line is replaced by a comment that includes the original text.
        self.assertIn("[v6 extracted to mission.yaml]", new_content)
        # Every non-blank line in the result must start with '--'
        for line in new_content.splitlines():
            if line.strip():
                self.assertTrue(line.strip().startswith("--"), f"Expected commented line, got: {line!r}")

    def test_absent_skynet_leaves_content_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_skynet(content, result)
        self.assertIsNone(result.skynet_config)
        self.assertEqual(new_content, content)


class TestExtractAssets(unittest.TestCase):
    """_extract_assets must parse veafAssets.Assets rows into dicts."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_multiple_rows_parsed(self) -> None:
        content = (
            "veafAssets.Assets = {\n"
            '  {name="Unit1", coalition="blue", strength=100},\n'
            '  {name="Unit2", coalition="red", strength=50},\n'
            "}\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_assets(content, result)
        self.assertIsNotNone(result.assets_extracted)
        assets = result.assets_extracted
        assert assets is not None
        self.assertEqual(len(assets), 2)
        self.assertEqual(assets[0]["name"], "Unit1")
        self.assertEqual(assets[0]["coalition"], "blue")
        self.assertEqual(assets[0]["strength"], 100)
        self.assertEqual(assets[1]["coalition"], "red")

    def test_boolean_value_parsed(self) -> None:
        content = 'veafAssets.Assets = {\n  {name="X", hidden=true},\n}\n'
        result = MigrationResult(new_content="")
        self.m._extract_assets(content, result)
        assert result.assets_extracted is not None
        self.assertIs(result.assets_extracted[0]["hidden"], True)

    def test_float_value_parsed(self) -> None:
        content = 'veafAssets.Assets = {\n  {name="X", scale=1.5},\n}\n'
        result = MigrationResult(new_content="")
        self.m._extract_assets(content, result)
        assert result.assets_extracted is not None
        self.assertAlmostEqual(result.assets_extracted[0]["scale"], 1.5)

    def test_assets_block_commented_out(self) -> None:
        content = 'veafAssets.Assets = {\n  {name="X"},\n}\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_assets(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_assets_table_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_assets(content, result)
        self.assertIsNone(result.assets_extracted)
        self.assertEqual(new_content, content)


class TestExtractQraChains(unittest.TestCase):
    """_extract_qra_chains must extract silence toggle and QRA chain definitions."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_silence_all_true(self) -> None:
        content = "VeafQRA.ToggleAllSilence(true)\n"
        result = MigrationResult(new_content="")
        self.m._extract_qra_chains(content, result)
        self.assertIs(result.qra_silence_all, True)

    def test_silence_all_false(self) -> None:
        content = "VeafQRA.ToggleAllSilence(false)\n"
        result = MigrationResult(new_content="")
        self.m._extract_qra_chains(content, result)
        self.assertIs(result.qra_silence_all, False)

    def test_qra_chain_name_and_coalition(self) -> None:
        content = (
            'local myQra = VeafQRA:new()\n  :setName("NorthQRA")\n  :setCoalition(coalition.side.RED)\n  :start()\n'
        )
        result = MigrationResult(new_content="")
        self.m._extract_qra_chains(content, result)
        self.assertEqual(len(result.qra_definitions), 1)
        qra = result.qra_definitions[0]
        self.assertEqual(qra["name"], "NorthQRA")
        self.assertEqual(qra["coalition"], "RED")

    def test_qra_chain_trigger_zone(self) -> None:
        content = 'local q = VeafQRA:new()\n  :setTriggerZone("ZoneAlpha")\n  :start()\n'
        result = MigrationResult(new_content="")
        self.m._extract_qra_chains(content, result)
        self.assertEqual(result.qra_definitions[0].get("trigger_zone"), "ZoneAlpha")

    def test_qra_chain_commented_out(self) -> None:
        # Need >1 key in the parsed QRA to pass the len(qra) > 1 guard
        content = 'local myQra = VeafQRA:new()\n  :setName("Alpha")\n  :setCoalition(coalition.side.RED)\n  :start()\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_qra_chains(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)


class TestExtractCapMissions(unittest.TestCase):
    """_extract_cap_missions must extract CAP mission definitions."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_cap_mission_all_fields(self) -> None:
        content = 'veafCombatMission.addCapMission("CAP-01", "Alpha CAP", "Intercept bandits", true, false)\n'
        result = MigrationResult(new_content="")
        self.m._extract_cap_missions(content, result)
        self.assertEqual(len(result.cap_missions_extracted), 1)
        cap = result.cap_missions_extracted[0]
        self.assertEqual(cap["group_name"], "CAP-01")
        self.assertEqual(cap["menu_name"], "Alpha CAP")
        self.assertEqual(cap["briefing"], "Intercept bandits")
        self.assertIs(cap["default"], True)
        self.assertIs(cap["activated"], False)

    def test_multiple_cap_missions(self) -> None:
        content = (
            'veafCombatMission.addCapMission("CAP-01", "Alpha", "Brief1", true, true)\n'
            'veafCombatMission.addCapMission("CAP-02", "Bravo", "Brief2", false, true)\n'
        )
        result = MigrationResult(new_content="")
        self.m._extract_cap_missions(content, result)
        self.assertEqual(len(result.cap_missions_extracted), 2)
        self.assertEqual(result.cap_missions_extracted[0]["group_name"], "CAP-01")
        self.assertEqual(result.cap_missions_extracted[1]["group_name"], "CAP-02")

    def test_cap_mission_line_commented_out(self) -> None:
        content = 'veafCombatMission.addCapMission("CAP-01", "Alpha", "Brief", true, true)\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_cap_missions(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_cap_missions_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_cap_missions(content, result)
        self.assertEqual(result.cap_missions_extracted, [])
        self.assertEqual(new_content, content)


# ===========================================================================
# MIG-002 — Unit tests for extractors not previously covered
# ===========================================================================


class TestExtractIdentityAndSecurity(unittest.TestCase):
    """_extract_identity_and_security must parse all identity/security fields."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_mission_name_extracted(self) -> None:
        content = 'veaf.config.MISSION_NAME = "My-Test-Mission"\n'
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertEqual(result.mission_name, "My-Test-Mission")

    def test_mission_name_line_commented(self) -> None:
        content = 'veaf.config.MISSION_NAME = "My-Test-Mission"\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_identity_and_security(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_export_path_nil_gives_none(self) -> None:
        content = "veaf.config.MISSION_EXPORT_PATH = nil\n"
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertIsNone(result.mission_export_path)

    def test_export_path_string_extracted(self) -> None:
        content = 'veaf.config.MISSION_EXPORT_PATH = "C:/Missions"\n'
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertEqual(result.mission_export_path, "C:/Missions")

    def test_security_disabled_true(self) -> None:
        content = "veaf.SecurityDisabled = true\n"
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertIs(result.security_disabled, True)

    def test_security_disabled_false(self) -> None:
        content = "veafSecurity.SecurityDisabled = false\n"
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertIs(result.security_disabled, False)

    def test_global_log_level_extracted(self) -> None:
        content = 'veaf.ForcedLogLevel = "debug"\n'
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertEqual(result.global_log_level_extracted, "debug")

    def test_absent_fields_leave_result_none(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        self.m._extract_identity_and_security(content, result)
        self.assertIsNone(result.mission_name)
        self.assertIsNone(result.mission_export_path)
        self.assertIsNone(result.security_disabled)
        self.assertIsNone(result.global_log_level_extracted)


class TestExtractCombatMissions(unittest.TestCase):
    """_extract_combat_missions must parse AddMissionsWithSkillAndScale chains."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_name_extracted(self) -> None:
        content = (
            "veafCombatMission.AddMissionsWithSkillAndScale(\n"
            "  VeafCombatMission:new()\n"
            '  :setName("Strike-01")\n'
            '  :setFriendlyName("Strike Mission 1")\n'
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_missions(content, result)
        self.assertEqual(len(result.combat_missions_extracted), 1)
        self.assertEqual(result.combat_missions_extracted[0]["name"], "Strike-01")

    def test_friendly_name_extracted(self) -> None:
        content = (
            "veafCombatMission.AddMissionsWithSkillAndScale(\n"
            '  VeafCombatMission:new():setName("X"):setFriendlyName("Nice Name")\n'
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_missions(content, result)
        self.assertEqual(result.combat_missions_extracted[0].get("friendly_name"), "Nice Name")

    def test_block_commented_out(self) -> None:
        content = 'veafCombatMission.AddMissionsWithSkillAndScale(\n  VeafCombatMission:new():setName("X")\n)\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_missions(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_match_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_missions(content, result)
        self.assertEqual(result.combat_missions_extracted, [])
        self.assertEqual(new_content, content)


class TestExtractShortcuts(unittest.TestCase):
    """_extract_shortcuts must parse VeafAlias builder chains."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_alias_name_extracted(self) -> None:
        content = (
            "veafShortcuts.AddAlias(\n"
            "    VeafAlias:new()\n"
            '        :setName("-test")\n'
            '        :setVeafCommand("_spawn bomb")\n'
            "        :setBypassSecurity(true)\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_shortcuts(content, result)
        self.assertEqual(len(result.shortcuts_extracted), 1)
        self.assertEqual(result.shortcuts_extracted[0]["name"], "-test")

    def test_alias_command_extracted(self) -> None:
        content = (
            "veafShortcuts.AddAlias(\n"
            "    VeafAlias:new()\n"
            '        :setName("-x")\n'
            '        :setVeafCommand("_destroy, radius 50")\n'
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_shortcuts(content, result)
        self.assertEqual(result.shortcuts_extracted[0].get("command"), "_destroy, radius 50")

    def test_bypass_security_false_extracted(self) -> None:
        content = (
            "veafShortcuts.AddAlias(\n"
            "    VeafAlias:new()\n"
            '        :setName("-s")\n'
            "        :setBypassSecurity(false)\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_shortcuts(content, result)
        self.assertIs(result.shortcuts_extracted[0].get("bypass_security"), False)

    def test_multiple_aliases(self) -> None:
        content = (
            "veafShortcuts.AddAlias(\n"
            '    VeafAlias:new():setName("-a"):setVeafCommand("cmd1")\n'
            ")\n"
            "veafShortcuts.AddAlias(\n"
            '    VeafAlias:new():setName("-b"):setVeafCommand("cmd2")\n'
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_shortcuts(content, result)
        self.assertEqual(len(result.shortcuts_extracted), 2)

    def test_block_commented_out(self) -> None:
        content = 'veafShortcuts.AddAlias(\n    VeafAlias:new():setName("-x"):setVeafCommand("cmd")\n)\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_shortcuts(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_aliases_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_shortcuts(content, result)
        self.assertEqual(result.shortcuts_extracted, [])
        self.assertEqual(new_content, content)


class TestExtractNamedPoints(unittest.TestCase):
    """_extract_named_points must comment out the if veafNamedPoints then block."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_block_commented_out(self) -> None:
        content = "if veafNamedPoints then\n    veafNamedPoints.Points = {}\n    veafNamedPoints.initialize()\nend\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_named_points(content, result)
        for line in new_content.splitlines():
            if line.strip():
                self.assertTrue(
                    line.strip().startswith("--"),
                    f"Expected commented line, got: {line!r}",
                )

    def test_migration_note_added(self) -> None:
        content = "if veafNamedPoints then\n    -- points\nend\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_named_points(content, result)
        self.assertIn("[v6 migration]", new_content)

    def test_warning_added(self) -> None:
        content = "if veafNamedPoints then\nend\n"
        result = MigrationResult(new_content="")
        self.m._extract_named_points(content, result)
        self.assertEqual(len(result.warnings), 1)
        self.assertIn("veafNamedPoints", result.warnings[0])

    def test_no_block_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_named_points(content, result)
        self.assertEqual(new_content, content)
        self.assertEqual(result.warnings, [])


class TestExtractSanctuaryZones(unittest.TestCase):
    """_extract_sanctuary_zones must parse VeafSanctuaryZone chains."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_zone_name_extracted(self) -> None:
        content = (
            "veafSanctuary.addZone(\n"
            "    VeafSanctuaryZone:new()\n"
            '        :setName("SafeZone-1")\n'
            "        :setCoalition(coalition.side.BLUE)\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_sanctuary_zones(content, result)
        self.assertEqual(len(result.sanctuary_zones_extracted), 1)
        self.assertEqual(result.sanctuary_zones_extracted[0]["name"], "SafeZone-1")

    def test_coalition_extracted(self) -> None:
        content = (
            "veafSanctuary.addZone(\n"
            "    VeafSanctuaryZone:new()\n"
            '        :setName("Z")\n'
            "        :setCoalition(coalition.side.RED)\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_sanctuary_zones(content, result)
        self.assertEqual(result.sanctuary_zones_extracted[0].get("coalition"), "RED")

    def test_delay_warning_extracted(self) -> None:
        content = (
            "veafSanctuary.addZone(\n"
            "    VeafSanctuaryZone:new()\n"
            '        :setName("Z")\n'
            "        :setDelayWarning(30)\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_sanctuary_zones(content, result)
        self.assertEqual(result.sanctuary_zones_extracted[0].get("delay_warning"), 30)

    def test_block_commented_out(self) -> None:
        content = 'veafSanctuary.addZone(\n    VeafSanctuaryZone:new():setName("Z")\n)\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_sanctuary_zones(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_zones_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_sanctuary_zones(content, result)
        self.assertEqual(result.sanctuary_zones_extracted, [])
        self.assertEqual(new_content, content)


class TestExtractCombatZoneSettings(unittest.TestCase):
    """_extract_combat_zone_settings must parse global veafCombatZone.Xxx = ... assignments."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_event_message_nil_extracted(self) -> None:
        content = "veafCombatZone.EventMessages.CombatZoneComplete = nil\n"
        result = MigrationResult(new_content="")
        self.m._extract_combat_zone_settings(content, result)
        self.assertIsNotNone(result.combat_zone_settings_extracted)
        settings = result.combat_zone_settings_extracted
        assert settings is not None
        self.assertIn("event_message_combatzonecomplete", settings)
        self.assertIsNone(settings["event_message_combatzonecomplete"])

    def test_watchdog_interval_extracted(self) -> None:
        content = "veafCombatZone.SecondsBetweenWatchdogChecks = 10\n"
        result = MigrationResult(new_content="")
        self.m._extract_combat_zone_settings(content, result)
        assert result.combat_zone_settings_extracted is not None
        self.assertEqual(result.combat_zone_settings_extracted.get("watchdog_check_interval"), 10)

    def test_radio_menu_name_extracted(self) -> None:
        content = 'veafCombatZone.RadioMenuName = "Command center"\n'
        result = MigrationResult(new_content="")
        self.m._extract_combat_zone_settings(content, result)
        assert result.combat_zone_settings_extracted is not None
        self.assertEqual(result.combat_zone_settings_extracted.get("radio_menu_name"), "Command center")

    def test_settings_line_commented_out(self) -> None:
        content = "veafCombatZone.SecondsBetweenWatchdogChecks = 5\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_zone_settings(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_settings_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_zone_settings(content, result)
        self.assertIsNone(result.combat_zone_settings_extracted)
        self.assertEqual(new_content, content)


class TestExtractCombatZones(unittest.TestCase):
    """_extract_combat_zones must parse VeafCombatZone definitions."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_zone_name_extracted(self) -> None:
        content = (
            "veafCombatZone.AddZone(\n"
            "    VeafCombatZone:new()\n"
            '        :setMissionEditorZoneName("myZone")\n'
            '        :setFriendlyName("My Zone")\n'
            "        :initialize()\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_zones(content, result)
        self.assertEqual(len(result.combat_zones_extracted), 1)
        self.assertEqual(result.combat_zones_extracted[0]["zone_name"], "myZone")

    def test_friendly_name_extracted(self) -> None:
        content = (
            "veafCombatZone.AddZone(\n"
            "    VeafCombatZone:new()\n"
            '        :setMissionEditorZoneName("z")\n'
            '        :setFriendlyName("Friendly Name")\n'
            "        :initialize()\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_zones(content, result)
        self.assertEqual(result.combat_zones_extracted[0].get("friendly_name"), "Friendly Name")

    def test_block_commented_out(self) -> None:
        content = 'veafCombatZone.AddZone(\n    VeafCombatZone:new():setMissionEditorZoneName("z"):initialize()\n)\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_zones(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_callback_generates_hint(self) -> None:
        content = (
            "veafCombatZone.AddZone(\n"
            "    VeafCombatZone:new()\n"
            '        :setMissionEditorZoneName("callbackZone")\n'
            "        :setOnCompletedHook(myCallback)\n"
            "        :initialize()\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_zones(content, result)
        self.assertGreater(len(result.callback_hints), 0)
        self.assertTrue(any("callbackZone" in h for h in result.callback_hints))

    def test_operation_zone_name_extracted(self) -> None:
        content = (
            "veafCombatZone.AddZone(\n"
            "    VeafCombatOperation:new()\n"
            '        :setMissionEditorZoneName("myOperation")\n'
            '        :setFriendlyName("My Operation")\n'
            "        :initialize()\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_zones(content, result)
        self.assertEqual(len(result.combat_zones_extracted), 1)
        self.assertEqual(result.combat_zones_extracted[0]["zone_name"], "myOperation")
        self.assertEqual(result.combat_zones_extracted[0]["type"], "operation")

    def test_no_zones_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_combat_zones(content, result)
        self.assertEqual(result.combat_zones_extracted, [])
        self.assertEqual(new_content, content)


class TestCombatZoneBriefingMultiline(unittest.TestCase):
    """setBriefing with Lua .. concatenation must produce a complete multiline string."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def _extract_zone(self, briefing_call: str) -> dict:
        content = (
            "veafCombatZone.AddZone(\n"
            "    VeafCombatZone:new()\n"
            '        :setMissionEditorZoneName("testZone")\n'
            f"        {briefing_call}\n"
            "        :initialize()\n"
            ")\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_combat_zones(content, result)
        return result.combat_zones_extracted[0]

    def test_single_fragment_newline_decoded(self) -> None:
        zone = self._extract_zone(':setBriefing("Hello\\nWorld")')
        self.assertIn("\n", zone["briefing"])
        self.assertIn("Hello", zone["briefing"])
        self.assertIn("World", zone["briefing"])

    def test_two_fragments_joined(self) -> None:
        zone = self._extract_zone(':setBriefing("Line one\\n" ..\n            "Line two\\n")')
        briefing = zone["briefing"]
        self.assertIn("Line one", briefing)
        self.assertIn("Line two", briefing)
        self.assertNotIn("..", briefing)

    def test_multiline_newlines_are_real(self) -> None:
        """Decoded \\n must be a real newline char, not literal backslash-n."""
        zone = self._extract_zone(':setBriefing("Part1\\nPart2")')
        self.assertNotIn("\\n", zone["briefing"])
        self.assertIn("\n", zone["briefing"])


class TestExtractAirwavesZones(unittest.TestCase):
    """_extract_airwaves_zones must parse AirWaveZone builder chains."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_zone_name_extracted(self) -> None:
        content = (
            "AirWaveZone:new()\n"
            '    :setName("Zone Alpha")\n'
            '    :setDescription("Test zone")\n'
            "    :addPlayerCoalition(coalition.side.BLUE)\n"
            "    :start()\n"
        )
        result = MigrationResult(new_content="")
        self.m._extract_airwaves_zones(content, result)
        self.assertEqual(len(result.airwave_zones_extracted), 1)
        self.assertEqual(result.airwave_zones_extracted[0]["name"], "Zone Alpha")

    def test_started_flag_true(self) -> None:
        content = 'AirWaveZone:new()\n    :setName("Z")\n    :start()\n'
        result = MigrationResult(new_content="")
        self.m._extract_airwaves_zones(content, result)
        self.assertIs(result.airwave_zones_extracted[0].get("start"), True)

    def test_zone_radius_extracted(self) -> None:
        content = 'AirWaveZone:new()\n    :setName("Z")\n    :setZoneRadius(50000)\n    :start()\n'
        result = MigrationResult(new_content="")
        self.m._extract_airwaves_zones(content, result)
        self.assertEqual(result.airwave_zones_extracted[0].get("zone_radius"), 50000)

    def test_callback_generates_hint(self) -> None:
        content = 'AirWaveZone:new()\n    :setName("CB-Zone")\n    :setOnDeploy(myDeployFn)\n    :start()\n'
        result = MigrationResult(new_content="")
        self.m._extract_airwaves_zones(content, result)
        self.assertGreater(len(result.callback_hints), 0)
        self.assertTrue(any("CB-Zone" in h for h in result.callback_hints))

    def test_block_commented_out(self) -> None:
        content = 'AirWaveZone:new()\n    :setName("Z")\n    :start()\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_airwaves_zones(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_zones_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_airwaves_zones(content, result)
        self.assertEqual(result.airwave_zones_extracted, [])
        self.assertEqual(new_content, content)


class TestExtractSecurityMm(unittest.TestCase):
    """_extract_security_mm must parse veafSecurity.password_MM hash entries."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_hash_extracted(self) -> None:
        content = 'veafSecurity.password_MM["abc123def456"] = true\n'
        result = MigrationResult(new_content="")
        self.m._extract_security_mm(content, result)
        self.assertEqual(result.password_mm_hashes, ["abc123def456"])

    def test_multiple_hashes_extracted(self) -> None:
        content = 'veafSecurity.password_MM["hash1"] = true\nveafSecurity.password_MM["hash2"] = true\n'
        result = MigrationResult(new_content="")
        self.m._extract_security_mm(content, result)
        self.assertEqual(result.password_mm_hashes, ["hash1", "hash2"])

    def test_lines_commented_out(self) -> None:
        content = 'veafSecurity.password_MM["myhash"] = true\n'
        result = MigrationResult(new_content="")
        new_content = self.m._extract_security_mm(content, result)
        self.assertIn("[v6 extracted to mission.yaml]", new_content)

    def test_no_hashes_unchanged(self) -> None:
        content = "local x = 1\n"
        result = MigrationResult(new_content="")
        new_content = self.m._extract_security_mm(content, result)
        self.assertEqual(result.password_mm_hashes, [])
        self.assertEqual(new_content, content)


# ===========================================================================
# MIG-001 — Integration tests on real fixture files
# ===========================================================================


class _IntegrationMixin:
    """Mixin for shared integration assertions.

    Does NOT inherit from TestCase — pytest won't collect it.
    Concrete test classes inherit (_IntegrationMixin, unittest.TestCase) so the
    MRO wires setUpClass/assertXxx correctly.
    setUpClass runs migrate() once per class to avoid repeated I/O and CPU.
    """

    FIXTURE: pathlib.Path  # override in subclass

    @classmethod
    def setUpClass(cls) -> None:
        super().setUpClass()  # type: ignore[misc]
        cls._content: str = cls.FIXTURE.read_text(encoding="utf-8")  # type: ignore[attr-defined]
        cls._result: MigrationResult = ConfigMigrator().migrate(cls._content)  # type: ignore[attr-defined]

    def test_no_exception(self) -> None:
        # setUpClass would have raised if migrate() failed — reaching here means success.
        pass

    def test_enabled_modules_not_empty(self) -> None:
        self.assertGreater(len(self._result.enabled_modules), 0)  # type: ignore[attr-defined]

    def test_yaml_snippet_is_valid_yaml(self) -> None:
        loaded = yaml.safe_load(self._result.yaml_snippet)  # type: ignore[attr-defined]
        self.assertIsNotNone(loaded)  # type: ignore[attr-defined]
        self.assertIn("modules", loaded)  # type: ignore[attr-defined]

    def test_no_uncommented_veaf_dofile_in_output(self) -> None:
        for line in self._result.new_content.splitlines():  # type: ignore[attr-defined]
            stripped = line.strip()
            if stripped.startswith("--"):
                continue
            self.assertNotRegex(  # type: ignore[attr-defined]
                stripped,
                r"doFile\s*\([^)]*veaf[^)]*\.lua",
                f"Unguarded doFile found: {stripped!r}",
            )


class TestIntegrationMissionBuilder(_IntegrationMixin, unittest.TestCase):
    """End-to-end migration of the mission-builder fixture."""

    FIXTURE = _MB_FIXTURE

    def test_known_modules_detected(self) -> None:
        self.assertIn("RADIO", self._result.enabled_modules)  # type: ignore[attr-defined]
        self.assertIn("SPAWN", self._result.enabled_modules)  # type: ignore[attr-defined]


class TestIntegrationDemoMission(_IntegrationMixin, unittest.TestCase):
    """End-to-end migration of the demo-mission fixture."""

    FIXTURE = _DEMO_FIXTURE

    def test_assets_extracted(self) -> None:
        self.assertIsNotNone(self._result.assets_extracted)  # type: ignore[attr-defined]
        assert self._result.assets_extracted is not None  # type: ignore[attr-defined]
        self.assertGreaterEqual(len(self._result.assets_extracted), 2)  # type: ignore[attr-defined]
        names = [a["name"] for a in self._result.assets_extracted]  # type: ignore[attr-defined]
        self.assertIn("Arco", names)
        self.assertIn("Petrolsky", names)

    def test_shortcuts_extracted(self) -> None:
        self.assertGreater(len(self._result.shortcuts_extracted), 0)  # type: ignore[attr-defined]
        alias_names = [s["name"] for s in self._result.shortcuts_extracted]  # type: ignore[attr-defined]
        self.assertIn("-b", alias_names)

    def test_combat_zone_settings_extracted(self) -> None:
        self.assertIsNotNone(self._result.combat_zone_settings_extracted)  # type: ignore[attr-defined]

    def test_combat_zones_extracted(self) -> None:
        self.assertGreater(len(self._result.combat_zones_extracted), 0)  # type: ignore[attr-defined]
        zone_names = [z.get("zone_name") for z in self._result.combat_zones_extracted]  # type: ignore[attr-defined]
        self.assertIn("czCrossKobuleti-1", zone_names)

    def test_airwave_zones_extracted(self) -> None:
        self.assertGreaterEqual(len(self._result.airwave_zones_extracted), 1)  # type: ignore[attr-defined]
        names = [z.get("name") for z in self._result.airwave_zones_extracted]  # type: ignore[attr-defined]
        self.assertIn("Zone 01", names)


if __name__ == "__main__":
    unittest.main()
