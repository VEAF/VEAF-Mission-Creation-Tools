"""SECREV-2 / VMR-068 — `_extract_list` treated any backslash as an escape, anywhere.

`_extract_table`, ten lines above it, only honours a backslash **inside a string** and consumes
exactly one character through an `escape_next` flag. `_extract_list` instead looked at
`content[i - 1] == "\\"` regardless of string state, which has two consequences:

* a doubled backslash — an ordinary Windows path in a Lua string, `"C:\\\\weather\\\\"` — ends with
  the closing quote sitting right after a backslash, so the quote read as escaped and the string
  never closed. Every brace after that point stopped being counted and the list came back short.
* a backslash outside a string skipped the following character, which may be a brace.
"""

from __future__ import annotations

import unittest

from weather_injector.utils.lua_converter import LuaToYamlConverter


class TestExtractListWithEscapedPaths(unittest.TestCase):
    def test_a_windows_path_does_not_swallow_the_rest_of_the_list(self) -> None:
        # The closing quote of the first table's path follows a backslash.
        content = r"""
        targets = {
            { name = "one", path = "C:\\missions\\", value = 1 },
            { name = "two", value = 2 },
        }
        """
        tables = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(tables), 2, f"a Windows path truncated the list: {tables}")
        self.assertIn('name = "two"', tables[1])

    def test_a_trailing_backslash_before_the_quote_is_an_escaped_backslash(self) -> None:
        # `"a\\"` is the two-character string `a\`, not an unterminated string.
        content = r"""
        targets = {
            { path = "a\\" },
            { path = "b" },
        }
        """
        tables = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(tables), 2, f"the escaped backslash was read as escaping the quote: {tables}")

    def test_a_brace_inside_a_string_is_still_ignored(self) -> None:
        # The control: string handling must keep working, or the fix would be trading one bug
        # for another.
        content = r"""
        targets = {
            { name = "brace } inside" },
            { name = "second" },
        }
        """
        tables = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(tables), 2, f"a brace inside a string ended a table: {tables}")
        self.assertIn("second", tables[1])

    def test_an_escaped_quote_does_not_close_the_string(self) -> None:
        content = r"""
        targets = {
            { name = "say \"hi\" } now" },
            { name = "second" },
        }
        """
        tables = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(tables), 2, f"an escaped quote closed the string: {tables}")

    def test_a_plain_list_is_unchanged(self) -> None:
        # The baseline this function already handled, kept so the fix cannot regress it.
        content = """
        targets = {
            { name = "one" },
            { name = "two" },
            { name = "three" },
        }
        """
        tables = LuaToYamlConverter._extract_list(content, "targets")
        self.assertEqual(len(tables), 3)

    def test_a_missing_list_still_returns_empty(self) -> None:
        self.assertEqual(LuaToYamlConverter._extract_list("nothing = 1", "targets"), [])


if __name__ == "__main__":
    unittest.main()
