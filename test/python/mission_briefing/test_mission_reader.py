"""What a one-shot mission's briefing reads from the built mission (FEAT-MCP-MISSION-BRIEFING ticket 02)."""

from __future__ import annotations

from typing import Any

import pytest
from mission_briefing.mission_reader import group_position, objective_area, radio_plans


def _unit(name: str, x: float, y: float, **extra: Any) -> dict[str, Any]:
    return {"name": name, "type": extra.pop("type", "T-72B"), "x": x, "y": y, **extra}


def _group(name: str, *units: dict[str, Any], **extra: Any) -> dict[str, Any]:
    return {"name": name, "units": {i: unit for i, unit in enumerate(units, 1)}, **extra}


def _content(blue: dict[str, Any], red: dict[str, Any]) -> dict[str, Any]:
    def side(categories: dict[str, Any]) -> dict[str, Any]:
        country = {cat: {"group": dict(enumerate(groups, 1))} for cat, groups in categories.items()}
        return {"country": {1: country}}

    return {
        "coalition": {"blue": side(blue), "red": side(red)},
        "triggers": {"zones": {1: {"name": "Khobi", "x": 1000.0, "y": 2000.0, "radius": 3000.0}}},
    }


def _radio(*channels: tuple[float, str | None]) -> dict[str, Any]:
    radio: dict[str, Any] = {"channels": {n: freq for n, (freq, _) in enumerate(channels, 1)}}
    if any(title for _, title in channels):
        radio["channelsNames"] = {n: title for n, (_, title) in enumerate(channels, 1) if title}
    return radio


class TestObjectiveArea:
    def test_the_zone_and_the_enemy_members_of_the_zone(self) -> None:
        content = _content(
            blue={"vehicle": [_group("Khobi-Friendly", _unit("b", 1000, 2000))]},
            red={
                "vehicle": [
                    _group("Khobi-SA8", _unit("Khobi-SA8-1", 1100, 2100, type="Osa 9A33 ln")),
                    _group("Elsewhere", _unit("x", 1000, 2000)),
                ],
                "static": [
                    _group("Depot group", _unit("khobi Dépôt de munitions", 900, 1900, type="Shelter")),
                    _group("Khobi-Static-ignored", _unit("Command post", 950, 1950)),
                ],
            },
        )
        area = objective_area(content, "Khobi", "red")
        assert (area.zone, area.x, area.y, area.radius) == ("Khobi", 1000.0, 2000.0, 3000.0)
        assert [(target.name, target.x, target.y) for target in area.targets] == [
            ("SA8", 1100.0, 2100.0),
            ("Dépôt de munitions", 900.0, 1900.0),
        ]

    def test_a_name_that_is_only_the_zone_keeps_it(self) -> None:
        content = _content(blue={}, red={"vehicle": [_group("Khobi #spawnradius=0", _unit("u", 1, 2))]})
        assert [target.name for target in objective_area(content, "Khobi", "red").targets] == ["Khobi"]

    def test_an_unknown_zone_is_refused(self) -> None:
        with pytest.raises(ValueError, match="Nowhere"):
            objective_area(_content(blue={}, red={}), "Nowhere", "red")


class TestGroupPosition:
    def test_a_group_of_any_side_and_category(self) -> None:
        content = _content(blue={}, red={"vehicle": [_group("SA-6 Site", _unit("a", 5.0, 6.0))]})
        assert group_position(content, "SA-6 Site") == (5.0, 6.0)
        assert group_position(content, "Missing") is None


class TestRadioPlans:
    def test_lua_arrays_read_back_as_lists(self) -> None:
        # luadata turns a Lua sequence into a list: that is how a built .miz hands the presets back
        radio = {"channels": [251.0, 390.0], "channelsNames": ["Magic", "Archer"]}
        unit = _unit("a1", 0, 0, type="A-10C_2", skill="Client", Radio=[radio])
        plans = radio_plans(_content(blue={"plane": [_group("ARCHER", unit)]}, red={}), "blue")
        assert [(plan.radio, plan.channels) for plan in plans] == [(1, ((1, "Magic", 251.0), (2, "Archer", 390.0)))]

    def test_the_presets_injected_into_the_players_first_aircraft(self) -> None:
        uhf = _radio((390.0, "Archer"), (251.0, "Magic"))
        vhf = _radio((124.0, None))
        content = _content(
            blue={
                "plane": [
                    _group("ARCHER", _unit("a1", 0, 0, type="A-10C_2", skill="Client", Radio={1: uhf, 2: vhf})),
                    _group("NINJA", _unit("n1", 0, 0, type="F-16C_50", skill="Client", Radio={1: uhf})),
                    _group("Texaco", _unit("t", 0, 0, type="KC135MPRS", skill="High", Radio={1: uhf})),
                    _group(
                        "Hornet template",
                        _unit("h", 0, 0, type="FA-18C_hornet", skill="High", Radio={1: _radio((305.0, "Range"))}),
                        dynSpawnTemplate=True,
                    ),
                ]
            },
            red={},
        )
        plans = radio_plans(content, "blue")
        assert [(plan.radio, plan.flights, plan.channels) for plan in plans] == [
            (1, ("ARCHER", "NINJA"), ((1, "Archer", 390.0), (2, "Magic", 251.0))),
            (1, ("FA-18C_hornet",), ((1, "Range", 305.0),)),
            (2, ("ARCHER",), ((1, "", 124.0),)),
        ]
