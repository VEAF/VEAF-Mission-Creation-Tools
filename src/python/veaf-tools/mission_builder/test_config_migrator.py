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
"""

from __future__ import annotations

import unittest

from mission_builder.config_migrator import ConfigMigrator, MigrationResult


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
        # veafSpawn variable is not mapped to "SPAWN" (that's veafSpawnCore);
        # the fallback stores the variable name as the module id.
        result = self.m.migrate("veafSpawn.initialize()\n")
        self.assertIn("veafSpawn", result.enabled_modules)


class TestGuardDetection(unittest.TestCase):
    """if veafXxx then guards must register the module as enabled."""

    def setUp(self) -> None:
        self.m = ConfigMigrator()

    def test_guard_registers_module(self) -> None:
        content = "if veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        self.assertIn("RADIO", result.enabled_modules)

    def test_no_duplicate_module_from_guard(self) -> None:
        # veafSpawn → "veafSpawn" (fallback); veafRadio → "RADIO" (mapped).
        # The important thing is no duplicates regardless of ID.
        content = "if veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        self.assertEqual(result.enabled_modules.count("RADIO"), 1)

    def test_multiple_modules_all_detected(self) -> None:
        content = "if veafSpawn then\n  veafSpawn.initialize()\nend\nif veafRadio then\n  veafRadio.initialize()\nend\n"
        result = self.m.migrate(content)
        # veafSpawn → fallback "veafSpawn"; veafRadio → "RADIO"
        self.assertIn("veafSpawn", result.enabled_modules)
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
        # RADIO is not in this content so it should be commented
        snippet = self._migrate("if veafRadio then\n  veafRadio.initialize()\nend\n")
        lines = snippet.splitlines()
        move_commented = any(ln.strip().startswith("#") and "MOVE" in ln for ln in lines)
        self.assertTrue(move_commented, "MOVE should appear commented out in the snippet")


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


if __name__ == "__main__":
    unittest.main()
