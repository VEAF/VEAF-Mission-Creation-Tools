"""`write_mission_folder` writes `mapResource` (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 16).

Caucasus Open Training v6: a key added to `map_resource_content` was lost in silence on a folder save —
`mission`, `warehouses` and `dictionary` were written back, `mapResource` never.
"""

from pathlib import Path

import luadata
from mission_tools.miz_tools import read_mission_folder, write_mission_folder

_MISSION = 'mission = {\n  ["theatre"] = "Caucasus",\n}\n'
_MAP_RESOURCE = 'mapResource = {\n  ["ResKey_1"] = "other.ogg",\n}\n'


def _folder(tmp_path: Path, *, map_resource: bool = True) -> Path:
    l10n = tmp_path / "l10n" / "DEFAULT"
    l10n.mkdir(parents=True)
    (tmp_path / "mission").write_text(_MISSION, encoding="utf-8")
    if map_resource:
        (l10n / "mapResource").write_text(_MAP_RESOURCE, encoding="utf-8")
    return tmp_path


def _resources(folder: Path) -> dict[str, str]:
    text = (folder / "l10n" / "DEFAULT" / "mapResource").read_text(encoding="utf-8")
    return luadata.unserialize(text)


def test_a_key_added_survives_a_save(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    mission = read_mission_folder(folder)
    mission.map_resource_content = {**(mission.map_resource_content or {}), "ResKey_2": "briefing.jpg"}
    write_mission_folder(mission, folder)
    assert _resources(folder) == {"ResKey_1": "other.ogg", "ResKey_2": "briefing.jpg"}


def test_an_unchanged_table_leaves_the_file_untouched(tmp_path: Path) -> None:
    folder = _folder(tmp_path)
    touched: list[Path] = []
    write_mission_folder(read_mission_folder(folder), folder, before_overwrite=touched.append)
    assert (folder / "l10n" / "DEFAULT" / "mapResource").read_text(encoding="utf-8") == _MAP_RESOURCE
    assert not [path for path in touched if path.name == "mapResource"]


def test_a_folder_without_the_file_gets_one_when_there_are_resources(tmp_path: Path) -> None:
    folder = _folder(tmp_path, map_resource=False)
    mission = read_mission_folder(folder)
    mission.map_resource_content = {"ResKey_1": "briefing.jpg"}
    write_mission_folder(mission, folder)
    assert _resources(folder) == {"ResKey_1": "briefing.jpg"}


def test_a_folder_without_the_file_and_without_resources_gets_none(tmp_path: Path) -> None:
    folder = _folder(tmp_path, map_resource=False)
    write_mission_folder(read_mission_folder(folder), folder)
    assert not (folder / "l10n" / "DEFAULT" / "mapResource").exists()
