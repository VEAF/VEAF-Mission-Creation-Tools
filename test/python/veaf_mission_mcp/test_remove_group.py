"""Tests for `remove_group` — the action that replaces hand-deleting a Lua block.

`FIX-MCP-AUTHORING-GAPS` 02. The three removals below are the three the 2026-08-18 verification
session actually needed — a player slot, an air-start slot, and the last group of its category — and
each hand-deletion left the container numbered `1,3,4`, which Lua loads and the build dies on.
"""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

import pytest
from mission_tools.miz_tools import read_mission_folder, read_miz
from veaf_mission_mcp.remove_group import remove_group

_MISSION = """mission = {
    ["theatre"] = "Caucasus",
    ["triggers"] = { ["zones"] = { [1] = { ["name"] = "CZ-North", ["x"] = 10, ["y"] = 20,
        ["radius"] = 500, ["type"] = 0, ["zoneId"] = 1, } } },
    ["coalition"] = { ["blue"] = { ["country"] = { [1] = { ["id"] = 2, ["name"] = "USA",
        ["plane"] = { ["group"] = {
            [1] = { ["name"] = "Player Viper", ["groupId"] = 1, ["units"] = { [1] = {
                ["name"] = "Player Viper-1", ["unitId"] = 1, ["type"] = "F-16C_50", } } },
            [2] = { ["name"] = "Air Start Hornet", ["groupId"] = 2, ["units"] = { [1] = {
                ["name"] = "Air Start Hornet-1", ["unitId"] = 2, ["type"] = "FA-18C_hornet", } } },
            [3] = { ["name"] = "Texaco", ["groupId"] = 3, ["units"] = { [1] = {
                ["name"] = "Texaco-1", ["unitId"] = 3, ["type"] = "KC-135", } } },
            [4] = { ["name"] = "Escort", ["groupId"] = 4, ["units"] = { [1] = {
                ["name"] = "Escort-1", ["unitId"] = 4, ["type"] = "F-15C", } },
                ["route"] = { ["points"] = { [1] = { ["x"] = 0, ["y"] = 0,
                    ["task"] = { ["id"] = "ComboTask", ["params"] = { ["tasks"] = { [1] = {
                        ["id"] = "Escort", ["params"] = { ["groupId"] = 3, ["lastWptIndexFlag"] = false } } } } },
                } } } },
        } },
        ["vehicle"] = { ["group"] = {
            [1] = { ["name"] = "CZ-North-armor", ["groupId"] = 5, ["units"] = { [1] = {
                ["name"] = "CZ-North-armor-1", ["unitId"] = 5, ["type"] = "T-72B", } } },
        } },
    } } }, ["red"] = { ["country"] = { } } },
    ["coalitions"] = { ["blue"] = { [1] = 2 }, ["red"] = { } },
}
"""

_YAML_WITH_ASSET = """modules:
  ASSETS:
    enabled: true
    assets:
      - sort: 1
        name: Texaco
        description: Tanker
        information: KC-135
        linked: true
"""


@pytest.fixture
def folder(tmp_path: Path) -> Path:
    exploded = tmp_path / "src" / "mission"
    exploded.mkdir(parents=True)
    (exploded / "mission").write_text(_MISSION, encoding="utf-8")
    (tmp_path / "mission.yaml").write_text(_YAML_WITH_ASSET, encoding="utf-8")
    return tmp_path


@pytest.fixture
def miz(tmp_path: Path) -> Path:
    path = tmp_path / "m.miz"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("mission", _MISSION.encode())
        archive.writestr("options", b"options = {\n}\n")
        archive.writestr("warehouses", b"warehouses = {\n}\n")
        archive.writestr("theatre", b"Caucasus")
        archive.writestr("l10n/DEFAULT/dictionary", b"dictionary = {\n}\n")
        archive.writestr("l10n/DEFAULT/mapResource", b"mapResource = {\n}\n")
    return path


def _country(content: dict[str, Any]) -> dict[str, Any]:
    countries = content["coalition"]["blue"]["country"]
    return (list(countries.values()) if isinstance(countries, dict) else countries)[0]


def _container(content: dict[str, Any], category: str) -> Any:
    return (_country(content).get(category) or {}).get("group")


def _names(content: dict[str, Any], category: str = "plane") -> list[str]:
    container = _container(content, category) or {}
    groups = list(container.values()) if isinstance(container, dict) else container
    return [g["name"] for g in groups]


