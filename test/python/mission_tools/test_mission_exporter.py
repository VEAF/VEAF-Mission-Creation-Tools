"""FEAT-EXPORT-MISSION — export a parsed mission to JSON / YAML / Markdown, safely."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml
from mission_tools.mission_exporter import (
    build_export_object,
    export_mission,
    to_json,
    to_markdown,
    to_yaml,
)
from mission_tools.miz_tools import DcsMission


def _mission() -> DcsMission:
    return DcsMission(
        file_path=Path("/dev/null"),
        mission_content={
            "date": {"Day": 1, "Month": 6, "Year": 2026},
            "start_time": 43200,
            "sortie": "DictKey_sortie_1",
            "descriptionText": "DictKey_desc_1",
            "coalition": {
                "blue": {
                    "country": [{"name": "USA", "plane": {"group": [{"name": "Uzi", "units": [{"type": "F-15C"}]}]}}]
                }
            },
            "triggers": {"zones": [{"name": "Zone-1"}, {"name": "Airwaves-1"}]},
            "trigrules": {"comment": ["VEAF init", "Player wins"]},
        },
        theatre_content="Caucasus",
        dictionary_content={"DictKey_sortie_1": "Test Mission", "DictKey_desc_1": "Defend the base."},
        map_resource_content={"ResKey_1": "veaf-scripts.lua", "ResKey_2": "image.png"},
    )


def _mission_with_lua_tables() -> DcsMission:
    """A mission carrying the three real DCS key-type families (see export-json-contract.md §2)."""
    return DcsMission(
        file_path=Path("/dev/null"),
        mission_content={
            # contiguous int → JSON array
            "trigrules": {1: {"comment": "rule1"}, 2: {"comment": "rule2"}},
            "trig": {"actions": {1: "a_do_script(...)"}, "flag": {1: True}},
            # sparse int (e.g. weapon pylons 1,2,8,11) → envelope
            "pylons": {1: "AIM-9", 2: "AIM-120", 8: "fuel", 11: "AIM-9"},
            # mixed int + string (e.g. DCS callsign {1,2,3,name=...}) → envelope
            "callsign": {1: 169, 2: 1, 3: 1, "name": "Colt11"},
            # string-numeric (e.g. DCS failures keyed by string id) → object, NOT coerced
            "failures": {"10": {"enable": False}, "11": {"enable": True}},
            "empty": {},
        },
    )


def _json_mission() -> dict:
    return json.loads(to_json(build_export_object(_mission_with_lua_tables())))["mission"]


class TestExportObject:
    def test_object_has_plugin_schema_keys(self) -> None:
        obj = build_export_object(_mission())
        assert set(obj) == {"schemaVersion", "theatre", "mission", "dictionary", "mapResource"}
        assert obj["schemaVersion"] == 2
        assert obj["theatre"] == "Caucasus"
        assert obj["mission"]["start_time"] == 43200

    def test_build_object_keeps_raw_integer_keys(self) -> None:
        # The pivot stays raw (YAML consumer); the JSON contract is applied only in to_json.
        obj = build_export_object(_mission_with_lua_tables())
        assert obj["mission"]["pylons"] == {1: "AIM-9", 2: "AIM-120", 8: "fuel", 11: "AIM-9"}


class TestJsonContract:
    """FEAT-EXPORT-BFR-PARSER-002 — the v2 key-type-preserving JSON contract (export-json-contract.md §2)."""

    def test_contiguous_int_keyed_table_becomes_array(self) -> None:
        mission = _json_mission()
        assert mission["trigrules"] == [{"comment": "rule1"}, {"comment": "rule2"}]
        assert mission["trig"]["actions"] == ["a_do_script(...)"]
        assert mission["trig"]["flag"] == [True]

    def test_sparse_int_table_uses_envelope_with_integer_keys(self) -> None:
        pylons = _json_mission()["pylons"]
        assert pylons == {"__luaTable__": [[1, "AIM-9"], [2, "AIM-120"], [8, "fuel"], [11, "AIM-9"]]}
        # pair keys are JSON integers (not strings) so the decoder rebuilds Lua integer keys
        assert all(isinstance(pair[0], int) for pair in pylons["__luaTable__"])

    def test_mixed_key_table_uses_envelope_preserving_both_types(self) -> None:
        callsign = _json_mission()["callsign"]
        assert callsign == {"__luaTable__": [[1, 169], [2, 1], [3, 1], ["name", "Colt11"]]}

    def test_string_numeric_table_stays_object_not_coerced(self) -> None:
        # `failures` keyed by string ids must stay a string-keyed object — never an array/envelope.
        failures = _json_mission()["failures"]
        assert failures == {"10": {"enable": False}, "11": {"enable": True}}

    def test_empty_table_is_object(self) -> None:
        assert _json_mission()["empty"] == {}

    def test_integer_keys_emit_without_decimal(self) -> None:
        # Contract precision: a pair key 1 must serialize as `1`, never `1.0` (decoder needs an int).
        text = to_json(build_export_object(_mission_with_lua_tables()), compact=True)
        assert '[1,"AIM-9"]' in text
        assert "1.0" not in text

    def test_envelope_pairs_are_two_element_arrays(self) -> None:
        for pair in _json_mission()["pylons"]["__luaTable__"]:
            assert isinstance(pair, list) and len(pair) == 2
            assert isinstance(pair[0], (int, str))


class TestJsonYaml:
    def test_json_is_valid_and_complete(self) -> None:
        text = to_json(build_export_object(_mission()))
        parsed = json.loads(text)
        assert parsed["mission"]["coalition"]["blue"]["country"][0]["name"] == "USA"

    def test_json_compact_has_no_newlines(self) -> None:
        text = to_json(build_export_object(_mission()), compact=True)
        assert "\n" not in text

    def test_yaml_round_trips(self) -> None:
        obj = build_export_object(_mission())
        assert yaml.safe_load(to_yaml(obj)) == obj


class TestMarkdown:
    def test_markdown_brief_sections(self) -> None:
        md = to_markdown(_mission())
        assert "# Test Mission" in md  # title resolved through the dictionary
        assert "Defend the base." in md  # description resolved
        assert "Caucasus" in md
        assert "## Order of battle" in md
        assert "Uzi (F-15C)" in md
        assert "- Zone-1" in md and "- Airwaves-1" in md
        assert "veaf-scripts.lua" in md
        assert "image.png" not in md  # only .lua scripts are listed


class TestExportMission:
    def test_dispatch_by_format(self) -> None:
        m = _mission()
        assert export_mission(m, "json").startswith("{")
        assert "theatre:" in export_mission(m, "yaml")
        assert export_mission(m, "markdown").startswith("# ")

    def test_unknown_format_raises(self) -> None:
        with pytest.raises(ValueError):
            export_mission(_mission(), "xml")


class TestExportNeverRunsLua:
    """FEAT-EXPORT-MISSION-004 — the export path must never execute Lua (RCE safety).

    Checked structurally via the AST (imports + calls), not by text matching, so the modules can
    still *describe* the risk in their docstrings without tripping the guard.
    """

    _BANNED_IMPORTS = {"subprocess", "lupa"}
    _BANNED_CALLS = {"eval", "exec", "compile"}

    def _imports_and_calls(self, rel: str) -> tuple[set[str], set[str]]:
        import ast

        root = Path(__file__).parents[3] / "src" / "python" / "veaf-tools"
        tree = ast.parse((root / rel).read_text(encoding="utf-8"))
        imports: set[str] = set()
        calls: set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imports.update(n.name.split(".")[0] for n in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module.split(".")[0])
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                calls.add(node.func.id)
        return imports, calls

    def test_export_modules_perform_no_lua_execution(self) -> None:
        for rel in ("mission_tools/mission_exporter.py", "veaf_tools/commands/export.py"):
            imports, calls = self._imports_and_calls(rel)
            assert not (imports & self._BANNED_IMPORTS), f"{rel} imports {imports & self._BANNED_IMPORTS} (RCE risk)"
            assert not (calls & self._BANNED_CALLS), f"{rel} calls {calls & self._BANNED_CALLS} (RCE risk)"
