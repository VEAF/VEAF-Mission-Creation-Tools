"""Tests for wave-8 mission-folder awareness (durable source edits)."""

from pathlib import Path

import pytest

from veaf_mission_mcp.mission_folder import load_folder_mission, save_folder_mission

_MISSION = """\
mission =
{
  ["coalition"] =
  {
  },
  ["start_time"] = 0,
}
"""


def _folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    return tmp_path


def test_load_reads_exploded_mission(tmp_path: Path) -> None:
    mission = load_folder_mission(_folder(tmp_path))
    assert isinstance(mission.mission_content, dict)
    assert "coalition" in mission.mission_content


def test_save_persists_a_mutation(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    mission = load_folder_mission(folder)
    mission.mission_content["start_time"] = 42
    save_folder_mission(mission, folder)
    assert load_folder_mission(folder).mission_content["start_time"] == 42


def test_save_backs_up_the_mission_file(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    result = save_folder_mission(load_folder_mission(folder), folder)
    backup = Path(result["backup"])
    assert backup.exists()
    assert backup.name.startswith("mission.")


def test_load_missing_folder_raises(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        load_folder_mission(tmp_path)  # empty folder, no mission file
