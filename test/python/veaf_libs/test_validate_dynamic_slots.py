"""`validate` counts the dynamic slots the build will open, not only the `Client` units.

FIX-SCRATCH-MISSION-FINDINGS ticket 20: a mission scaffolded with `prepare` has no `Client` unit by
construction — its slots are dynamic, opened by the warehouses step on the templates the build
injects. `validate` warned « Aucune place joueur » and « presets.yaml est configuré mais la mission
n'a aucun aéronef joueur » on GermanyCW-v6, whose build offers slots at 12 bases.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from veaf_libs.i18n import t
from veaf_libs.mission_validator import validate_mission_folder

_NO_CLIENT = """mission =
{
    ["coalition"] = { ["blue"] = { ["country"] = {} }, ["red"] = { ["country"] = {} } },
    ["coalitions"] = { ["blue"] = {}, ["red"] = {}, ["neutrals"] = {} },
    ["triggers"] = { ["zones"] = {} },
}
"""

_WITH_CLIENT = """mission =
{
    ["coalition"] =
    {
        ["blue"] =
        {
            ["country"] =
            {
                [1] =
                {
                    ["id"] = 2,
                    ["name"] = "USA",
                    ["plane"] = { ["group"] = { [1] = { ["name"] = "Uzi",
                        ["units"] = { [1] = { ["skill"] = "Client", ["type"] = "F-15C" } } } } },
                },
            },
        },
        ["red"] = { ["country"] = {} },
    },
    ["coalitions"] = { ["blue"] = { [1] = 2 }, ["red"] = {}, ["neutrals"] = {} },
    ["triggers"] = { ["zones"] = {} },
}
"""


def _warehouses(dynamic_spawn: bool, coalition: str = "BLUE") -> str:
    flag = "true" if dynamic_spawn else "false"
    return (
        "warehouses =\n{\n"
        f'    ["airports"] = {{ [24] = {{ ["coalition"] = "{coalition}", ["dynamicSpawn"] = {flag} }} }},\n'
        '    ["warehouses"] = {},\n}\n'
    )


def _folder(
    tmp_path: Path,
    *,
    mission: str = _NO_CLIENT,
    warehouses: str | None = None,
    warehouses_yaml: str | None = None,
    mission_yaml: str = "modules: {}\n",
) -> Path:
    (tmp_path / "mission.yaml").write_text(mission_yaml, encoding="utf-8")
    src = tmp_path / "src"
    (src / "mission").mkdir(parents=True)
    (src / "mission" / "mission").write_text(mission, encoding="utf-8")
    if warehouses is not None:
        (src / "mission" / "warehouses").write_text(warehouses, encoding="utf-8")
    if warehouses_yaml is not None:
        (src / "warehouses.yaml").write_text(warehouses_yaml, encoding="utf-8")
    (src / "presets.yaml").write_text("presets: {}\n", encoding="utf-8")
    return tmp_path


def _warnings(folder: Path) -> list[str]:
    return [i.message for i in validate_mission_folder(folder)]


def _no_slot() -> str:
    # Resolved at assertion time: another test may switch the language after this module is imported.
    return t("validate.no_player_slot")


def _no_preset_target() -> str:
    return t("validate.presets_no_aircraft")


class TestDynamicSlotsCount:
    def test_a_base_open_to_dynamic_slots_is_a_player_slot(self, tmp_path: Path) -> None:
        messages = _warnings(_folder(tmp_path, warehouses=_warehouses(True)))
        assert _no_slot() not in messages
        assert _no_preset_target() not in messages

    def test_a_base_the_warehouses_config_will_open_is_a_player_slot(self, tmp_path: Path) -> None:
        """The editor writes `dynamicSpawn = false`; the build's warehouses step turns it on."""
        folder = _folder(tmp_path, warehouses=_warehouses(False), warehouses_yaml="blue:\n  defaults: {}\n")
        messages = _warnings(folder)
        assert _no_slot() not in messages
        assert _no_preset_target() not in messages

    def test_static_slots_alone_still_count(self, tmp_path: Path) -> None:
        assert _no_slot() not in _warnings(_folder(tmp_path, mission=_WITH_CLIENT))


class TestStillWarned:
    def test_neither_static_nor_dynamic_slots(self, tmp_path: Path) -> None:
        messages = _warnings(_folder(tmp_path, warehouses=_warehouses(False)))
        assert _no_slot() in messages
        assert _no_preset_target() in messages

    def test_a_neutral_base_offers_no_slot(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path, warehouses=_warehouses(True, coalition="NEUTRAL"))
        assert _no_slot() in _warnings(folder)

    def test_the_warehouses_config_does_not_open_a_side_it_does_not_declare(self, tmp_path: Path) -> None:
        folder = _folder(tmp_path, warehouses=_warehouses(False), warehouses_yaml="red:\n  defaults: {}\n")
        assert _no_slot() in _warnings(folder)

    @pytest.mark.parametrize(
        "mission_yaml",
        ["pipeline:\n  dynamic_slot_templates: false\n", "pipeline:\n  warehouses: false\n"],
    )
    def test_no_slot_when_the_build_step_is_off(self, tmp_path: Path, mission_yaml: str) -> None:
        folder = _folder(
            tmp_path,
            warehouses=_warehouses(False),
            warehouses_yaml="blue:\n  defaults: {}\n",
            mission_yaml=mission_yaml,
        )
        assert _no_slot() in _warnings(folder)
