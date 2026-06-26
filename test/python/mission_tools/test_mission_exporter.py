"""FEAT-EXPORT-MISSION — export a parsed mission to JSON / YAML / Markdown, safely."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
import yaml
from mission_tools.miz_tools import DcsMission
from mission_tools.mission_exporter import (
    build_export_object,
    export_mission,
    to_json,
    to_markdown,
    to_yaml,
)


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


def _mission_with_trig() -> DcsMission:
    """A mission whose `trig`/`trigrules` are int-keyed dicts, as `keep_as_dict` leaves them."""
    return DcsMission(
        file_path=Path("/dev/null"),
        mission_content={
            "trigrules": {1: {"comment": "rule1"}, 2: {"comment": "rule2"}},
            "trig": {
                "actions": {1: "a_do_script(...)"},
                "conditions": {1: "return true"},
                "flag": {1: True},
            },
            "sparse": {2: "a", 5: "b"},  # group/zone deleted in the editor → gap
            "mixed": {1: "a", "x": "b"},
            "empty": {},
        },
    )


class TestExportObject:
    def test_object_has_plugin_schema_keys(self) -> None:
        obj = build_export_object(_mission())
        assert set(obj) == {"schemaVersion", "theatre", "mission", "dictionary", "mapResource"}
        assert obj["schemaVersion"] == 1
        assert obj["theatre"] == "Caucasus"
        assert obj["mission"]["start_time"] == 43200


class TestArrayness:
    """FEAT-EXPORT-BFR-PARSER-002 — the JSON array/object contract (export-json-contract.md §2)."""

    def test_contiguous_int_keyed_dict_becomes_array(self) -> None:
        obj = build_export_object(_mission_with_trig())
        mission = obj["mission"]
        assert mission["trigrules"] == [{"comment": "rule1"}, {"comment": "rule2"}]
        assert mission["trig"]["actions"] == ["a_do_script(...)"]
        assert mission["trig"]["conditions"] == ["return true"]
        assert mission["trig"]["flag"] == [True]

    def test_sparse_dict_stays_object_with_string_keys(self) -> None:
        mission = build_export_object(_mission_with_trig())["mission"]
        assert mission["sparse"] == {"2": "a", "5": "b"}

    def test_mixed_key_dict_stays_object(self) -> None:
        mission = build_export_object(_mission_with_trig())["mission"]
        assert mission["mixed"] == {"1": "a", "x": "b"}

    def test_empty_dict_stays_object(self) -> None:
        mission = build_export_object(_mission_with_trig())["mission"]
        assert mission["empty"] == {}

    def test_json_emits_arrays_for_sequences(self) -> None:
        parsed = json.loads(to_json(build_export_object(_mission_with_trig())))
        assert isinstance(parsed["mission"]["trigrules"], list)
        assert isinstance(parsed["mission"]["sparse"], dict)


class TestParityGate:
    """FEAT-EXPORT-BFR-PARSER-005 — the exported object reproduces today's `load()` shape.

    The plugin indexes some tables numerically (`#trigrules`, `ipairs(trig.actions)`): those must be
    JSON arrays. A table left sparse by an editor deletion (`{[2]=,[5]=}`) cannot be an array and
    ships as an object with string keys — the plugin's decoder coerces them back (contract §3).
    """

    def test_numerically_indexed_tables_are_arrays_sparse_is_object(self) -> None:
        # `triggers.zones` after deleting zones #1, #3, #4 in the editor: a sparse int-keyed table.
        mission = DcsMission(
            file_path=Path("/dev/null"),
            mission_content={
                "trigrules": {1: {"comment": "VEAF init"}, 2: {"comment": "Player wins"}},
                "triggers": {"zones": {2: {"name": "Zone-2"}, 5: {"name": "Zone-5"}}},
            },
        )
        parsed = json.loads(to_json(build_export_object(mission)))
        # contiguous → array (works with #/ipairs after decoding)
        assert parsed["mission"]["trigrules"] == [{"comment": "VEAF init"}, {"comment": "Player wins"}]
        # sparse → object with string keys (decoder coerces back to integer keys)
        assert parsed["mission"]["triggers"]["zones"] == {"2": {"name": "Zone-2"}, "5": {"name": "Zone-5"}}


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
