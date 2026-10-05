"""`set_briefing_picture` — a coalition's briefing image in one call (FIX-DEMO-MISSION-FINDINGS 07).

The demo mission scripted the three pieces DCS keeps apart: the file in `l10n/DEFAULT/`, its key in
`mapResource`, and that key in `pictureFileNameB/R/N`.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

import luadata
import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.briefing_picture import set_briefing_picture

_MISSION_LUA = (
    b'mission = { ["coalition"] = { ["blue"] = { ["country"] = { } } }, ["pictureFileNameR"] = { [1] = "ResKey_Old" } }'
)


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b'mapResource = {\n  ["ResKey_Old"] = "old.png",\n}\n')
    return path


@pytest.fixture
def folder(tmp_path: Path) -> Path:
    root = tmp_path / "folder"
    l10n = root / "src" / "mission" / "l10n" / "DEFAULT"
    l10n.mkdir(parents=True)
    (root / "src" / "mission" / "mission").write_bytes(_MISSION_LUA)
    (l10n / "mapResource").write_text('mapResource = {\n  ["ResKey_Old"] = "old.png",\n}\n', encoding="utf-8")
    return root


@pytest.fixture
def picture(tmp_path: Path) -> Path:
    path = tmp_path / "map.png"
    path.write_bytes(b"PNG-fake")
    return path


def _values(container: object) -> list:
    return list(container.values()) if isinstance(container, dict) else list(container or [])


class TestSetBriefingPicture:
    def test_a_folder_gets_the_file_the_key_and_the_reference(self, folder: Path, picture: Path) -> None:
        result = set_briefing_picture(folder, source_path=str(picture), side="blue")

        l10n = folder / "src" / "mission" / "l10n" / "DEFAULT"
        assert result["key"] == "MCP_Picture_map" and result["durable"] is True
        assert (l10n / "map.png").read_bytes() == b"PNG-fake"
        # save_folder_mission writes mapResource back (the finding's « does not rewrite mapResource »)
        assert luadata.unserialize((l10n / "mapResource").read_text(encoding="utf-8")) == {
            "ResKey_Old": "old.png",
            "MCP_Picture_map": "map.png",
        }
        content = luadata.unserialize((folder / "src" / "mission" / "mission").read_text(encoding="utf-8"))
        assert _values(content["pictureFileNameB"]) == ["MCP_Picture_map"]

    def test_a_side_keeps_the_pictures_it_already_had(self, folder: Path, picture: Path) -> None:
        result = set_briefing_picture(folder, source_path=str(picture), side="red")
        assert result["pictures"] == ["ResKey_Old", "MCP_Picture_map"]

    def test_the_same_picture_twice_is_listed_once(self, folder: Path, picture: Path) -> None:
        set_briefing_picture(folder, source_path=str(picture), side="blue")
        again = set_briefing_picture(folder, source_path=str(picture), side="blue")
        assert again["pictures"] == ["MCP_Picture_map"] and again["replaced"] is True

    def test_a_miz_is_written_too(self, miz: Path, picture: Path) -> None:
        set_briefing_picture(miz, source_path=str(picture), side="neutral")
        with zipfile.ZipFile(miz) as zf:
            assert zf.read("l10n/DEFAULT/map.png") == b"PNG-fake"
            assert zf.namelist().count("l10n/DEFAULT/mapResource") == 1
        mission = read_miz(miz)
        assert mission.map_resource_content == {"ResKey_Old": "old.png", "MCP_Picture_map": "map.png"}
        assert _values(mission.mission_content["pictureFileNameN"]) == ["MCP_Picture_map"]

    def test_an_unknown_side_is_refused(self, folder: Path, picture: Path) -> None:
        with pytest.raises(ValueError, match="blue"):
            set_briefing_picture(folder, source_path=str(picture), side="green")

    def test_only_an_image_is_accepted(self, folder: Path, tmp_path: Path) -> None:
        sound = tmp_path / "beacon.ogg"
        sound.write_bytes(b"OggS")
        with pytest.raises(ValueError, match=r"\.png"):
            set_briefing_picture(folder, source_path=str(sound), side="blue")

    def test_the_action_is_registered(self, folder: Path, picture: Path) -> None:
        from veaf_mission_mcp.server import CATALOG

        result = CATALOG.run_action(
            "set_briefing_picture", {"mission_path": str(folder), "source_path": str(picture), "side": "blue"}
        )
        assert result["key"] == "MCP_Picture_map"
