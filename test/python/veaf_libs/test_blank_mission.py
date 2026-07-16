"""Tests for the synthetic blank-mission generator (FEAT-BLANK-MISSION-THEATRE-001)."""

from pathlib import Path

import pytest
from mission_tools.miz_tools import read_mission_folder
from veaf_libs import blank_mission


def _write_folder(tmp_path: Path, files: dict[str, bytes]) -> Path:
    """Write a generated file set into a folder's ``src/mission/`` and return the folder."""
    mission_dir = tmp_path / "src" / "mission"
    for rel, content in files.items():
        dest = mission_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(content)
    return tmp_path


class TestSupportedTheatres:
    def test_caucasus_is_supported(self) -> None:
        assert "Caucasus" in blank_mission.supported_theatres()


class TestGenerateBlankMission:
    def test_returns_the_exploded_file_set(self) -> None:
        files = blank_mission.generate_blank_mission("caucasus")
        assert set(files) == {
            "mission",
            "options",
            "warehouses",
            "theatre",
            "l10n/DEFAULT/dictionary",
            "l10n/DEFAULT/mapResource",
        }

    def test_theatre_file_carries_the_name(self) -> None:
        files = blank_mission.generate_blank_mission("caucasus")
        assert files["theatre"] == b"Caucasus"

    def test_case_insensitive_theatre_lookup(self) -> None:
        assert blank_mission.generate_blank_mission("CAUCASUS")["theatre"] == b"Caucasus"

    def test_unsupported_theatre_raises_naming_it(self) -> None:
        with pytest.raises(ValueError, match="nevada"):
            blank_mission.generate_blank_mission("nevada")

    def test_generated_folder_parses_with_theatre_and_bullseye(self, tmp_path: Path) -> None:
        folder = _write_folder(tmp_path, blank_mission.generate_blank_mission("caucasus"))

        mission = read_mission_folder(folder)

        assert mission.theatre_content == "Caucasus"
        assert mission.mission_content is not None
        assert mission.mission_content["theatre"] == "Caucasus"
        blue_bullseye = mission.mission_content["coalition"]["blue"]["bullseye"]
        assert (blue_bullseye["x"], blue_bullseye["y"]) == (-327185.79676896, 607093.66320678)

    def test_generated_mission_has_no_groups(self, tmp_path: Path) -> None:
        folder = _write_folder(tmp_path, blank_mission.generate_blank_mission("caucasus"))

        mission = read_mission_folder(folder)

        assert list(mission.iter_groups()) == []
