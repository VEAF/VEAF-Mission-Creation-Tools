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
    [
        "../mission.yaml",
        "src/../../x.yaml",
        "src/scripts/x.lua",
        "src/mission/mission",
        "README.md",
        "src/sub/x.yaml",
        "src/C:evil.yaml",
        "src/..yaml",
    ],
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


def test_a_symbolic_link_out_of_the_folder_is_refused(folder: Path, tmp_path_factory: pytest.TempPathFactory) -> None:
    outside = tmp_path_factory.mktemp("outside") / "target.yaml"
    outside.write_text("secret: 1\n", encoding="utf-8")
    link = folder / "src" / "link.yaml"
    try:
        link.symlink_to(outside)
    except OSError:
        pytest.skip("creating a symbolic link needs a privilege this account lacks")

    with pytest.raises(ValueError, match="mission.yaml"):
        edit_mission_file(folder, "src/link.yaml", search="secret: 1", replace="secret: 2")
    assert outside.read_text(encoding="utf-8") == "secret: 1\n"


def test_lines_are_counted_on_line_feeds_only(folder: Path) -> None:
    """`str.splitlines` also splits on U+2028 and form feeds: the slices would drift from the file."""
    (folder / "src" / "versions.yaml").write_text("a: 1  # x\u2028y\nb: 2\n", encoding="utf-8", newline="\n")

    result = read_mission_file(folder, "src/versions.yaml", start_line=2, line_count=1)

    assert (result["content"], result["total_lines"]) == ("b: 2\n", 2)


def _crlf(folder: Path) -> Path:
    path = folder / "mission.yaml"
    path.write_bytes(MISSION_YAML.replace("\n", "\r\n").encode("utf-8"))
    return path


def test_read_returns_line_feeds_from_a_crlf_file(folder: Path) -> None:
    """What the AI copies back is what it read: `\r\n` in, a `\n` passage out (FIX-OPENCODE-TEST-FINDINGS 02)."""
    _crlf(folder)

    result = read_mission_file(folder, "mission.yaml")

    assert (result["content"], result["total_lines"]) == (MISSION_YAML, 5)


def test_edit_matches_a_multi_line_passage_in_a_crlf_file_and_keeps_crlf(folder: Path) -> None:
    """Sent with `\n`, the passage was "not found" and the AI rewrote presets.yaml with PowerShell."""
    path = _crlf(folder)

    edit_mission_file(folder, "mission.yaml", search="  era: MODERN\nmodules:\n", replace="  era: COLDWAR\nmodules:\n")

    assert path.read_bytes() == MISSION_YAML.replace("MODERN", "COLDWAR").replace("\n", "\r\n").encode("utf-8")


def test_edit_matches_a_crlf_passage_in_an_lf_file_and_keeps_lf(folder: Path) -> None:
    edit_mission_file(
        folder, "mission.yaml", search="  era: MODERN\r\nmodules:\r\n", replace="  era: WW2\r\nmodules:\r\n"
    )

    assert (folder / "mission.yaml").read_bytes() == MISSION_YAML.replace("MODERN", "WW2").encode("utf-8")


def test_with_no_mission_folder_read_serves_the_shipped_scaffold() -> None:
    """Before scaffold_mission, the AI read the shipped templates out of published/ by hand (FIX-OPENCODE-TEST-FINDINGS 03)."""
    from veaf_libs.shipped_defaults import resolve_defaults_source

    result = read_mission_file(None, "src/dynamic-slot-templates.yaml", line_count=5)

    shipped = resolve_defaults_source(Path("nowhere"))
    assert shipped is not None
    expected = (shipped / "src" / "dynamic-slot-templates.yaml").read_text(encoding="utf-8").split("\n")[:5]
    assert result["content"] == "\n".join(expected) + "\n"
    assert result["shipped"] is True


def test_the_action_reads_the_shipped_scaffold_without_mission_path() -> None:
    from veaf_mission_mcp.server import CATALOG

    result = CATALOG.run_action("read_mission_file", {"file": "mission.yaml", "line_count": 3})
    assert result["shipped"] is True and result["first_line"] == 1


def test_edit_still_needs_a_mission_folder() -> None:
    from veaf_mission_mcp.server import CATALOG

    with pytest.raises(ValueError, match="mission_path"):
        CATALOG.run_action("edit_mission_file", {"file": "mission.yaml", "search": "a", "replace": "b"})
