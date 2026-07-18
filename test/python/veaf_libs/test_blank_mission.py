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

    def test_is_theatre_supported_case_insensitive(self) -> None:
        assert blank_mission.is_theatre_supported("CAUCASUS")
        assert not blank_mission.is_theatre_supported("nevada")


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
        # Bullseye comes from the vendored dcs-maps data — assert it is wired with numeric coords,
        # not a hardcoded literal (the value tracks the upstream calibration mission).
        blue_bullseye = mission.mission_content["coalition"]["blue"]["bullseye"]
        assert isinstance(blue_bullseye["x"], (int, float)) and isinstance(blue_bullseye["y"], (int, float))

    def test_generates_for_another_theatre(self, tmp_path: Path) -> None:
        folder = _write_folder(tmp_path, blank_mission.generate_blank_mission("Normandy"))
        mission = read_mission_folder(folder)
        assert mission.theatre_content == "Normandy"
        assert list(mission.iter_groups()) == []
        # Same wiring as Caucasus: each coalition carries a numeric bullseye.
        assert mission.mission_content is not None
        for side in ("blue", "red", "neutrals"):
            bullseye = mission.mission_content["coalition"][side]["bullseye"]
            assert isinstance(bullseye["x"], (int, float)) and isinstance(bullseye["y"], (int, float))

    def test_alias_resolves_for_blank(self) -> None:
        # SinaiMap is the canonical key; the airdromes.yaml-style "Sinai" alias resolves to it.
        assert blank_mission.is_theatre_supported("Sinai")
        assert blank_mission.generate_blank_mission("Sinai")["theatre"] == b"SinaiMap"

    def test_generated_mission_has_no_groups(self, tmp_path: Path) -> None:
        folder = _write_folder(tmp_path, blank_mission.generate_blank_mission("caucasus"))

        mission = read_mission_folder(folder)

        assert list(mission.iter_groups()) == []
