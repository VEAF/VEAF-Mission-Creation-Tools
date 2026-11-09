"""A mission member is written in the layout the DCS Mission Editor writes (FEAT-DCS-EDITOR-LUA-LAYOUT 01).

The expected texts copy what the editor wrote in a mission saved on 2026-11-09 (DCS 2.9): tab
indentation, every key in brackets, a table's `{` on its own line, `{}` inline for an empty table, a
`-- end of [key]` comment after each table, and `} -- end of <name>` to close the member. Tools outside
VEAF read a mission's text that way (Flogas, 2026-11-09), so a built mission has to look the same.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import luadata
import pytest
from mission_tools.dcs_lua import serialize_member
from mission_tools.miz_tools import read_mission_folder

_REPO_ROOT = Path(__file__).resolve().parents[3]
_MISSIONS_ROOT = _REPO_ROOT / "test" / "veaf-tools"


def test_nested_tables_follow_the_editor_layout() -> None:
    content = {
        "coalition": {"blue": {"bullseye": {"x": 800.45410484296, "y": 917.83293390332}, "country": [{"id": 2}]}},
        "start_time": 28800,
    }

    assert serialize_member(content, "mission") == (
        "mission = \n"
        "{\n"
        '\t["coalition"] = \n'
        "\t{\n"
        '\t\t["blue"] = \n'
        "\t\t{\n"
        '\t\t\t["bullseye"] = \n'
        "\t\t\t{\n"
        '\t\t\t\t["x"] = 800.45410484296,\n'
        '\t\t\t\t["y"] = 917.83293390332,\n'
        '\t\t\t}, -- end of ["bullseye"]\n'
        '\t\t\t["country"] = \n'
        "\t\t\t{\n"
        "\t\t\t\t[1] = \n"
        "\t\t\t\t{\n"
        '\t\t\t\t\t["id"] = 2,\n'
        "\t\t\t\t}, -- end of [1]\n"
        '\t\t\t}, -- end of ["country"]\n'
        '\t\t}, -- end of ["blue"]\n'
        '\t}, -- end of ["coalition"]\n'
        '\t["start_time"] = 28800,\n'
        "} -- end of mission\n"
    )


def test_an_empty_table_stays_on_its_line() -> None:
    assert serialize_member({"passwords": {}, "forcedOptions": []}, "mission") == (
        'mission = \n{\n\t["forcedOptions"] = {},\n\t["passwords"] = {},\n} -- end of mission\n'
    )


def test_an_empty_member_is_one_line() -> None:
    assert serialize_member({}, "mapResource") == "mapResource = {}\n"


def test_scalars_are_written_as_the_editor_does() -> None:
    text = serialize_member({"a": True, "b": False, "c": 28800.0, "d": -0.5, "e": 'say "hi"\nnow \\ here'}, "x")

    assert '\t["a"] = true,\n' in text
    assert '\t["b"] = false,\n' in text
    # The editor writes a whole number without a decimal part.
    assert '\t["c"] = 28800,\n' in text
    assert '\t["d"] = -0.5,\n' in text
    assert '\t["e"] = "say \\"hi\\"\\\nnow \\\\ here",\n' in text


def test_numeric_keys_of_a_dict_are_bracketed_numbers() -> None:
    assert serialize_member({12: "a"}, "dictionary") == 'dictionary = \n{\n\t[12] = "a",\n} -- end of dictionary\n'


def test_a_key_with_a_line_break_cannot_leave_its_closing_comment() -> None:
    # A Lua comment ends at the line break: the rest of such a key would be code DCS runs.
    key = "a\nos.execute('x')\r--"
    text = serialize_member({key: {"b": 1}}, "mission")

    closing = [line for line in text.split("\n") if "-- end of" in line and "os.execute" in line]
    assert closing == ["\t}, -- end of [\"a\\nos.execute('x')\\r--\"]"]
    assert luadata.unserialize(text) == {key: {"b": 1}}


def _mission_folders() -> list[Path]:
    """Every repository mission folder holding a loose `src/mission/mission`."""
    if not _MISSIONS_ROOT.is_dir():
        return []
    return sorted(p for p in _MISSIONS_ROOT.iterdir() if (p / "src" / "mission" / "mission").is_file())


@pytest.mark.parametrize("folder", _mission_folders(), ids=lambda p: p.name)
def test_a_real_mission_reads_back_unchanged(folder: Path) -> None:
    mission = read_mission_folder(folder)
    members: dict[str, Any] = {
        "mission": mission.mission_content,
        "options": mission.options_content,
        "warehouses": mission.warehouses_content,
        "dictionary": mission.dictionary_content,
        "mapResource": mission.map_resource_content,
    }
    for name, content in members.items():
        if content is None:
            continue
        # The same `keep_as_dict` as `read_mission_folder`: trigger tables stay keyed by number.
        reread = luadata.unserialize(serialize_member(content, name), keep_as_dict=["trig", "trigrules"])
        assert _empties_as_dicts(reread) == _empties_as_dicts(content), name


def _empties_as_dicts(value: Any) -> Any:
    """`value` with every empty list made an empty dict: Lua's `{}` is both, the parser picks one."""
    if isinstance(value, dict):
        return {key: _empties_as_dicts(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_empties_as_dicts(item) for item in value] if value else {}
    return value