class TestRemovalAndRenumbering:
    """The defect itself: what a hand-deletion left behind."""

    def test_the_group_is_gone(self, folder: Path) -> None:
        result = remove_group(folder, group_name="Air Start Hornet")
        assert result["group"] == "Air Start Hornet"
        assert "Air Start Hornet" not in _names(read_mission_folder(folder).mission_content or {})

    def test_the_survivors_are_renumbered_one_to_n(self, folder: Path) -> None:
        # `1,3,4` is exactly the shape that killed three builds; the keys must close up.
        remove_group(folder, group_name="Air Start Hornet")
        container = _container(read_mission_folder(folder).mission_content or {}, "plane")
        keys = sorted(container.keys()) if isinstance(container, dict) else list(range(1, len(container) + 1))
        assert keys == [1, 2, 3]

    def test_the_survivors_keep_their_order(self, folder: Path) -> None:
        remove_group(folder, group_name="Air Start Hornet")
        assert _names(read_mission_folder(folder).mission_content or {}) == ["Player Viper", "Texaco", "Escort"]

    def test_removing_the_first_group_renumbers_too(self, folder: Path) -> None:
        remove_group(folder, group_name="Player Viper")
        content = read_mission_folder(folder).mission_content or {}
        container = _container(content, "plane")
        keys = sorted(container.keys()) if isinstance(container, dict) else list(range(1, len(container) + 1))
        assert keys == [1, 2, 3]
        assert _names(content)[0] == "Air Start Hornet"

    def test_the_remaining_count_is_reported(self, folder: Path) -> None:
        assert remove_group(folder, group_name="Texaco")["remaining"] == 3

    def test_the_result_says_where_the_group_lived(self, folder: Path) -> None:
        result = remove_group(folder, group_name="CZ-North-armor")
        assert result["category"] == "vehicle"
        assert result["coalition"] == "blue"
        assert result["country"] == "USA"
        assert result["group_id"] == 5


class TestTheLastGroupOfItsCategory:
    def test_the_group_key_is_dropped_rather_than_left_empty(self, folder: Path) -> None:
        # The shape FIX-GROUP-CONTAINER-SHAPE opens on: an empty container a reader takes for a list.
        result = remove_group(folder, group_name="CZ-North-armor")
        assert result["remaining"] == 0
        assert "group" not in (_country(read_mission_folder(folder).mission_content or {}).get("vehicle") or {})


class TestReferenceWarnings:
    """Named, not refused: the mission maker may well mean it."""

    def test_a_capturing_combat_zone_is_named(self, folder: Path) -> None:
        warnings = remove_group(folder, group_name="CZ-North-armor")["warnings"]
        assert any("CZ-North" in w and "prefix" in w for w in warnings)

    def test_an_escort_task_pointing_at_the_group_is_named(self, folder: Path) -> None:
        # The Escort task nests inside a ComboTask, which is how DCS actually writes it.
        warnings = remove_group(folder, group_name="Texaco")["warnings"]
        assert any("Escort" in w and "group id 3" in w for w in warnings)

    def test_an_assets_entry_is_named(self, folder: Path) -> None:
        warnings = remove_group(folder, group_name="Texaco")["warnings"]
        assert any("ASSETS" in w for w in warnings)

    def test_an_unreferenced_group_warns_about_nothing(self, folder: Path) -> None:
        assert remove_group(folder, group_name="Air Start Hornet")["warnings"] == []

    def test_a_miz_target_cannot_check_the_assets_entry(self, miz: Path) -> None:
        # No mission.yaml in an archive; the mission-table references are still checked.
        warnings = remove_group(miz, group_name="Texaco")["warnings"]
        assert any("Escort" in w for w in warnings)
        assert not any("ASSETS" in w for w in warnings)


class TestTargets:
    def test_a_folder_edit_is_durable(self, folder: Path) -> None:
        assert remove_group(folder, group_name="Texaco")["durable"] is True

    def test_a_miz_edit_is_not(self, miz: Path) -> None:
        result = remove_group(miz, group_name="Texaco")
        assert result["durable"] is False
        assert "Texaco" not in _names(read_miz(miz).mission_content or {})


class TestRefusals:
    def test_a_fragment_is_refused(self, folder: Path) -> None:
        # 'Texaco' would match by fragment; 'Texa' must not remove it.
        with pytest.raises(ValueError, match="No group named 'Texa'"):
            remove_group(folder, group_name="Texa")

    def test_the_refusal_lists_what_exists(self, folder: Path) -> None:
        with pytest.raises(ValueError, match="Player Viper"):
            remove_group(folder, group_name="Nope")

    def test_nothing_is_written_when_the_name_misses(self, folder: Path) -> None:
        mission_file = folder / "src" / "mission" / "mission"
        before = mission_file.read_text(encoding="utf-8")
        with pytest.raises(ValueError):
            remove_group(folder, group_name="Nope")
        assert mission_file.read_text(encoding="utf-8") == before
