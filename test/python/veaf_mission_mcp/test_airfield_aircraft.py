"""Tests for `list_airfield_aircraft` — the aircraft types an airfield can offer as dynamic slots.

FIX-MCP-REPLAY-FINDINGS ticket 02. A local model edited `src/warehouses.yaml` by hand with `F-16C` and
`AV-8B`, which the build does not know (the types are `F-16C_50` and `AV8BNA`), and rebuilt. The action
answers from the catalogue the build injects.
"""

from pathlib import Path
from typing import Any

import pytest
import yaml
from mission_tools.miz_tools import DcsMission
from veaf_libs.dcs_airdromes import airdrome_id_for_name
from veaf_mission_mcp import airfield_aircraft
from veaf_mission_mcp.airfield_aircraft import list_airfield_aircraft
from warehouses_injector import apply_warehouses


def _group(name: str, unit_type: str) -> dict[str, Any]:
    return {"name": name, "dynSpawnTemplate": True, "units": {1: {"type": unit_type}}}


def _catalogue() -> dict[str, Any]:
    return {
        "airplanes": {
            "coalitions": {
                "blue": {"CJTF Blue": {"F-16CM Template": _group("F-16CM Template", "F-16C_50")}},
                "red": {"CJTF Red": {"MiG-29 Template Red": _group("MiG-29 Template Red", "MiG-29S")}},
            }
        },
        "helicopters": {"coalitions": {"blue": {"CJTF Blue": {"UH-1H Template": _group("UH-1H Template", "UH-1H")}}}},
    }


def _folder(tmp_path: Path, *, catalogue: dict[str, Any] | None = None, era: str | None = None) -> Path:
    """A mission folder; with no `catalogue` the build would use the shipped one."""
    (tmp_path / "src").mkdir()
    mission_yaml: dict[str, Any] = {"mission": {"era": era}} if era else {}
    (tmp_path / "mission.yaml").write_text(yaml.safe_dump(mission_yaml), encoding="utf-8")
    if catalogue is not None:
        (tmp_path / "src" / "dynamic-slot-templates.yaml").write_text(yaml.safe_dump(catalogue), encoding="utf-8")
    return tmp_path


def _serve(monkeypatch: pytest.MonkeyPatch, theatre: str, airports: dict[int, Any]) -> None:
    mission = DcsMission(
        file_path=Path("mission"),
        mission_content={},
        theatre_content=theatre,
        warehouses_content={"airports": airports, "warehouses": {}, "weapons": {}},
    )
    monkeypatch.setattr(airfield_aircraft, "load_folder_mission", lambda _p: mission)


def _id(theatre: str, name: str) -> int:
    airdrome_id = airdrome_id_for_name(theatre, name)
    assert airdrome_id is not None
    return airdrome_id


class TestWhatAnAirfieldOffers:
    def test_the_types_are_the_ones_the_build_validates(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "BLUE"}})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Batumi")
        assert result["aircraft"]["blue"] == {"F-16C_50": "F-16CM Template", "UH-1H": "UH-1H Template"}

    def test_an_airfield_offers_its_owner_templates_only(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "RED"}})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Batumi")
        assert set(result["aircraft"]) == {"red"}
        assert result["owner"] == "red"

    def test_a_neutral_airfield_answers_for_both_sides(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Batumi")
        assert set(result["aircraft"]) == {"blue", "red"}
        assert result["owner"] == "neutral"

    def test_the_coalition_argument_wins_over_the_owner(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "BLUE"}})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Batumi", coalition="red")
        assert set(result["aircraft"]) == {"red"}

    def test_a_helipad_only_airfield_offers_helicopters_only(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _serve(monkeypatch, "Syria", {_id("Syria", "Lakatamia"): {"coalition": "BLUE"}})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Lakatamia")
        assert result["aircraft"]["blue"] == {"UH-1H": "UH-1H Template"}
        assert result["parks"] == ["helicopter"]

    def test_the_era_of_the_mission_keeps_out_aircraft_that_did_not_fly(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # The shipped catalogue spans every era and the build filters it by the mission's (a 1987 mission
        # offered F-16C and Apaches); a maker's own catalogue is taken as written.
        _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "BLUE"}})
        result = list_airfield_aircraft(_folder(tmp_path, era="COLD_WAR"), "Batumi")
        assert "F-16C_50" not in result["aircraft"]["blue"]
        assert "F-100D" in result["aircraft"]["blue"]
        assert result["era"] == "COLD_WAR"

    def test_a_makers_own_catalogue_is_taken_as_written(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "BLUE"}})
        result = list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue(), era="COLD_WAR"), "Batumi")
        assert "F-16C_50" in result["aircraft"]["blue"]


class TestRefusals:
    def test_an_unknown_airfield_is_refused_with_the_theatre(
        self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        _serve(monkeypatch, "Caucasus", {})
        with pytest.raises(ValueError, match="Unknown airfield 'Nowheresville'.*Caucasus"):
            list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Nowheresville")

    def test_an_unknown_coalition_is_refused(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        _serve(monkeypatch, "Caucasus", {})
        with pytest.raises(ValueError, match="coalition"):
            list_airfield_aircraft(_folder(tmp_path, catalogue=_catalogue()), "Batumi", coalition="green")


def _template(group_id: int, name: str, unit_type: str) -> dict[str, Any]:
    return {"groupId": group_id, "name": name, "dynSpawnTemplate": True, "units": [{"type": unit_type}]}


class TestTheNamesPassTheWarehouseStep:
    def test_every_offered_type_links_to_its_template(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        """The answer, written into a warehouse config, is stocked and linked by the real warehouses step."""
        batumi = _id("Caucasus", "Batumi")
        _serve(monkeypatch, "Caucasus", {batumi: {"coalition": "BLUE"}})
        offered = list_airfield_aircraft(_folder(tmp_path), "Batumi")["aircraft"]["blue"]
        assert len(offered) > 10  # the shipped catalogue, not a toy

        templates = [_template(100 + i, name, kind) for i, (kind, name) in enumerate(offered.items())]
        mission = DcsMission(
            file_path=Path("dummy.miz"),
            mission_content={"coalition": {"blue": {"country": [{"name": "USA", "plane": {"group": templates}}]}}},
            warehouses_content={"airports": {batumi: {"coalition": "BLUE", "dynamicSpawn": False, "aircrafts": {}}}},
            theatre_content="Caucasus",
        )
        stock = {kind: {"amount": "unlimited", "template": name} for kind, name in offered.items()}
        result = apply_warehouses(mission, {"blue": {"airports": {"Batumi": {"aircrafts": stock}}}})
        assert result.templates_linked == len(offered)


def test_the_shipped_catalogue_names_f_16c_and_av_8b_as_the_build_spells_them(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """The replay's wrong keys, `F-16C` and `AV-8B`: the answer says `F-16C_50` and `AV8BNA`."""
    _serve(monkeypatch, "Caucasus", {_id("Caucasus", "Batumi"): {"coalition": "BLUE"}})
    blue = list_airfield_aircraft(_folder(tmp_path), "Batumi")["aircraft"]["blue"]
    assert blue["F-16C_50"]
    assert blue["AV8BNA"]
    assert "F-16C" not in blue
