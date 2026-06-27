"""Unit tests for veaf_libs.dcs_mock_audit — TOOLING-DCS-MOCK-COVERAGE (TDM-002)."""

from __future__ import annotations

import json
import unittest

from veaf_libs.dcs_mock_audit import (
    AuditResult,
    SchemaModel,
    audit_mocks,
    compute_audit,
    extract_used_calls,
    load_schema,
    parse_mocked_functions,
    parse_schema,
    strip_lua_comments,
)

# A mini schema mirroring the real shape: globals -> {static, properties{...}}.
_MINI_SCHEMA = {
    "globals": {
        "land": {"kind": "namespace", "static": {"getHeight": {"params": [], "returns": {}}}},
        "coalition": {"kind": "namespace", "static": {"addGroup": {"params": []}}},
        "trigger": {
            "kind": "namespace",
            "properties": {
                "action": {"static": {"outText": {"params": []}, "quadToAll": {"params": []}}},
                "misc": {"static": {"getUserFlag": {"params": []}}},
            },
        },
    }
}

_MINI_MOCK = """
land = {
  getHeight = function(vec2) return 0 end,
  SurfaceType = { LAND = 1, WATER = 3 },
}
trigger = {
  action = {
    outText = function(text, duration) end,
  },
  misc = {
    getUserFlag = function(flag) return 0 end,
  },
}
coalition = {
  side = { RED = 1, BLUE = 2 },
  -- a body containing braces and an `if ... end` must not corrupt the key stack
  getCountryCoalition = function(countryId)
    if countryId == 0 then return 1 end
    return { x = 0, y = 0 }
  end,
}
local function _helper(x) return x end
"""

_MINI_CALLSITE = """
-- a comment mentioning land.getHeight( should be ignored
local h = land.getHeight(myVec)               -- in schema, mocked
trigger.action.outText("hi", 10)              -- in schema, mocked
trigger.action.quadToAll(args)                -- in schema, NOT mocked -> missing
coalition.addGroup(country, cat, data)        -- in schema, NOT mocked -> missing
trigger.action.bogusCall(x)                   -- known ns, not in schema -> unknown
local n = someTable.land.getHeight(v)         -- sub-field, must NOT match
local g = group:getName()                     -- method call, must NOT match
veaf.doStuff()                                -- not a DCS namespace -> ignored
"""


class TestStripLuaComments(unittest.TestCase):
    def test_short_comment_removed(self) -> None:
        self.assertEqual(strip_lua_comments("a = 1 -- hello\nb = 2").strip(), "a = 1 \nb = 2")

    def test_comment_marker_inside_string_kept(self) -> None:
        src = 'url = "http://x--y.com"'
        self.assertEqual(strip_lua_comments(src), src)

    def test_long_comment_removed(self) -> None:
        src = "a = 1 --[[ multi\nline\ncomment ]] b = 2"
        out = strip_lua_comments(src)
        self.assertNotIn("multi", out)
        self.assertIn("a = 1", out)
        self.assertIn("b = 2", out)


class TestParseSchema(unittest.TestCase):
    def test_collects_static_and_nested_properties(self) -> None:
        model = parse_schema(_MINI_SCHEMA)
        self.assertIsInstance(model, SchemaModel)
        self.assertEqual(model.namespaces, frozenset({"land", "coalition", "trigger"}))
        self.assertIn("land.getHeight", model.functions)
        self.assertIn("coalition.addGroup", model.functions)
        self.assertIn("trigger.action.outText", model.functions)
        self.assertIn("trigger.action.quadToAll", model.functions)
        self.assertIn("trigger.misc.getUserFlag", model.functions)

    def test_load_schema_from_text(self) -> None:
        model = load_schema(json.dumps(_MINI_SCHEMA))
        self.assertIn("land.getHeight", model.functions)

    def test_empty_document(self) -> None:
        model = parse_schema({})
        self.assertEqual(model.functions, frozenset())
        self.assertEqual(model.namespaces, frozenset())


class TestExtractUsedCalls(unittest.TestCase):
    def setUp(self) -> None:
        self.namespaces = {"land", "coalition", "trigger"}

    def test_extracts_namespace_qualified_calls(self) -> None:
        used = extract_used_calls(_MINI_CALLSITE, self.namespaces)
        self.assertIn("land.getHeight", used)
        self.assertIn("trigger.action.outText", used)
        self.assertIn("trigger.action.quadToAll", used)
        self.assertIn("coalition.addGroup", used)
        self.assertIn("trigger.action.bogusCall", used)

    def test_subfield_access_not_matched(self) -> None:
        used = extract_used_calls("local x = a.land.getHeight(v)", self.namespaces)
        self.assertEqual(used, set())

    def test_method_call_not_matched(self) -> None:
        self.assertEqual(extract_used_calls("g:getName()", self.namespaces), set())

    def test_non_namespace_call_ignored(self) -> None:
        self.assertEqual(extract_used_calls("veaf.doStuff()", self.namespaces), set())

    def test_comment_calls_ignored(self) -> None:
        self.assertEqual(extract_used_calls("-- land.getHeight(x)", self.namespaces), set())

    def test_no_namespaces_returns_empty(self) -> None:
        self.assertEqual(extract_used_calls("land.getHeight(v)", set()), set())

    def test_block_comment_calls_ignored(self) -> None:
        src = "--[[ land.getHeight(x) ]] coalition.addGroup(a)"
        self.assertEqual(extract_used_calls(src, self.namespaces), {"coalition.addGroup"})


