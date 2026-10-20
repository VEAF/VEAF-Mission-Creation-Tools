"""read_mission_file / edit_mission_file — the mission folder's text files for an AI with no file access.

FEAT-AI-ZERO-SETUP: in Claude Desktop's chat mode, an assistant asked to rename a mission answered that
no action could, and told the user to edit `mission.yaml` by hand; the guide's checklist asks it to
adapt four `src/*.yaml` files it could not open either.
"""

from pathlib import Path

import pytest
from veaf_mission_mcp.mission_files import edit_mission_file, read_mission_file

MISSION_YAML = "mission:\n  name: My-Mission  # the .miz name\n  era: MODERN\nmodules:\n  SKYNET: false\n"


@pytest.fixture
def folder(tmp_path: Path) -> Path:
    (tmp_path / "mission.yaml").write_text(MISSION_YAML, encoding="utf-8", newline="\n")
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "versions.yaml").write_text(
        "".join(f"line{n}: {n}\n" for n in range(1, 11)), encoding="utf-8", newline="\n"
    )
    return tmp_path


def test_read_returns_the_file_with_its_line_count(folder: Path) -> None:
    result = read_mission_file(folder, "mission.yaml")

    assert result["content"] == MISSION_YAML
    assert (result["first_line"], result["last_line"], result["total_lines"]) == (1, 5, 5)


def test_read_returns_a_slice_of_a_long_file(folder: Path) -> None:
    result = read_mission_file(folder, "src/versions.yaml", start_line=4, line_count=3)

    assert result["content"] == "line4: 4\nline5: 5\nline6: 6\n"
    assert (result["first_line"], result["last_line"], result["total_lines"]) == (4, 6, 10)


def test_edit_replaces_one_exact_passage_and_keeps_the_rest(folder: Path) -> None:
    result = edit_mission_file(
        folder, "mission.yaml", search="name: My-Mission", replace="name: helico_convoi_Montagnes"
    )

    text = (folder / "mission.yaml").read_text(encoding="utf-8")
    assert "  name: helico_convoi_Montagnes  # the .miz name\n" in text
    assert text.replace("helico_convoi_Montagnes", "My-Mission") == MISSION_YAML
    assert Path(result["backup"]).read_text(encoding="utf-8") == MISSION_YAML


def test_edit_keeps_lf_line_endings(folder: Path) -> None:
    edit_mission_file(folder, "mission.yaml", search="SKYNET: false", replace="SKYNET: true")

    assert b"\r\n" not in (folder / "mission.yaml").read_bytes()


def test_edit_refuses_a_passage_found_twice(folder: Path) -> None:
    with pytest.raises(ValueError, match="2 times"):
        edit_mission_file(folder, "src/versions.yaml", search=": 1", replace=": 0")

    assert (folder / "src" / "versions.yaml").read_text(encoding="utf-8").startswith("line1: 1\n")


def test_edit_refuses_a_passage_not_found(folder: Path) -> None:
    with pytest.raises(ValueError, match="not found"):
        edit_mission_file(folder, "mission.yaml", search="name: Other", replace="name: x")


def test_edit_refuses_a_result_that_is_no_longer_yaml_and_leaves_the_file(folder: Path) -> None:
    with pytest.raises(ValueError, match="YAML"):
        edit_mission_file(folder, "mission.yaml", search="era: MODERN", replace="era: [MODERN")

    assert (folder / "mission.yaml").read_text(encoding="utf-8") == MISSION_YAML


@pytest.mark.parametrize(
    "file",
    ["../mission.yaml", "src/../../x.yaml", "src/scripts/x.lua", "src/mission/mission", "README.md", "src/sub/x.yaml"],
)
def test_only_mission_yaml_and_src_yaml_files_are_reachable(folder: Path, file: str) -> None:
    with pytest.raises(ValueError, match="mission.yaml"):
        read_mission_file(folder, file)
    with pytest.raises(ValueError, match="mission.yaml"):
        edit_mission_file(folder, file, search="a", replace="b")


def test_an_absolute_path_is_refused(folder: Path) -> None:
    with pytest.raises(ValueError, match="mission.yaml"):
        read_mission_file(folder, str(folder / "mission.yaml"))


def test_a_folder_without_mission_yaml_is_not_a_mission_folder(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        read_mission_file(tmp_path, "mission.yaml")


def test_both_actions_are_in_the_catalogue(folder: Path) -> None:
    from veaf_mission_mcp.actions import register_default_actions
    from veaf_mission_mcp.catalog import ActionCatalog

    catalog = ActionCatalog()
    register_default_actions(catalog)
    catalog.run_action(
        "edit_mission_file",
        {"mission_path": str(folder), "file": "mission.yaml", "search": "era: MODERN", "replace": "era: WW2"},
    )
    read = catalog.run_action("read_mission_file", {"mission_path": str(folder), "file": "mission.yaml"})
    assert "era: WW2" in read["content"]
