"""Which era a shortcut is correct for, and what `list_shortcuts` and `validate` do with it.

FIX-OPEN-TRAINING-NORMANDY-FINDINGS ticket 05: building a 1944 mission through the MCP, an agent had to find by
experiment that `-aaa` follows `mission.era` and `-ewr` does not.
"""

import tempfile
from pathlib import Path

import pytest
import yaml
from veaf_libs import shortcut_eras
from veaf_libs.bundled_data import read_bundled_text
from veaf_libs.mission_validator import WARNING, _check_shortcut_eras, validate_mission_folder
from veaf_libs.veaf_shortcuts_scanner import get_shortcuts
from veaf_mission_mcp.oracle import list_shortcuts

_FOLLOWING = [
    "-aaa",
    "-samSR",
    "-samLR",
    "-samVLR",
    "-sam",
    "-armor",
    "-infantry",
    "-transport",
    "-combat",
    "-convoy",
    "-cas",
]
_WW2 = ["-freya", "-wurzburg", "-flak88", "-lefh", "-pak40", "-wespe"]
_MODERN = ["-ewr", "-blue_ewr", "-dogear", "-arty", "-mlrs", "-grad", "-sa2", "-shilka", "-hv_convoy_red", "-patriot"]


@pytest.mark.parametrize("alias", _FOLLOWING)
def test_the_shortcuts_that_draw_from_era_tables_follow_the_era(alias: str) -> None:
    assert shortcut_eras.era_of_alias(alias) == shortcut_eras.FOLLOWS_ERA


@pytest.mark.parametrize("alias", _WW2)
def test_the_ww2_radars_and_field_guns_are_ww2(alias: str) -> None:
    assert shortcut_eras.era_of_alias(alias) == shortcut_eras.WW2


@pytest.mark.parametrize("alias", _MODERN)
def test_fixed_modern_equipment_is_post_ww2(alias: str) -> None:
    assert shortcut_eras.era_of_alias(alias) == shortcut_eras.POST_WW2


@pytest.mark.parametrize("alias", ["-point", "-destroy", "-smoke", "-light", "-send"])
def test_a_command_that_spawns_no_equipment_is_era_free(alias: str) -> None:
    assert shortcut_eras.era_of_alias(alias) == shortcut_eras.ERA_FREE


def test_what_is_not_measured_is_not_claimed() -> None:
    assert shortcut_eras.era_of_alias("-jtac") == shortcut_eras.UNKNOWN


def test_an_alias_the_scanner_does_not_know_has_no_era() -> None:
    assert shortcut_eras.era_of_alias("-no_such_alias") is None


def test_the_alias_is_found_with_or_without_its_dash_and_whatever_its_case() -> None:
    assert shortcut_eras.era_of_alias("samlr") == shortcut_eras.era_of_alias("-samLR") == shortcut_eras.FOLLOWS_ERA


def test_every_ww2_shortcut_resolves_to_a_unit_or_group_alias() -> None:
    """A shortcut naming an alias `veafUnits` does not know spawns nothing, and says so only in game."""
    data = yaml.safe_load(read_bundled_text("veaf_libs", "data", "veaf-units.yaml"))
    units = {a.lower() for e in data["units"] for a in e["aliases"]}
    groups = {a.lower() for e in data["groups"] for a in e["aliases"]}
    by_alias = {a: e["veafCommand"] for e in get_shortcuts() for a in e["aliases"]}
    for alias in _WW2:
        command = by_alias[alias]
        kind, name = (part.strip() for part in command.split(",")[:2])
        wanted = name.removeprefix("name ").lower()
        assert wanted in (units if kind == "_spawn unit" else groups), f"{alias} -> {command}"