class TestParseMockedFunctions(unittest.TestCase):
    def test_nested_paths_and_body_skip(self) -> None:
        mocked = parse_mocked_functions(_MINI_MOCK)
        self.assertIn("land.getHeight", mocked)
        self.assertIn("trigger.action.outText", mocked)
        self.assertIn("trigger.misc.getUserFlag", mocked)
        self.assertIn("coalition.getCountryCoalition", mocked)

    def test_enum_tables_not_recorded(self) -> None:
        mocked = parse_mocked_functions(_MINI_MOCK)
        self.assertNotIn("land.SurfaceType", mocked)
        self.assertNotIn("coalition.side", mocked)
        self.assertNotIn("land.SurfaceType.LAND", mocked)

    def test_local_function_not_recorded(self) -> None:
        self.assertNotIn("_helper", parse_mocked_functions(_MINI_MOCK))

    def test_string_values_and_long_strings(self) -> None:
        # String literals (incl. a `}` inside) and a long string must not corrupt
        # table-scope tracking.
        src = """
        env = {
          theatre = "Caucasus }",
          banner = [[multi
          line }} string]],
          info = function(text) return "ok" end,
        }
        """
        mocked = parse_mocked_functions(src)
        self.assertEqual(mocked, {"env.info"})

    def test_function_body_braces_do_not_break_stack(self) -> None:
        # coalition.getCountryCoalition returns a table; the following sibling must
        # still be attributed to the right namespace.
        src = """
        coalition = {
          a = function() return { x = 1 } end,
          b = function() end,
        }
        """
        mocked = parse_mocked_functions(src)
        self.assertEqual(mocked, {"coalition.a", "coalition.b"})


class TestComputeAudit(unittest.TestCase):
    def test_buckets(self) -> None:
        schema = SchemaModel(
            functions=frozenset({"land.getHeight", "coalition.addGroup", "trigger.action.outText"}),
            namespaces=frozenset({"land", "coalition", "trigger"}),
        )
        used = {"land.getHeight", "coalition.addGroup", "trigger.action.bogusCall"}
        mocked = {"land.getHeight", "trigger.action.outText"}
        result = compute_audit(schema=schema, used=used, mocked=mocked)
        self.assertEqual(result.missing, ("coalition.addGroup",))
        self.assertEqual(result.unknown, ("trigger.action.bogusCall",))
        self.assertEqual(result.unused, ("trigger.action.outText",))
        self.assertTrue(result.has_gap)

    def test_no_gap(self) -> None:
        schema = SchemaModel(functions=frozenset({"land.getHeight"}), namespaces=frozenset({"land"}))
        result = compute_audit(schema=schema, used={"land.getHeight"}, mocked={"land.getHeight"})
        self.assertEqual(result.missing, ())
        self.assertFalse(result.has_gap)

    def test_unused_ignores_non_schema_namespaces(self) -> None:
        schema = SchemaModel(functions=frozenset({"land.getHeight"}), namespaces=frozenset({"land"}))
        # mist.* is not a schema namespace -> must not appear in the cleanup bucket.
        result = compute_audit(schema=schema, used=set(), mocked={"mist.scheduleFunction"})
        self.assertEqual(result.unused, ())


class TestAuditMocksEndToEnd(unittest.TestCase):
    def test_full_pipeline(self) -> None:
        result = audit_mocks(
            schema_json=json.dumps(_MINI_SCHEMA),
            mock_lua=_MINI_MOCK,
            veaf_sources=[_MINI_CALLSITE],
        )
        self.assertIsInstance(result, AuditResult)
        # quadToAll and addGroup are used + in-schema but not mocked.
        self.assertIn("trigger.action.quadToAll", result.missing)
        self.assertIn("coalition.addGroup", result.missing)
        # bogusCall is used on a known namespace but not in the schema.
        self.assertIn("trigger.action.bogusCall", result.unknown)
        # getUserFlag is mocked but never used in the call site.
        self.assertIn("trigger.misc.getUserFlag", result.unused)


if __name__ == "__main__":
    unittest.main()
