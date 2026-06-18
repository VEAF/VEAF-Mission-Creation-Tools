"""Tests for veaf_libs.config_override (FOOTHOLD-V6-004).

The config-override renderer turns a ``config_override.values`` mapping (dotted
Lua-global keys → scalar values) into a small Lua script that reassigns only the
changed globals, and the lexical validator flags any key segment absent from the
injected Foothold corpus. Validation is pure-Python regex — no Lua execution.
"""

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from veaf_libs.config_override import (
    OVERRIDE_SCRIPT_NAME,
    find_unknown_segments,
    read_corpus,
    render_override_lua,
)


class TestRenderOverrideLua(unittest.TestCase):
    def test_renders_string_value_as_quoted_lua(self) -> None:
        lua = render_override_lua({"CapDifficulty": "medium"})
        self.assertIn('CapDifficulty = "medium"', lua)

    def test_renders_boolean_values(self) -> None:
        lua = render_override_lua({"StartNormal": True, "AutoRestart": False})
        self.assertIn("StartNormal = true", lua)
        self.assertIn("AutoRestart = false", lua)

    def test_renders_numeric_value(self) -> None:
        lua = render_override_lua({"MaxPlayers": 12})
        self.assertIn("MaxPlayers = 12", lua)

    def test_renders_dotted_path_as_nested_assignment(self) -> None:
        lua = render_override_lua({"Config.SubTable.Field": "x"})
        self.assertIn('Config.SubTable.Field = "x"', lua)

    def test_carries_generated_header(self) -> None:
        lua = render_override_lua({"A": 1})
        self.assertIn("GENERATED", lua)

    def test_preserves_key_order(self) -> None:
        lua = render_override_lua({"First": 1, "Second": 2})
        self.assertLess(lua.index("First"), lua.index("Second"))

    def test_string_with_quotes_stays_valid_lua(self) -> None:
        lua = render_override_lua({"Greeting": 'say "hi"'})
        # Must not produce a broken "say "hi"" literal — long string is used.
        self.assertNotIn('"say "hi""', lua)
        self.assertIn("Greeting = ", lua)


class TestFindUnknownSegments(unittest.TestCase):
    CORPUS = "CapDifficulty = easy\nlocal Config = {}\nConfig.SubTable = { Field = 1 }\n"

    def test_known_top_level_global_returns_empty(self) -> None:
        self.assertEqual(find_unknown_segments({"CapDifficulty": "hard"}, self.CORPUS), [])

    def test_unknown_global_is_reported(self) -> None:
        self.assertEqual(find_unknown_segments({"Nonexistent": 1}, self.CORPUS), ["Nonexistent"])

    def test_each_dotted_segment_is_checked(self) -> None:
        # Config + SubTable + Field all present.
        self.assertEqual(find_unknown_segments({"Config.SubTable.Field": 1}, self.CORPUS), [])

    def test_missing_intermediate_segment_is_reported(self) -> None:
        self.assertEqual(find_unknown_segments({"Config.Ghost.Field": 1}, self.CORPUS), ["Ghost"])

    def test_segments_are_deduplicated_in_order(self) -> None:
        result = find_unknown_segments({"Ghost.Field": 1, "Ghost.SubTable": 2}, self.CORPUS)
        self.assertEqual(result, ["Ghost"])

    def test_word_boundary_avoids_false_positive_substring(self) -> None:
        # "Cap" must not match inside "CapDifficulty".
        self.assertEqual(find_unknown_segments({"Cap": 1}, self.CORPUS), ["Cap"])


class TestReadCorpus(unittest.TestCase):
    def test_concatenates_lua_files_and_excludes_override(self) -> None:
        with TemporaryDirectory() as tmp:
            scripts = Path(tmp)
            (scripts / "Foothold Config.lua").write_text("CapDifficulty = easy\n", encoding="utf-8")
            (scripts / "Foothold setup.lua").write_text("doSetup()\n", encoding="utf-8")
            (scripts / OVERRIDE_SCRIPT_NAME).write_text("CapDifficulty = medium\n", encoding="utf-8")
            corpus = read_corpus(scripts)
        self.assertIn("CapDifficulty = easy", corpus)
        self.assertIn("doSetup()", corpus)
        # The generated override must not be part of its own validation corpus.
        self.assertNotIn("CapDifficulty = medium", corpus)

    def test_missing_directory_yields_empty_corpus(self) -> None:
        self.assertEqual(read_corpus(Path("does-not-exist-xyz")), "")


if __name__ == "__main__":
    unittest.main()
