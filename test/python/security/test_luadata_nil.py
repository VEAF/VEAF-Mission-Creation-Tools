"""Regression: the pure-Python luadata parser must accept Lua `nil` values.

SECREV-001 replaced the lua-executing `luadata.unserialize` with a pure-Python
state machine that did not handle `nil` as a value. v5 configs commonly write
`country = nil` (and other `key = nil`), so parsing real `radioSettings.lua` /
`waypointsSettings.lua` `settings` tables crashed with "unexpected character".
In Lua a `nil`-valued entry simply does not exist, so it is dropped.
"""

from __future__ import annotations

import luadata


class TestLuadataNil:
    def test_named_key_nil_is_dropped(self) -> None:
        assert luadata.unserialize("__c = { x = nil }", all_is_dict=True) == {}

    def test_nil_keeps_sibling_entries(self) -> None:
        assert luadata.unserialize("__c = { a = 1, b = nil, c = 3 }", all_is_dict=True) == {"a": 1, "c": 3}

    def test_nil_followed_by_table_key(self) -> None:
        # The exact v5 shape: `country = nil,` then a nested `["waypoints"] = {…}`.
        result = luadata.unserialize(
            '__c = { category = "plane", country = nil,\n ["waypoints"] = { [1] = 5 } }',
            all_is_dict=True,
        )
        assert result == {"category": "plane", "waypoints": {1: 5}}

    def test_bracketed_key_nil_is_dropped(self) -> None:
        assert luadata.unserialize('__c = { ["country"] = nil, ["x"] = 1 }', all_is_dict=True) == {"x": 1}