class TestListShortcutsByEra:
    def test_every_entry_carries_its_era(self) -> None:
        result = list_shortcuts()
        for family in ("units", "groups", "commands"):
            assert result[family] and all("era" in entry for entry in result[family]), family

    def test_a_ww2_mission_is_offered_the_era_following_and_ww2_shortcuts_only(self) -> None:
        names = {a for e in list_shortcuts(era="WW2")["commands"] for a in e["aliases"]}
        assert {"-aaa", "-armor", "-freya", "-flak88", "-point"} <= names
        assert names.isdisjoint({"-ewr", "-arty", "-sa2", "-jtac"})

    def test_a_modern_mission_is_not_offered_the_ww2_ones(self) -> None:
        names = {a for e in list_shortcuts(era="MODERN")["commands"] for a in e["aliases"]}
        assert {"-ewr", "-arty", "-aaa"} <= names
        assert names.isdisjoint(set(_WW2))

    def test_the_unit_and_group_families_are_filtered_too(self) -> None:
        groups = {a for e in list_shortcuts(era="WW2")["groups"] for a in e["aliases"]}
        assert {"flak88", "lefh"} <= groups and "M-109" not in groups

    def test_a_bad_era_is_refused(self) -> None:
        with pytest.raises(ValueError, match="era must be"):
            list_shortcuts(era="1944")


def _mission(*names: str) -> dict:
    units = [{"name": n, "type": "T-55"} for n in names]
    return {"coalition": {"red": {"country": [{"id": 0, "vehicle": {"group": [{"name": "Zone", "units": units}]}}]}}}


class TestValidate:
    def test_a_modern_shortcut_in_a_ww2_mission_is_reported_once_per_carrier(self) -> None:
        mission = _mission('#veafInterpreter["-ewr"]', '#command="-arty, spacing 2"', '#veafInterpreter["-aaa"]')
        issues = _check_shortcut_eras({"mission": {"era": "WW2"}}, mission)
        assert [i.level for i in issues] == [WARNING, WARNING]
        assert "-ewr" in issues[0].message and "-arty" in issues[1].message

    def test_the_ww2_and_era_following_shortcuts_pass(self) -> None:
        mission = _mission('#veafInterpreter["-freya"]', '#veafInterpreter["-samLR"]', '#veafInterpreter["-flak88"]')
        assert _check_shortcut_eras({"mission": {"era": "WW2"}}, mission) == []

    def test_a_modern_mission_is_not_checked(self) -> None:
        assert _check_shortcut_eras({"mission": {"era": "MODERN"}}, _mission('#veafInterpreter["-ewr"]')) == []

    def test_an_unknown_shortcut_is_not_claimed(self) -> None:
        assert _check_shortcut_eras({"mission": {"era": "WW2"}}, _mission('#veafInterpreter["-jtac"]')) == []

    def test_the_era_is_detected_when_the_yaml_gives_none(self) -> None:
        mission = _mission('#veafInterpreter["-ewr"]')
        mission["date"] = {"Year": 1944}
        assert len(_check_shortcut_eras({}, mission)) == 1

    def test_validate_runs_the_check(self) -> None:
        folder = Path(tempfile.mkdtemp())
        (folder / "mission.yaml").write_text("mission:\n  era: WW2\nmodules: {}\n", encoding="utf-8")
        (folder / "src" / "mission").mkdir(parents=True)
        lua = (
            'mission = { ["coalition"] = { ["red"] = { ["country"] = { [1] = { ["id"] = 0, ["vehicle"] = { ["group"] = {'
            ' [1] = { ["name"] = "Zone", ["units"] = { [1] = { ["type"] = "T-55",'
            ' ["name"] = "#veafInterpreter[\\"-sa6\\"]" } } } } } } } } } }'
        )
        (folder / "src" / "mission" / "mission").write_text(lua, encoding="utf-8")
        messages = [i.message for i in validate_mission_folder(folder) if i.level == WARNING]
        assert any("-sa6" in m for m in messages)


def test_the_ww2_air_defence_groups_are_ww2() -> None:
    """The groups `-aaa` draws from in a WW2 mission were classed post-WW2: their flak types were missing."""
    groups = {a: e["era"] for e in list_shortcuts()["groups"] for a in e["aliases"]}
    ww2_groups = {a: era for a, era in groups.items() if "-WW2-" in a}
    assert ww2_groups and set(ww2_groups.values()) == {shortcut_eras.WW2}
