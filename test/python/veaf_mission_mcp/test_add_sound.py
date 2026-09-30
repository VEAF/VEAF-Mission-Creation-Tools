"""`add_sound` — embed a sound a unit can transmit.

FIX-OPEN-TRAINING-PROMPT-FINDINGS ticket 04: the beacons of GermanyCW-v6 were copied from a v5 mission
by hand, sound files and `mapResource` included, because no action wrote either.
"""

from __future__ import annotations

import zipfile
from pathlib import Path

import luadata
import pytest
from mission_tools.miz_tools import read_miz
from veaf_mission_mcp.add_sound import add_sound

_MISSION_LUA = b'mission = { ["coalition"] = { ["blue"] = { ["country"] = { } } } }'


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    path = tmp_path / "mission.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("options", b"options = {\n}\n")
        zf.writestr("warehouses", b"warehouses = {\n}\n")
        zf.writestr("theatre", b"Caucasus")
        zf.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        zf.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


@pytest.fixture
def sound(tmp_path: Path) -> Path:
    path = tmp_path / "beacon.ogg"
    path.write_bytes(b"OggS-fake")
    return path


class TestAddSound:
    def test_the_file_is_embedded_and_declared(self, miz: Path, sound: Path) -> None:
        result = add_sound(miz, source_path=str(sound))
        assert result["key"] == "MCP_Sound_beacon" and result["file"] == "beacon.ogg"
        with zipfile.ZipFile(miz) as zf:
            assert zf.read("l10n/DEFAULT/beacon.ogg") == b"OggS-fake"
            assert zf.namelist().count("l10n/DEFAULT/mapResource") == 1
        assert read_miz(miz).map_resource_content == {"MCP_Sound_beacon": "beacon.ogg"}

    def test_the_same_file_again_reuses_its_key(self, miz: Path, sound: Path) -> None:
        add_sound(miz, source_path=str(sound))
        again = add_sound(miz, source_path=str(sound))
        assert again["key"] == "MCP_Sound_beacon" and again["replaced"] is True

    def test_a_mission_folder_gets_the_file_beside_its_mission(self, tmp_path: Path, sound: Path) -> None:
        folder = tmp_path / "folder"
        l10n = folder / "src" / "mission" / "l10n" / "DEFAULT"
        l10n.mkdir(parents=True)
        (folder / "src" / "mission" / "mission").write_bytes(_MISSION_LUA)
        (l10n / "mapResource").write_text('mapResource = {\n  ["ResKey_1"] = "other.ogg",\n}\n', encoding="utf-8")
        result = add_sound(folder, source_path=str(sound))
        assert result["durable"] is True
        assert (l10n / "beacon.ogg").read_bytes() == b"OggS-fake"
        written = luadata.unserialize((l10n / "mapResource").read_text(encoding="utf-8"))
        assert written == {"ResKey_1": "other.ogg", "MCP_Sound_beacon": "beacon.ogg"}

    def test_anything_but_a_sound_is_refused(self, miz: Path, tmp_path: Path) -> None:
        script = tmp_path / "x.lua"
        script.write_text("--", encoding="utf-8")
        with pytest.raises(ValueError, match=r"\.ogg or \.wav"):
            add_sound(miz, source_path=str(script))


def test_a_key_the_build_owns_is_never_handed_out(tmp_path: Path, sound: Path) -> None:
    path = tmp_path / "built.miz"
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr("mission", _MISSION_LUA)
        zf.writestr("l10n/DEFAULT/mapResource", b'mapResource = { ["VEAF_MapKey_Sound_0"] = "beacon.ogg" }\n')
    assert add_sound(path, source_path=str(sound))["key"] == "MCP_Sound_beacon"
