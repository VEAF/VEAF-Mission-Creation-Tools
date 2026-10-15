import zipfile
from pathlib import Path

import pytest
from veaf_mission_mcp.describe_mission import describe_mission


def test_lists_groups_across_coalitions_and_countries(sample_miz: Path) -> None:
    result = describe_mission(sample_miz)

    assert {
        "name": "Blue Recon Flight",
        "coalition": "blue",
        "country": "USA",
        "category": "plane",
    } in result["groups"]
    assert {
        "name": "Red Armor Section",
        "coalition": "red",
        "country": "Russia",
        "category": "vehicle",
    } in result["groups"]
    assert len(result["groups"]) == 2


def test_lists_trigger_zones_with_position_and_radius(sample_miz: Path) -> None:
    result = describe_mission(sample_miz)

    assert result["zones"] == [{"name": "combatZone_Test", "x": 100.0, "y": 200.0, "radius": 3000}]


def test_raises_a_clear_error_when_mission_file_is_missing(tmp_path: Path) -> None:
    miz_path = tmp_path / "empty.miz"
    with zipfile.ZipFile(miz_path, "w") as zf:
        zf.writestr("options", b"options = {\n}\n")

    with pytest.raises(ValueError, match="Not a valid DCS mission archive"):
        describe_mission(miz_path)


def test_raises_for_a_missing_file(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        describe_mission(tmp_path / "does-not-exist.miz")


def test_a_mission_folder_is_read_like_a_miz(sample_miz: Path, tmp_path: Path) -> None:
    """FIX-OPEN-TRAINING-MARIANAS-FINDINGS ticket 05: a folder died on `PermissionError`, while every
    write action takes one."""
    folder = tmp_path / "folder"
    exploded = folder / "src" / "mission"
    exploded.mkdir(parents=True)
    with zipfile.ZipFile(sample_miz) as zf:
        zf.extractall(exploded)
    (folder / "mission.yaml").write_text("modules: {}\n", encoding="utf-8")
    assert describe_mission(folder) == describe_mission(sample_miz)
