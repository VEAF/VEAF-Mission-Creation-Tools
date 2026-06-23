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
                    "country": [
                        {"name": "USA", "plane": {"group": [{"name": "Uzi", "units": [{"type": "F-15C"}]}]}}
                    ]
                }
            },
            "triggers": {"zones": [{"name": "Zone-1"}, {"name": "Airwaves-1"}]},
            "trigrules": {"comment": ["VEAF init", "Player wins"]},
        },
        theatre_content="Caucasus",
        dictionary_content={"DictKey_sortie_1": "Test Mission", "DictKey_desc_1": "Defend the base."},
        map_resource_content={"ResKey_1": "veaf-scripts.lua", "ResKey_2": "image.png"},
    )


class TestExportObject:
    def test_object_has_plugin_schema_keys(self) -> None:
        obj = build_export_object(_mission())
        assert set(obj) == {"theatre", "mission", "dictionary", "mapResource"}
        assert obj["theatre"] == "Caucasus"
        assert obj["mission"]["start_time"] == 43200


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
